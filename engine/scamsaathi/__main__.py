"""python -m scamsaathi [--pack FILE] [--lang en|hi] [--json] [--apk FILE.apk] [TEXT ...]   (reads stdin if no text and no --apk)"""
import argparse
import json
import os
import sys
from pathlib import Path

from . import analyze, load_pack
from .apk import ApkError, parse_apk

DEFAULT_PACK = Path(__file__).resolve().parent / "data" / "pack.json"
LABEL = {"en": {"safe": "SAFE", "suspicious": "SUSPICIOUS", "dangerous": "DANGEROUS"},
         "hi": {"safe": "सुरक्षित", "suspicious": "संदिग्ध", "dangerous": "ख़तरनाक"}}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="scamsaathi")
    ap.add_argument("text", nargs="*")
    ap.add_argument("--pack", default=os.environ.get("SCAMSAATHI_PACK", str(DEFAULT_PACK)))
    ap.add_argument("--lang", choices=("en", "hi"), default="en")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--apk", help="check an Android app file by reading its permissions (it is never installed or run)")
    args = ap.parse_args(argv)
    apk = None
    if args.apk:
        try:
            apk = parse_apk(Path(args.apk).read_bytes())
        except (ApkError, OSError) as exc:
            print(f"cannot read {args.apk}: {exc}", file=sys.stderr)
            return 2
        apk["file_name"] = Path(args.apk).stem
    text = " ".join(args.text) if args.text else ("" if apk else sys.stdin.read())
    result = analyze(text, load_pack(args.pack), apk)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    print(f"{LABEL[args.lang][result['verdict']]}  (score {result['score']}, family: {result['family']})")
    for r in result["reasons"]:
        print(f" - {r['text'][args.lang]}")
    if apk:
        print(f"app: {apk['package']}, asks for {len(apk['permissions'])} permissions; only the manifest was read, nothing was run")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
