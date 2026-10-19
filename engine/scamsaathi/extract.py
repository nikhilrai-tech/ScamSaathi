"""Find links, app files and UPI IDs in already-normalised text, and compute URL features.

Everything here is plain string logic plus two small regexes, so the Dart engine can match it exactly.
Nothing is ever fetched, opened or executed."""
from __future__ import annotations

import re
from dataclasses import dataclass, field

TRAIL = ".,;:!?"
TOKEN_STRIP = ".,;:!?()[]<>\"'"
_URL_CHARS = r"[^\s<>\"')\]\u0080-￿]"


@dataclass
class Extracted:
    features: set = field(default_factory=set)
    domains: set = field(default_factory=set)
    apk_files: set = field(default_factory=set)
    upi_ids: set = field(default_factory=set)


def _url_regex(bare_tlds, shorteners):
    tlds = "|".join(sorted(bare_tlds, key=lambda t: (-len(t), t)))
    shorts = "|".join(re.escape(s) for s in sorted(shorteners, key=lambda t: (-len(t), t)))
    tail = r"(?![a-z0-9-])(?:[/?#]" + _URL_CHARS + r"*)?"
    return re.compile(
        r"(?:https?://|www\.)" + _URL_CHARS + r"+"
        r"|(?<![a-z0-9@./-])(?:" + shorts + r")" + tail +
        r"|(?<![a-z0-9@./-])[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:" + tlds + r")" + tail
    )


def _upi_regex(handles):
    hs = "|".join(sorted(handles, key=lambda t: (-len(t), t)))
    return re.compile(r"(?<![a-z0-9._@-])[a-z0-9][a-z0-9._-]+@(?:" + hs + r")(?![a-z0-9._-])")


def _strip_trailing(url: str) -> str:
    while url and url[-1] in TRAIL:
        url = url[:-1]
    return url


def split_url(url: str):
    """-> (host, path). Manual parsing on purpose: library URL parsers differ between languages."""
    rest = url
    for scheme in ("https://", "http://"):
        if rest.startswith(scheme):
            rest = rest[len(scheme):]
            break
    cut = len(rest)
    for sep in "/?#":
        i = rest.find(sep)
        if i >= 0:
            cut = min(cut, i)
    host, path = rest[:cut], rest[cut:]
    if "@" in host:
        host = host[host.rfind("@") + 1:]
    if ":" in host:
        host = host[:host.find(":")]
    host = host.rstrip(".")
    return host, path


def _is_ip(host: str) -> bool:
    parts = host.split(".")
    return len(parts) == 4 and all(p.isascii() and p.isdigit() and 1 <= len(p) <= 3 for p in parts)


def _on_domain(host: str, domain: str) -> bool:
    return host == domain or host.endswith("." + domain)


def url_features(host: str, path: str, lists) -> set:
    feats = set()
    if not host:
        return feats
    if any(_on_domain(host, s) for s in lists["shorteners"]):
        feats.add("url.shortener")
    if _is_ip(host):
        feats.add("url.ip_host")
    if any(label.startswith("xn--") for label in host.split(".")):
        feats.add("url.punycode")
    if host.rsplit(".", 1)[-1] in lists["risky_tlds"]:
        feats.add("url.risky_tld")
    if path.split("?")[0].split("#")[0].endswith(".apk"):
        feats.add("url.apk")
    if any(w in host for w in lists["gov_words"]) and not any(_on_domain(host, d) for d in lists["official_gov_domains"]):
        feats.add("url.lookalike_gov")
    for brand, official in lists["brands"].items():
        if brand in host and not any(_on_domain(host, d) for d in official):
            feats.add("url.lookalike_brand")
    return feats


def extract(norm: str, lists) -> Extracted:
    out = Extracted()
    urls = []
    for m in _url_regex(lists["bare_tlds"], lists["shorteners"]).finditer(norm):
        url = _strip_trailing(m.group(0))
        if url.startswith("www."):
            url = "http://" + url
        host, path = split_url(url)
        if not host:
            continue
        urls.append(url)
        out.domains.add(host)
        out.features |= url_features(host, path, lists)
    for token in norm.split(" "):
        token = token.strip(TOKEN_STRIP)
        if token.endswith(".apk") and "/" not in token:
            out.apk_files.add(token)
            out.features.add("file.apk")
    for m in _upi_regex(lists["upi_handles"]).finditer(norm):
        out.upi_ids.add(m.group(0))
    return out
