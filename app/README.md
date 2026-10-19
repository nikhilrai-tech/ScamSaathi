# ScamSaathi app (Flutter)

Offline scam checker. Paste or share a message, link or APK name and get a verdict with plain-language reasons in Hindi
or English. The check runs on the phone from the signed rule pack in `assets/pack.json`.

```bash
cd app
flutter pub get
flutter test && flutter analyze
flutter run                                         # offline build: no network features at all
flutter run --dart-define=SCAMSAATHI_API=https://your-api.example   # enables pack updates, scam feed and opt-in reports
```

## How it stays in step with the rest of the repo

- `test/corpus_test.dart` runs the **same** golden corpus as the Python engine (`packs/core/corpus.jsonl`). The Dart and
  Python engines must give identical verdicts, families and reasons.
- `assets/pack.json` and `assets/release.pub` are copies of `packs/core/pack.json` and `packs/keys/release.pub`; a test
  fails if they drift. After a pack change: `cp ../packs/core/pack.json assets/pack.json`.
- Downloaded packs are used only if the Ed25519 signature verifies against the pinned public key and the version is higher
  than the one the app already has. `test/fixtures/` holds a pack signed by the Python tool with a throwaway key, which proves
  Python-made signatures verify in Dart.

## Privacy rules the code enforces (and tests check)

- The message is analysed locally and never written to disk or sent anywhere.
- Reporting is **off by default**. When on, it sends only SHA-256 hashes of domains/UPI IDs, the scam family, a district
  and a hash of a random install id, and only after the user taps "report".
- The note to the user's Saathi names the kind of scam only. It never contains the message, a link, a number or a UPI ID.
- A "no warning signs" result never says "safe": it tells the user it is not a guarantee.

## Not done / not verified

- **Android is not built or run on a device or emulator yet.** The share-to-check hook (`MainActivity.kt` and the
  `SEND` intent filter in `AndroidManifest.xml`) and the SMS/WhatsApp/dialler launches are written but untested on real hardware.
  The Dart logic, the screens (widget tests) and a web build are verified.
- The application id `io.github.nikhilrai_tech.scamsaathi` is a placeholder. Change it before any Play Store release:
  it cannot be changed afterwards.
- No APK file analysis yet (the engine reads names and links in text only), no voice read-out, no Marathi yet.
