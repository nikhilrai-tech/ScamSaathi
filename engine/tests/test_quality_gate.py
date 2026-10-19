"""A guard against quietly getting worse. These are floors, not claims: see docs/EVALUATION.md for what the numbers mean and why
only a fresh set gives an honest accuracy figure. A change that breaks a floor needs a reason in its pull request."""
import json
from pathlib import Path

from scamsaathi import analyze, load_pack

CORE = Path(__file__).resolve().parents[2] / "packs" / "core"
PACK = load_pack(CORE / "pack.json")


def rows(*names):
    return [json.loads(line) for n in names for line in (CORE / f"{n}.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]


def flagged(r):
    return analyze(r["text"], PACK)["verdict"] != "safe"


def test_false_alarms_on_all_normal_messages_stay_low():
    normal = [r for r in rows("benchmark", "heldout", "heldout2", "heldout3", "everyday") if r["label"] == "benign"]
    normal += [r for r in rows("corpus") if r["verdict"] == "safe"]  # the golden everyday cases are not in the training data
    false_alarms = [r["id"] for r in normal if flagged(r)]
    assert len(false_alarms) / len(normal) <= 0.03, f"{len(false_alarms)}/{len(normal)} normal messages flagged: {false_alarms}"


def test_no_normal_message_is_ever_called_dangerous():
    normal = [r for r in rows("benchmark", "heldout", "heldout2", "heldout3", "everyday") if r["label"] == "benign"]
    bad = [r["id"] for r in normal if analyze(r["text"], PACK)["verdict"] == "dangerous"]
    assert not bad, bad


def test_scam_catch_rate_has_a_floor():
    scams = [r for r in rows("benchmark", "heldout", "heldout2", "heldout3") if r["label"] == "scam"]
    caught = sum(flagged(r) for r in scams)
    assert caught / len(scams) >= 0.85, f"only {caught}/{len(scams)} scams flagged"
