"""packs/core/snapshot.json records the engine's answer for every message we have. If this fails after a rule or model change,
run `python tools/snapshot.py`, review the diff (which verdicts moved, and why), and commit it with the change."""
import json
from pathlib import Path

from scamsaathi import analyze, load_pack

CORE = Path(__file__).resolve().parents[2] / "packs" / "core"
PACK = load_pack(CORE / "pack.json")
SNAP = json.loads((CORE / "snapshot.json").read_text(encoding="utf-8"))


def test_snapshot_matches_the_engine():
    stale = []
    for row in SNAP:
        a = analyze(row["text"], PACK)
        if (a["verdict"], a["score"], a["family"], [x["id"] for x in a["reasons"]]) != (row["verdict"], row["score"], row["family"], row["signals"]):
            stale.append(row["id"])
    assert not stale, f"snapshot is out of date for {len(stale)} messages, e.g. {stale[:5]}: run tools/snapshot.py"


def test_snapshot_covers_every_message_we_have():
    have = set()
    for name in ["corpus", "benchmark", "heldout", "heldout2", "heldout3", "everyday"]:
        for line in (CORE / f"{name}.jsonl").read_text(encoding="utf-8").splitlines():
            if line.strip():
                have.add(f"{name}:{json.loads(line)['id']}")
    assert have == {r["id"] for r in SNAP}


def test_the_model_alone_never_makes_a_message_dangerous():
    for row in SNAP:
        rule_signals = [s for s in row["signals"] if s != "model.wording"]
        if row["verdict"] == "dangerous":
            assert len(rule_signals) >= 2, row["id"]


def test_the_model_does_fire_somewhere_and_stays_quiet_on_most_normal_messages():
    fired = [r for r in SNAP if "model.wording" in r["signals"]]
    assert fired, "the model never fires: is it in the pack?"
    normal = [r for r in SNAP if r["id"].split(":")[1].startswith(("benign", "h-benign", "h2-benign", "h3-benign", "e-benign", "safe-"))]
    assert sum("model.wording" in r["signals"] for r in normal) / len(normal) < 0.05
