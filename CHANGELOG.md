# Changelog

All notable changes. Versions follow [Semantic Versioning](https://semver.org/); while the major version is 0, anything may change.

## [0.2.0] - 2026-10-20

### Added
- **Measured accuracy** ([docs/EVALUATION.md](docs/EVALUATION.md)): a labelled benchmark and three held-out sets of made-up messages, an evaluator
  (`tools/evaluate.py`, with confidence intervals) and an honest history. On a fresh set the rules alone caught 42% of scams; with the new wording
  model 75% (27 of 36, interval 59% to 86%) at 1 false alarm in 36 normal messages.
- **Wording model**: a character n-gram Naive Bayes inside the signed pack. Integer weights, so Python and Dart agree exactly; it can warn but never alone
  makes a message *dangerous*. Trained by `tools/train_model.py` with an out-of-fold alert threshold.
- **Five new scam families**: electricity/gas disconnection threats, fake courier and customs parcels, investment and "double your money" tips,
  relatives in trouble (new number, urgent money), and fake buyers and sellers (army officer, advance payment). Plus about 20 new signals and many
  new wordings for the ten existing families, all with English and Hindi explanations.
- A "money is being asked for" feature (an amount together with a pay or send verb) in both engines, and `weak_families`: a pay-first request names the
  scam only when nothing more specific fired.
- `packs/core/snapshot.json` records the engine's answer for ~480 messages; both engines are tested against it, and any rule change shows up as a diff.
- Everyday normal messages with links (YouTube, Maps, Drive, government sites) as a training and test set.

### Fixed
- The pay-verb list matched "pay" inside "rupaye", so any message with an amount looked like a payment request.
- Existing Hindi and English explanations are unchanged.

## [0.1.1] - 2026-10-20

### Fixed
- **The web demo no longer contacts Google's CDNs.** It used to fetch the rendering engine (CanvasKit) from `www.gstatic.com` and
  fonts from `fonts.gstatic.com`. Neither saw the message, but they saw the visitor's IP. The engine and fonts are now served by the
  page itself, and a browser test fails if any other host is contacted.
- A screen reader read the verdict title twice.

### Added
- Noto Sans and Noto Sans Devanagari bundled in the app (SIL OFL 1.1, see `THIRD_PARTY.md`): Hindi renders correctly on phones
  without a good Devanagari font, and the web demo needs no font server.
- Real-browser end-to-end tests (`e2e/`, Chrome driven through the accessibility tree) running in CI.
- A visible note on the web demo that the message is checked inside the tab.

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
