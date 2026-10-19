#!/usr/bin/env python3
"""Record what the engine says about every message we have (golden corpus + all benchmark sets) in packs/core/snapshot.json.

    python tools/snapshot.py            # rewrite the snapshot
    python tools/snapshot.py --check    # fail if it is out of date (used by the tests)

Both engines are checked against this file, so Python and Dart must agree on ~450 messages, not only the golden corpus, and any
change to a rule shows up as a reviewable diff of verdicts."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "engine"))
from scamsaathi import analyze, load_pack  # noqa: E402

SOURCES = ["corpus", "benchmark", "heldout", "heldout2", "heldout3", "everyday"]
OUT = ROOT / "packs/core/snapshot.json"


def build():
    pack = load_pack(ROOT / "packs/core/pack.json")
    rows = []
    for name in SOURCES:
        for line in (ROOT / "packs/core" / f"{name}.jsonl").read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            r = json.loads(line)
            a = analyze(r["text"], pack)
            rows.append({"id": f"{name}:{r['id']}", "text": r["text"], "verdict": a["verdict"], "score": a["score"],
                         "family": a["family"], "signals": [x["id"] for x in a["reasons"]]})
    return rows


def main():
    rows = build()
    text = "[\n" + ",\n".join(" " + json.dumps(r, ensure_ascii=False) for r in rows) + "\n]\n"
    if "--check" in sys.argv:
        if OUT.read_text(encoding="utf-8") != text:
            print("snapshot is out of date: run python tools/snapshot.py and review the diff")
            return 1
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"{len(rows)} messages written to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
