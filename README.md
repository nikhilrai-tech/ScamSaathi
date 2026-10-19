# ScamSaathi

**A scam shield for the people scammers target most: farmers, students, and their families. It works offline, in their own language, and it brings a trusted person into the loop.**

> **Status: pre-alpha.** Engine, API and app v0 exist and are tested, but nothing is ready to protect anyone yet:
> the Android app has not been run on a real phone, accuracy on real messages is unmeasured, and nothing is deployed.
> See the [roadmap](docs/ARCHITECTURE.md#roadmap) and the [honest market map](docs/MARKET.md).

## The problem

Every day people in India lose money to fake "PM-Kisan.apk", "RTO challan" and "KYC update" files, to fake scholarship and job offers,
to UPI collect-request tricks and to loan-app threats. Most of it arrives on WhatsApp and SMS, in Hindi, Marathi or another
regional language, and the victim is often alone when it happens.

Existing checkers are mostly English-first, cloud-based, built for one message at a time, and meant for the person who
already knows something is wrong. ScamSaathi is built around three ideas that are hard to find together:

1. **Share-to-check.** From WhatsApp or SMS, share a message, link or APK to ScamSaathi. The verdict appears in seconds, in
   simple language, with voice. No typing, no copy-paste.
2. **Offline and private by default.** Detection runs on the phone from signed rule packs. A message is never uploaded unless the
   user chooses to report it, and then only the indicators (domain, UPI ID, phone number, APK hash) are sent, not the chat.
3. **The Saathi loop.** A user can name a trusted person (a son, a teacher, a cooperative officer). When something looks
   dangerous, that person is told and can answer "don't pay, it's a scam" before the money moves.

On the institution side, a school, a farmer-producer organisation, a cooperative bank or an NGO gets a dashboard of what
is circulating in its area ("a fake crop-insurance APK is going around this district") and can push an alert to the people it serves.

## What is in this repository

| Folder | What | Stack |
|---|---|---|
| `packs/` | Detection rule packs (data, not code) and the shared test corpus | JSON |
| `engine/` | Reference detection engine and conformance tests | Python |
| `api/` | Intelligence feed, reports, organisations, alerts | Django REST framework |
| `app/` | The mobile app, with the same engine in Dart | Flutter |
| `tools/` | Offline rule-pack signing | Python |

The Python and Dart engines must give the same verdict for every case in the shared corpus; CI enforces it.

## Contributing

Rule packs for new scams and for new languages are the most valuable contribution. See [CONTRIBUTING.md](CONTRIBUTING.md).
Please read [SECURITY.md](SECURITY.md) before reporting a vulnerability, and never include real people's data in an issue.

## License

Apache License 2.0, see [LICENSE](LICENSE).
