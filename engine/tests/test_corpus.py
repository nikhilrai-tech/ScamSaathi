"""The golden corpus is the contract between every engine (Python now, Dart in the app). Expected values were written by
hand from the scam's description, not copied from engine output."""
import json
import re
from pathlib import Path

import pytest

from scamsaathi import analyze, load_pack

PACK_DIR = Path(__file__).resolve().parents[2] / "packs" / "core"
PACK = load_pack(PACK_DIR / "pack.json")
CASES = [json.loads(line) for line in (PACK_DIR / "corpus.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_case(case):
    r = analyze(case["text"], PACK)
    assert r["verdict"] == case["verdict"], r
    assert r["family"] == case["family"], r
    assert sorted(x["id"] for x in r["reasons"]) == sorted(case["signals"]), r


def test_ids_are_unique():
    ids = [c["id"] for c in CASES]
    assert len(ids) == len(set(ids))


def test_every_signal_is_exercised_by_the_corpus():
    used = {s for c in CASES for s in c["signals"]}
    unused = {s["id"] for s in PACK["signals"]} - used
    assert not unused, f"add corpus cases for: {sorted(unused)}"


def test_every_family_has_a_dangerous_or_suspicious_example():
    seen = {c["family"] for c in CASES if c["verdict"] != "safe"}
    missing = set(PACK["families"]) - seen - {"job_scholarship", "remote_access"}
    assert not missing, f"no non-safe example for: {sorted(missing)}"


def test_enough_safe_messages_to_keep_us_honest():
    safe = [c for c in CASES if c["verdict"] == "safe"]
    assert len(safe) >= len(CASES) // 3


def test_corpus_has_no_real_looking_phone_numbers():
    phone = re.compile(r"(?<!\d)(?:\+?91[- ]?)?[6-9]\d{9}(?!\d)")
    bad = [c["id"] for c in CASES if phone.search(c["text"])]
    assert not bad, f"use made-up text, no phone numbers: {bad}"
