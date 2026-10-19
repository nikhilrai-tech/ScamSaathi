# API v0

Base path `/v1`. JSON only. Everything is rate limited per IP. The server never receives message text, raw domains, raw
UPI IDs or phone numbers.

## Hashes

| kind | `value_hash` |
|---|---|
| `domain` | `sha256(utf8(lowercase host))`, 64 lowercase hex characters |
| `upi` | `sha256(utf8(lowercase UPI ID))` |
| `apk_sha256` | the SHA-256 of the APK file |

`reporter_hash` is `sha256` of a random install id kept on the phone. It is not a phone number or an account.

## Public endpoints

| Method and path | What |
|---|---|
| `GET /v1/packs/core/manifest` | `{name, version, sha256, alg, key_id, signature, url}` |
| `GET /v1/packs/core/pack.json` | The exact signed bytes. The app checks `sha256` and the Ed25519 signature against its pinned public key, and only accepts a higher `version` |
| `POST /v1/reports` | `{kind, value_hash, family, reporter_hash, district?}`. Counts once per reporter. Confirmed at 3 distinct reporters. Official bank/government domains are refused |
| `GET /v1/feed?since=<iso>` | Confirmed hashes `{kind, hash, family}`, oldest first, with `next_since` when there are more |
| `POST /v1/feedback` | `{text, label: "scam" or "normal", app_verdict, family?, lang}`. A message the person chose to send because the app got it wrong. The server masks phone numbers, long numbers, PAN, emails, UPI IDs and link paths again, stores only the text, label and what the app said (no IP, device or reporter id), drops duplicates silently, and always answers `201 {accepted: true}`. Never published; a person reviews it in the admin site |
| `GET /v1/alerts?district=nashik` | Active alerts from **verified** organisations in that district |

If the pack is missing, unsigned or tampered with, both pack endpoints answer `503` and say nothing more (fail closed).

## Organisation endpoints

Header `Authorization: Api-Key <key>`. The key is shown once by `manage.py createorg` and only its hash is stored.

| Method and path | What |
|---|---|
| `GET /v1/org/dashboard` | Confirmed indicators by family reported in the organisation's own district in the last 30 days |
| `GET /v1/org/alerts` | The organisation's own alerts |
| `POST /v1/org/alerts` | Verified organisations only: `{title, body_en, body_hi, family?, days 1..30}`. Links and web addresses are refused |
| `POST /v1/org/reports` | Verified organisations only: confirms an indicator at once |

## Running it

```bash
cd api && python -m venv .venv && .venv/bin/pip install -r requirements.txt
export SCAMSAATHI_SECRET_KEY=<long random value>      # or SCAMSAATHI_DEBUG=1 for local development only
.venv/bin/python manage.py migrate
.venv/bin/python manage.py createorg --name "Example FPO" --slug example-fpo --district nashik --verified
.venv/bin/python manage.py test
```

Releasing a pack (maintainer, offline): `python tools/packsign.py sign --private ~/.scamsaathi/release.key --pack packs/core/pack.json`,
then deploy `pack.json` and `pack.sig.json` together. The private key never goes on a server.
