#!/usr/bin/env python3
"""Sign and verify rule packs with Ed25519. Run by a maintainer at release time, offline.

    packsign.py genkey  --private ~/.scamsaathi/release.key --public packs/keys/release.pub
    packsign.py sign    --private ~/.scamsaathi/release.key --pack packs/core/pack.json
    packsign.py verify  --public  packs/keys/release.pub    --pack packs/core/pack.json

The signature covers the exact bytes of pack.json, so any other language can verify it without
re-serialising JSON. The private key never goes in the repository or on a server."""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
from pathlib import Path

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey


def _raw_public(key: Ed25519PrivateKey) -> bytes:
    return key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def key_id(public_raw: bytes) -> str:
    return hashlib.sha256(public_raw).hexdigest()[:16]


def genkey(private_path, public_path) -> str:
    """Create a key pair. Refuses to overwrite, and the private file is readable by the owner only."""
    key = Ed25519PrivateKey.generate()
    seed = key.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption())
    private_path, public_path = Path(private_path).expanduser(), Path(public_path)
    private_path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(private_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(base64.b64encode(seed).decode() + "\n")
    public_path.parent.mkdir(parents=True, exist_ok=True)
    public_path.write_text(base64.b64encode(_raw_public(key)).decode() + "\n")
    return key_id(_raw_public(key))


def load_private(path) -> Ed25519PrivateKey:
    return Ed25519PrivateKey.from_private_bytes(base64.b64decode(Path(path).expanduser().read_text().strip()))


def load_public_raw(path) -> bytes:
    raw = base64.b64decode(Path(path).read_text().strip())
    if len(raw) != 32:
        raise ValueError("public key must be 32 raw bytes, base64 encoded")
    return raw


def sign(private_path, pack_path, out_path=None) -> dict:
    data = Path(pack_path).read_bytes()
    key = load_private(private_path)
    sig = {"alg": "ed25519", "key_id": key_id(_raw_public(key)), "version": json.loads(data)["version"],
           "sha256": hashlib.sha256(data).hexdigest(), "signature": base64.b64encode(key.sign(data)).decode()}
    out = Path(out_path) if out_path else Path(pack_path).with_name("pack.sig.json")
    out.write_text(json.dumps(sig, indent=2) + "\n")
    return sig


def verify(public_path, pack_path, sig_path=None) -> bool:
    data = Path(pack_path).read_bytes()
    sig_file = Path(sig_path) if sig_path else Path(pack_path).with_name("pack.sig.json")
    sig = json.loads(sig_file.read_text())
    raw = load_public_raw(public_path)
    if sig.get("alg") != "ed25519" or sig.get("key_id") != key_id(raw) or sig.get("sha256") != hashlib.sha256(data).hexdigest():
        return False
    try:
        Ed25519PublicKey.from_public_bytes(raw).verify(base64.b64decode(sig["signature"]), data)
    except InvalidSignature:
        return False
    return True


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="packsign")
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("genkey")
    g.add_argument("--private", required=True)
    g.add_argument("--public", required=True)
    s = sub.add_parser("sign")
    s.add_argument("--private", required=True)
    s.add_argument("--pack", required=True)
    v = sub.add_parser("verify")
    v.add_argument("--public", required=True)
    v.add_argument("--pack", required=True)
    args = ap.parse_args(argv)
    if args.cmd == "genkey":
        print("key_id:", genkey(args.private, args.public))
        print("Back up the private key somewhere safe and offline. If it is lost, apps must be updated with a new public key.")
    elif args.cmd == "sign":
        sig = sign(args.private, args.pack)
        print(f"signed version {sig['version']} with key {sig['key_id']}")
    else:
        ok = verify(args.public, args.pack)
        print("OK" if ok else "INVALID")
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
