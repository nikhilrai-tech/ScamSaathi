# Architecture

## Principles

1. **Offline first.** A verdict never needs the network. The network only adds fresh rule packs and the Saathi alert.
2. **Private by default.** Message text, screenshots and files stay on the device. Reporting is opt-in and sends indicators only.
3. **Rules are data.** Detection logic lives in versioned JSON rule packs, not in two code bases that can drift.
4. **Two engines, one truth.** A Python reference engine (server, tooling) and a Dart engine (app) both must pass the same
   golden corpus. A rule is not merged until both agree.
5. **Never execute what you inspect.** APKs are parsed, never installed or run. Links are not opened by the device without consent.
6. **False alarms are bugs.** Precision before recall: a tool that cries wolf is uninstalled.

## Components

```
 WhatsApp / SMS --share--> [ Flutter app ] --verdict, voice--> user
                               |   |  \
                  signed packs |   |   '--(opt-in) indicators only--> [ Django API ]
                               |   '--Saathi alert (push/SMS)--------> trusted person
                               v
                         Dart engine <==== same corpus ====> Python engine
                                                                   |
 Institution dashboard (web) <--- aggregates, alerts --------- [ Django API ] --> signed rule packs
```

### Rule packs (`packs/`)
Versioned JSON: signals (patterns, phrases per language, URL/UPI/phone features), weights, explanations in every
supported language, and the scam family each belongs to. Packs are signed (Ed25519); the app only accepts packs with a
valid signature and a higher version number. The shared corpus (`packs/corpus/*.jsonl`) holds labelled examples (made up,
never real people's messages) and the expected verdict.

### Engine
Input: text, extracted URLs/UPI IDs/phone numbers, optional APK metadata (package name, permissions, signing certificate).
Output: `verdict` (`safe`, `suspicious`, `dangerous`), a score, the scam family, and **reasons**, each with a plain-language
explanation. No score without reasons.

### Mobile app (`app/`, Flutter)
Android first (share-target intent, APK metadata through a platform channel using `PackageManager`; the file is never
installed). Large type, voice read-out, Hindi and Marathi first, English fallback. iOS later (no APK sideloading there, so the
APK feature does not apply).

### API (`api/`, Django REST framework)
- `POST /v1/reports`: opt-in indicator reports (hashed domains/UPI IDs/phones/APK hashes, scam family, district, no message text).
- `GET /v1/packs/latest`: signed rule pack manifest.
- Organisations, members, alerts and a trend dashboard for institutions, with per-organisation data isolation.
- Rate limits, abuse protection against poisoned reports (a report needs several independent reporters, or a trusted org, before it affects a pack).

## Threat model (short)
| Threat | Mitigation |
|---|---|
| Attacker poisons reports to blacklist a real business | Quorum of independent reporters, human review, appeal path, packs are signed centrally |
| Malicious rule pack pushed to phones | Ed25519 signature, monotonically increasing version, pinned public key |
| Privacy leak through reports | Only salted/normalised hashes of indicators, district-level location, no message text, DPDP Act 2023 consent screen |
| Saathi feature used to stalk someone | The user chooses and can remove a Saathi at any time; the Saathi only sees "a dangerous message was found", never the content unless the user shares it |
| Scammers read the rules and evade them | Rules are public on purpose; the feed updates faster than they adapt, and signals combine, so no single pattern decides |

## Roadmap
1. **Foundations** (done): licence, governance, protected `main`, CI.
2. **Engine v0** (done): rule-pack schema, ten first scam families, Python engine and a golden corpus with strict validation.
3. **API v0** (done): signed packs, hashed reports with quorum, organisations, alerts, dashboard.
4. **App v0** (done, Android untested on a device): Dart engine passing the same corpus, signed pack updates, scam feed, Saathi note, Hindi/English UI.
5. **Next, in order**
   - Run the app on a real Android phone and fix what breaks (share intent, launches, fonts).
   - Interviews (20) and a pilot with 3 institutions. This decides whether the Saathi loop and dashboard are wanted.
   - A labelled, consented Hindi/Marathi message set to measure precision and recall honestly.
   - APK analysis on device (package name, permissions, signing certificate; never installed).
   - Marathi and more languages, voice read-out, institution web dashboard, deployment, privacy notice for the DPDP Act.
