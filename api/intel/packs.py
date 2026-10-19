"""Load the rule pack and refuse to serve it unless the signature checks out (fail closed)."""
import base64
import hashlib
import json
from dataclasses import dataclass

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from django.conf import settings

from .hashing import sha256_hex


class PackIntegrityError(Exception):
    pass


@dataclass
class SignedPack:
    data: bytes
    pack: dict
    sig: dict


def key_id(public_raw: bytes) -> str:
    return hashlib.sha256(public_raw).hexdigest()[:16]


def load_signed_pack() -> SignedPack:
    try:
        data = (settings.PACKS_DIR / "pack.json").read_bytes()
        sig = json.loads((settings.PACKS_DIR / "pack.sig.json").read_text())
        raw = base64.b64decode(settings.PACK_PUBLIC_KEY.read_text().strip())
        if sig.get("alg") != "ed25519" or sig.get("key_id") != key_id(raw):
            raise PackIntegrityError("signature was made with a different key")
        if sig.get("sha256") != hashlib.sha256(data).hexdigest():
            raise PackIntegrityError("pack does not match its signature file")
        Ed25519PublicKey.from_public_bytes(raw).verify(base64.b64decode(sig["signature"]), data)
        return SignedPack(data, json.loads(data), sig)
    except PackIntegrityError:
        raise
    except (OSError, ValueError, KeyError, InvalidSignature) as exc:
        raise PackIntegrityError(f"pack is missing or not validly signed: {type(exc).__name__}") from exc


def known_families() -> set:
    """Family names, read without verifying: used only to validate input, never served."""
    try:
        return set(json.loads((settings.PACKS_DIR / "pack.json").read_text())["families"])
    except (OSError, ValueError, KeyError):
        return set()


def official_domain_hashes() -> set:
    """Hashes of real bank / government domains. They can never be reported, so nobody can blacklist them by poisoning."""
    try:
        lists = json.loads((settings.PACKS_DIR / "pack.json").read_text())["lists"]
    except (OSError, ValueError, KeyError):
        return set()
    domains = list(lists.get("official_gov_domains", []))
    for official in lists.get("brands", {}).values():
        domains += official
    return {sha256_hex(d) for d in domains}
