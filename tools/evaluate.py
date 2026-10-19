#!/usr/bin/env python3
"""Measure the detection engine on the labelled benchmark (packs/core/benchmark.jsonl).

    python tools/evaluate.py                       # human-readable report
    python tools/evaluate.py --markdown            # table for the docs
    python tools/evaluate.py --min-recall 0.8 --max-false-alarms 0.05   # exit 1 if worse (used in CI)

A message is "flagged" when the verdict is suspicious or dangerous. Recall is the share of scams flagged; the false-alarm rate is the
share of normal messages flagged. The benchmark is made up (no real person's message), so these numbers describe how the rules
behave on realistic examples written for this project, not on live WhatsApp traffic."""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "engine"))
from scamsaathi import analyze, load_pack  # noqa: E402


def wilson(k, n, z=1.96):
    """95% confidence interval for a proportion k/n (small samples give wide intervals)."""
    if n == 0:
        return 0.0, 1.0
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5) / d
    return max(0.0, c - h), min(1.0, c + h)


def evaluate(pack, rows):
    scams = [r for r in rows if r["label"] == "scam"]
    normal = [r for r in rows if r["label"] == "benign"]
    res = {r["id"]: analyze(r["text"], pack) for r in rows}
    flagged = lambda r: res[r["id"]]["verdict"] != "safe"  # noqa: E731
    dangerous = lambda r: res[r["id"]]["verdict"] == "dangerous"  # noqa: E731
    tp = [r for r in scams if flagged(r)]
    miss = [r for r in scams if not flagged(r)]
    fp = [r for r in normal if flagged(r)]
    fam = defaultdict(lambda: [0, 0, 0])  # family -> [scams, flagged, family correct]
    for r in scams:
        f = fam[r["family"]]
        f[0] += 1
        f[1] += flagged(r)
        f[2] += flagged(r) and res[r["id"]]["family"] == r["family"]
    return {
        "scams": len(scams), "benign": len(normal),
        "recall": len(tp) / len(scams) if scams else 0.0, "dangerous_recall": sum(dangerous(r) for r in scams) / len(scams) if scams else 0.0,
        "false_alarm_rate": len(fp) / len(normal) if normal else 0.0, "false_dangerous": sum(dangerous(r) for r in normal),
        "precision": len(tp) / (len(tp) + len(fp)) if tp or fp else 1.0,
        "family_correct_of_flagged": sum(v[2] for v in fam.values()) / max(1, len(tp)),
        "by_family": {k: {"scams": v[0], "flagged": v[1], "family_correct": v[2]} for k, v in sorted(fam.items())},
        "missed": [(r["id"], r["family"], r["text"]) for r in miss],
        "false_alarms": [(r["id"], res[r["id"]]["verdict"], [x["id"] for x in res[r["id"]]["reasons"]], r["text"]) for r in fp],
    }


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", default=str(ROOT / "packs/core/pack.json"))
    ap.add_argument("--bench", default=str(ROOT / "packs/core/benchmark.jsonl"))
    ap.add_argument("--markdown", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--no-model", action="store_true", help="ignore the wording model: rules only")
    ap.add_argument("--min-recall", type=float)
    ap.add_argument("--max-false-alarms", type=float)
    a = ap.parse_args(argv)
    rows = [json.loads(line) for line in Path(a.bench).read_text(encoding="utf-8").splitlines() if line.strip()]
    pack = load_pack(a.pack)
    if a.no_model:
        pack.pop("model", None)
    r = evaluate(pack, rows)
    if a.json:
        print(json.dumps(r, ensure_ascii=False, indent=2))
    elif a.markdown:
        print(f"| Measure | Result |\n|---|---|\n| Scam messages in the benchmark | {r['scams']} |\n| Normal messages (incl. hard cases) | {r['benign']} |")
        k = round(r['recall'] * r['scams']); lo, hi = wilson(k, r['scams'])
        print(f"| **Recall** (scams flagged suspicious or dangerous) | **{r['recall']:.0%}** ({k}/{r['scams']}, 95% interval {lo:.0%} to {hi:.0%}) |")
        print(f"| Scams called *dangerous* | {r['dangerous_recall']:.0%} |")
        lo, hi = wilson(len(r['false_alarms']), r['benign'])
        print(f"| **False alarms** (normal messages flagged) | **{r['false_alarm_rate']:.1%}** ({len(r['false_alarms'])}/{r['benign']}, 95% interval {lo:.1%} to {hi:.1%}) |")
        print(f"| Normal messages called *dangerous* | {r['false_dangerous']} |")
        print(f"| Right scam type among flagged scams | {r['family_correct_of_flagged']:.0%} |\n")
        print("| Scam type | Messages | Flagged |\n|---|---|---|")
        for k, v in r["by_family"].items():
            print(f"| {k} | {v['scams']} | {v['flagged']} |")
    else:
        print(f"scams {r['scams']}  normal {r['benign']}")
        print(f"recall {r['recall']:.1%}  (dangerous {r['dangerous_recall']:.1%})   false alarms {r['false_alarm_rate']:.1%} "
              f"({len(r['false_alarms'])})  normal called dangerous {r['false_dangerous']}   precision {r['precision']:.1%}")
        print(f"right scam type among flagged scams: {r['family_correct_of_flagged']:.1%}\n")
        for k, v in r["by_family"].items():
            print(f"  {k:18} flagged {v['flagged']}/{v['scams']}   right type {v['family_correct']}")
        print(f"\nMISSED SCAMS ({len(r['missed'])}):")
        for i, f, t in r["missed"]:
            print(f"  {i} [{f}] {t[:110]}")
        print(f"\nFALSE ALARMS ({len(r['false_alarms'])}):")
        for i, v, ids, t in r["false_alarms"]:
            print(f"  {i} {v} {ids} {t[:100]}")
    bad = []
    if a.min_recall is not None and r["recall"] < a.min_recall:
        bad.append(f"recall {r['recall']:.1%} < {a.min_recall:.0%}")
    if a.max_false_alarms is not None and r["false_alarm_rate"] > a.max_false_alarms:
        bad.append(f"false alarms {r['false_alarm_rate']:.1%} > {a.max_false_alarms:.0%}")
    if bad:
        print("FAIL: " + "; ".join(bad), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
