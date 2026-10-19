"""Indicators are exchanged as hashes. The server never sees a raw domain, UPI ID or message.

    domain / upi : value_hash = sha256(utf8(lowercase host or UPI ID)) as 64 lowercase hex characters
    apk_sha256   : the SHA-256 of the APK file itself (already a hash)
"""
import hashlib
import re

HEX64 = re.compile(r"^[0-9a-f]{64}$")


def sha256_hex(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()
