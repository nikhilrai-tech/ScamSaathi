from __future__ import annotations

from .extract import extract
from .model import MODEL_ID, model_fires
from .normalize import contains, normalize


def analyze(text: str, pack: dict) -> dict:
    """Return the verdict for one message. Deterministic: same text and pack always give the same result.

    verdict: safe | suspicious | dangerous.  Every non-safe verdict carries reasons; no score without reasons.
    A single signal can never make a message `dangerous` (thresholds.min_signals_dangerous)."""
    norm = normalize(text)
    found = extract(norm, pack["lists"])
    fired = []
    for sig in pack["signals"]:
        if sig["type"] == "feature":
            hit = sig["feature"] in found.features
        else:
            hit = any(contains(norm, p, sig["match"]) for p in sig["phrases"]) and \
                not any(contains(norm, u, "substring") for u in sig.get("unless", []))
        if hit:
            fired.append(sig)
    model = pack.get("model")
    if model and model_fires(norm, model, pack["lists"]):
        fired.append({"id": MODEL_ID, "weight": model["weight"], "family": "generic", "reason": model["reason"]})

    th = pack["thresholds"]
    score = min(100, sum(s["weight"] for s in fired))
    rule_signals = [s for s in fired if s["id"] != MODEL_ID]  # the model alone can never make a message dangerous
    if score >= th["dangerous"] and len(rule_signals) >= th["min_signals_dangerous"]:
        verdict = "dangerous"
    elif score >= th["suspicious"]:
        verdict = "suspicious"
    else:
        verdict = "safe"

    by_family = {}
    for s in fired:
        if s["family"] != "generic":
            by_family[s["family"]] = by_family.get(s["family"], 0) + s["weight"]
    if verdict == "safe":
        family = "none"
    elif by_family:
        # a "weak" family (such as advance_fee, a pay-first modifier) names the scam only when nothing more specific fired
        weak = set(pack.get("weak_families", []))
        pool = {f: w for f, w in by_family.items() if f not in weak} or by_family
        family = sorted(pool.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
    else:
        family = "unknown"

    fired.sort(key=lambda s: (-s["weight"], s["id"]))
    return {
        "verdict": verdict,
        "score": score,
        "family": family,
        "reasons": [{"id": s["id"], "weight": s["weight"], "text": s["reason"]} for s in fired],
        "indicators": {"domains": sorted(found.domains), "apk_files": sorted(found.apk_files),
                       "upi_ids": sorted(found.upi_ids)},
    }
