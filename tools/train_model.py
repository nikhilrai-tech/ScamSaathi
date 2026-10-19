#!/usr/bin/env python3
"""Train the wording model (character n-gram Naive Bayes) from labelled message sets and store it inside the rule pack.

    python tools/train_model.py --sets benchmark heldout heldout2                # train + report, writes nothing
    python tools/train_model.py --sets benchmark heldout heldout2 --write        # also put the model into packs/core/pack.json

Calibration is honest by construction: the alert threshold is chosen from *out-of-fold* scores (each set is scored by a model that
never saw it), so that about `--target-false-alarms` of normal messages would be flagged. The weights are stored as integers so
the Dart engine reproduces every decision exactly.

The training data is made up (see docs/EVALUATION.md). The model learns the wording of those examples, so its numbers describe
messages like them, not live WhatsApp traffic."""
import argparse
import json
import math
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "engine"))
sys.path.insert(0, str(ROOT / "tools"))
from scamsaathi import analyze, load_pack  # noqa: E402
from scamsaathi.model import prepare, score_parts  # noqa: E402
from scamsaathi.normalize import normalize  # noqa: E402
import packfmt  # noqa: E402

SCALE = 1000
NGRAMS = [3, 4, 5]
REASON = {"en": "The wording is very similar to scam messages seen before.",
          "hi": "इस मैसेज के शब्द पहले देखे गए ठगी वाले मैसेजों से बहुत मिलते हैं।"}


def load(name):
    path = Path(name) if name.endswith(".jsonl") else ROOT / "packs" / "core" / f"{name}.jsonl"
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def grams(text, lists):
    c = Counter()
    for word in prepare(normalize(text), lists):
        s = " " + word + " "
        for n in NGRAMS:
            for i in range(len(s) - n + 1):
                c[s[i:i + n]] += 1
    return c


def train(rows, lists, alpha=0.5, min_count=2, prune=0.2):
    cs, cb = Counter(), Counter()
    for r in rows:
        (cs if r["label"] == "scam" else cb).update(grams(r["text"], lists))
    vocab = set(cs) | set(cb)
    ts, tb = sum(cs.values()), sum(cb.values())
    weights = {}
    for g in vocab:
        if cs[g] + cb[g] < min_count:
            continue
        w = math.log((cs[g] + alpha) / (ts + alpha * len(vocab))) - math.log((cb[g] + alpha) / (tb + alpha * len(vocab)))
        if abs(w) >= prune:
            weights[g] = round(w * SCALE)
    return weights


def mean_score(weights, text, lists):
    total, count = score_parts(normalize(text), {"weights": weights, "ngrams": NGRAMS}, lists)
    return total / count if count else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sets", nargs="+", required=True, help="names of packs/core/NAME.jsonl, or paths to private .jsonl files that must never be committed")
    ap.add_argument("--target-false-alarms", type=float, default=0.03)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--out", help="with --write, save the pack here instead of packs/core/pack.json (to test a model without touching the real pack)")
    ap.add_argument("--spread", nargs="*", default=["everyday"],
                    help="sets whose messages are spread over the other sets' folds instead of forming a fold of their own")
    a = ap.parse_args()
    pack_path = ROOT / "packs/core/pack.json"
    pack = load_pack(pack_path)
    pack.pop("model", None)  # the rules alone, to see what the model adds
    lists = pack["lists"]
    data = {n: load(n) for n in a.sets}
    # A fold made only of normal messages with links would be scored by a model that never saw one, and would push the threshold
    # far too high. Spread such sets over the other folds so every fold's training data has some of them.
    spread = [r for n in a.spread if n in data for r in data.pop(n)]
    folds = {n: list(rows) for n, rows in data.items()}
    for i, r in enumerate(spread):
        folds[list(folds)[i % len(folds)]].append(r)
    data = folds

    oof = []  # (label, model score from a model that never saw this message, rule score)
    for held in data:
        w = train([r for n, rows in data.items() if n != held for r in rows], lists)
        for r in data[held]:
            oof.append((r["label"], mean_score(w, r["text"], lists), analyze(r["text"], pack)["score"]))
    benign = sorted(s for lab, s, _ in oof if lab == "benign")
    thr = math.ceil(benign[min(len(benign) - 1, math.ceil(len(benign) * (1 - a.target_false_alarms)) - 1)])
    scam = [(s, r) for lab, s, r in oof if lab == "scam"]
    norm = [(s, r) for lab, s, r in oof if lab == "benign"]
    print(f"out-of-fold over {len(scam)} scams and {len(norm)} normal messages, threshold {thr} (target false alarms {a.target_false_alarms:.0%}):")
    print(f"  rules alone     recall {sum(r >= 35 for _, r in scam) / len(scam):4.0%}  false alarms {sum(r >= 35 for _, r in norm) / len(norm):4.1%}")
    print(f"  model alone     recall {sum(s > thr for s, _ in scam) / len(scam):4.0%}  false alarms {sum(s > thr for s, _ in norm) / len(norm):4.1%}")
    print(f"  rules or model  recall {sum(s > thr or r >= 35 for s, r in scam) / len(scam):4.0%}  false alarms {sum(s > thr or r >= 35 for s, r in norm) / len(norm):4.1%}")

    final = train([r for rows in data.values() for r in rows], lists)
    print(f"final model: {len(final)} n-grams from {sum(len(v) for v in data.values())} messages in {a.sets}")
    if a.write:
        pack = json.loads(pack_path.read_text(encoding="utf-8"))
        pack["model"] = {"kind": "char-ngram-nb", "ngrams": NGRAMS, "scale": SCALE, "threshold": thr, "weight": 35,
                         "trained_on": sorted(Path(n).stem + ("" if not n.endswith(".jsonl") else " (private)") for n in a.sets), "reason": REASON, "weights": final}
        target = Path(a.out) if a.out else pack_path
        packfmt.dump(pack, target)
        print("written to", target, f"({target.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
