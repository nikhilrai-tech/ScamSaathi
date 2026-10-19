"""python -m scamsaathi [--pack FILE] [--lang en|hi] [--json] [TEXT ...]   (reads stdin if no text)"""
import argparse
import json
import os
import sys
from pathlib import Path

from . import analyze, load_pack

DEFAULT_PACK = Path(__file__).resolve().parent / "data" / "pack.json"
LABEL = {"en": {"safe": "SAFE", "suspicious": "SUSPICIOUS", "dangerous": "DANGEROUS"},
         "hi": {"safe": "सुरक्षित", "suspicious": "संदिग्ध", "dangerous": "ख़तरनाक"}}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="scamsaathi")
    ap.add_argument("text", nargs="*")
    ap.add_argument("--pack", default=os.environ.get("SCAMSAATHI_PACK", str(DEFAULT_PACK)))
    ap.add_argument("--lang", choices=("en", "hi"), default="en")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    text = " ".join(args.text) if args.text else sys.stdin.read()
    result = analyze(text, load_pack(args.pack))
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    print(f"{LABEL[args.lang][result['verdict']]}  (score {result['score']}, family: {result['family']})")
    for r in result["reasons"]:
        print(f" - {r['text'][args.lang]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
