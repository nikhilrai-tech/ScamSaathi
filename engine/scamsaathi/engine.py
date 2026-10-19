from __future__ import annotations

from .extract import extract
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

    th = pack["thresholds"]
    score = min(100, sum(s["weight"] for s in fired))
    if score >= th["dangerous"] and len(fired) >= th["min_signals_dangerous"]:
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
        family = sorted(by_family.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
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
