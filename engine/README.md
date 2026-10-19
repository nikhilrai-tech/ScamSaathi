# scamsaathi-engine

The offline detection engine behind [ScamSaathi](https://github.com/nikhilrai-tech/ScamSaathi), an open-source scam shield for
farmers, students and families in India.

It reads one message and says whether it looks like a scam, **and why**, in plain Hindi or English. Nothing is fetched, opened
or executed, and no network is needed. It has no dependencies.

> **Early release.** Rules for fifteen common scam families plus a small wording model. On a fresh test set of made-up messages it flagged 27 of 36
> scams (75%) and 1 of 36 normal messages. It has not been tested on real traffic yet. Treat results as a hint for a human, never as proof.
> Details: https://github.com/nikhilrai-tech/ScamSaathi/blob/main/docs/EVALUATION.md

```bash
pipx install scamsaathi-engine          # or: pip install scamsaathi-engine
scamsaathi "SBI KYC update karo warna account block ho jayega. Link: http://sbi-kyc-update.xyz/verify"
scamsaathi --lang hi "PM Kisan ki nayi list aayi hai. Yeh file install karo: PM-Kisan-Yojana.apk"
```

```
DANGEROUS  (score 95, family: kyc_bank)
 - The link uses a bank or payment app name, but it is not that company's real website.
 - It asks you to update KYC through a message. Banks do not ask for KYC over WhatsApp or SMS links.
 - The website ending (like .xyz or .top) is often used by scam sites.
 - It pushes you to act in a hurry or be punished. Scammers rush you so you do not think.
```

## Use it from Python

```python
from scamsaathi import analyze, load_default_pack

pack = load_default_pack()
result = analyze("Update KYC at http://sbi-secure.top/v and share OTP", pack)
result["verdict"]      # "safe" | "suspicious" | "dangerous"
result["family"]       # e.g. "kyc_bank"
result["reasons"]      # [{"id": ..., "weight": ..., "text": {"en": ..., "hi": ...}}, ...]
result["indicators"]   # {"domains": [...], "apk_files": [...], "upi_ids": [...]}  (no message text)
```

A single warning sign can never make a message "dangerous"; at least two must agree. A message with no warning signs is
reported as `safe`, which only means nothing suspicious was found, not that it is trustworthy.

## Rules are data

Detection lives in a versioned JSON rule pack, not in code. The Flutter app ships a Dart port of this engine and both must
pass the same golden corpus. Rule packs are signed with Ed25519 so a phone can reject a tampered update.

See the [project README](https://github.com/nikhilrai-tech/ScamSaathi#readme) for the app, the API and the roadmap.
Licensed under Apache-2.0.
