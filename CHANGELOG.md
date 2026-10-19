# Changelog

All notable changes. Versions follow [Semantic Versioning](https://semver.org/); while the major version is 0, anything may change.

## [0.1.0] - 2026-10-20

First public pre-alpha. Nothing here is ready to protect anyone yet: accuracy on real messages is unmeasured and nothing is deployed.
The Android app was tested on a real phone by the maintainer.

### Added
- **Detection engine** (Python, `scamsaathi-engine`): offline, deterministic, explainable. Ten scam families (fake APK, bank KYC/OTP,
  UPI collect, job/scholarship, loan app, government scheme, prize/lottery, advance fee, impersonation, remote access), reasons in
  English and Hindi, never "dangerous" on a single signal. Rules are data in `packs/core/pack.json`.
- **Golden corpus**: 36 made-up messages (a third are normal messages that must stay safe) shared by the Python and Dart engines.
- **API** (Django REST framework): signed rule packs (Ed25519, offline key, fail closed), hashed scam reports with a quorum, official
  bank and government domains protected from poisoning, organisations with hashed API keys, verified-only district alerts, dashboard.
- **Flutter app**: Dart port of the engine passing the same corpus, signed pack updates, community scam feed matched locally,
  opt-in anonymous reports (hashes only), a note to a trusted person ("Saathi") that never contains the message, share-to-check on
  Android, Hindi-first UI with dark mode, example messages and a three-level warning bar.
- **Release engineering**: APK (debug-signed test build), web demo on GitHub Pages, Python package, API image on GHCR, CI on every change.

### Known limitations
- The APK is signed with a debug key and is for trying only.
- No APK file analysis, voice read-out or Marathi yet.
- Reporter ids are self-generated, so a determined attacker can fake reporters; the quorum, official-domain protection, admin
  revocation and rate limits reduce this but do not eliminate it.
