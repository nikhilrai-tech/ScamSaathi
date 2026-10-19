from __future__ import annotations

import json
from pathlib import Path

from .normalize import normalize

KNOWN_FEATURES = {"file.apk", "url.apk", "url.shortener", "url.ip_host", "url.punycode", "url.risky_tld",
                  "url.lookalike_gov", "url.lookalike_brand", "ask.payment"}
LANGS = ("en", "hi")
LIST_KEYS = ("bare_tlds", "risky_tlds", "shorteners", "gov_words", "official_gov_domains", "brands", "upi_handles", "pay_verbs", "sensitive_permissions", "apk_brand_words")


class PackError(ValueError):
    pass


def validate_pack(pack: dict) -> None:
    """Strict on purpose: a malformed rule pack must fail loudly, never silently weaken detection."""
    def need(cond, msg):
        if not cond:
            raise PackError(msg)

    need(pack.get("schema_version") == 1, "unsupported schema_version")
    need(isinstance(pack.get("version"), int) and pack["version"] >= 1, "version must be an integer >= 1")
    th = pack.get("thresholds", {})
    need(0 < th.get("suspicious", 0) < th.get("dangerous", 0) <= 100, "bad thresholds")
    need(th.get("min_signals_dangerous", 0) >= 1, "bad min_signals_dangerous")
    families = pack.get("families", [])
    need(families and len(set(families)) == len(families) and "generic" not in families, "bad families")
    need(set(pack.get("weak_families", [])) <= set(families), "weak_families must be families")
    for key in LIST_KEYS:
        need(key in pack.get("lists", {}), f"missing list {key}")
    model = pack.get("model")
    if model is not None:
        need(model.get("kind") == "char-ngram-nb" and all(isinstance(n, int) and 2 <= n <= 6 for n in model.get("ngrams", [])) and model.get("ngrams"), "bad model.ngrams")
        need(isinstance(model.get("threshold"), int) and isinstance(model.get("weight"), int) and 1 <= model["weight"] <= 60, "bad model threshold or weight")
        need(all(isinstance(model.get("reason", {}).get(lang), str) and model["reason"][lang].strip() for lang in LANGS), "model needs a reason in every language")
        w = model.get("weights")
        need(isinstance(w, dict) and w and all(isinstance(k, str) and isinstance(v, int) for k, v in w.items()), "bad model.weights")
    seen = set()
    for sig in pack.get("signals", []):
        sid = sig.get("id")
        need(isinstance(sid, str) and sid and sid not in seen, f"bad or duplicate signal id {sid!r}")
        seen.add(sid)
        need(isinstance(sig.get("weight"), int) and 1 <= sig["weight"] <= 60, f"{sid}: weight must be 1..60")
        need(sig.get("family") in families or sig.get("family") == "generic", f"{sid}: unknown family")
        reason = sig.get("reason", {})
        need(all(isinstance(reason.get(lang), str) and reason[lang].strip() for lang in LANGS),
             f"{sid}: reason needs text in {LANGS}")
        if sig.get("type") == "feature":
            need(sig.get("feature") == sid and sid in KNOWN_FEATURES, f"{sid}: unknown feature")
        elif sig.get("type") == "phrase":
            need(sig.get("match") in ("word", "substring"), f"{sid}: match must be word or substring")
            for key in ("phrases", "unless"):
                items = sig.get(key, [] if key == "unless" else None)
                need(isinstance(items, list) and (key == "unless" or items), f"{sid}: {key} must be a list")
                for p in items:
                    need(isinstance(p, str) and p and p == normalize(p), f"{sid}: phrase {p!r} is not in normalised form")
        elif sig.get("type") == "apk":
            need(any(k in sig for k in ("any_permissions", "any_actions", "min_sensitive", "brand_names")), f"{sid}: an apk signal needs a condition")
            for key in ("any_permissions", "any_actions"):
                need(all(isinstance(x, str) and x for x in sig.get(key, [])), f"{sid}: {key} must be strings")
        else:
            raise PackError(f"{sid}: unknown type")


def load_default_pack() -> dict:
    """The rule pack that ships inside this package."""
    return load_pack(Path(__file__).with_name("data") / "pack.json")


def load_pack(path) -> dict:
    pack = json.loads(Path(path).read_text(encoding="utf-8"))
    validate_pack(pack)
    return pack
