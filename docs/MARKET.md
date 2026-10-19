# Market map (honest version)

*Written 19 Oct 2026 from a quick web search. Not a full study; re-check before any investor or press claim.*

## It is not an empty space

| Project | What it does | How ScamSaathi differs |
|---|---|---|
| [Gadbad](https://pypi.org/project/gadbad/) (MIT, PyPI) | Reads fake APKs spread over WhatsApp in India (RTO challan, bank KYC) without running them | A command-line tool for analysts. No app, no end user, no alerts |
| [Saavdhan](https://github.com/kalpitt/saavdhan/releases) | Android app that finds scam and spyware apps, explains in Hindi/English, guides removal | Device-side only, no trusted-person loop, no institution layer |
| [ScamRakshak](https://rohitraj.tech/notes/upi-fraud-805-crore-why-i-built-offline-scam-detector) | Offline detector for messages, URLs, UPI IDs and screenshots, Hindi/English | Solo detector. Check the repository for its licence and activity |
| [Seerie](https://www.producthunt.com/products/seerie) | Offline scam checker for SMS, links, screenshots | Closed source, individual user only |
| [Truecaller Scam Checker](https://www.techrepublic.com/article/news-truecaller-scam-checker-apac-india/) | Launched in India 28 Sep 2026; checks numbers, links, messages against Truecaller data and community reports | Large, cloud based, English-first, closed. Not offline, not open |
| Government channels | Sanchar Saathi / Chakshu to report, 1930 helpline and cybercrime.gov.in after a loss | Reporting after the fact, not prevention at the moment of the message |

Anyone can build "paste a message, get a verdict". That is **not** a company and **not** our wedge.

## Where the gap seems to be (to be validated, not assumed)

1. **A guardian loop.** None of the above bring a trusted second person in before the payment. Many victims are elderly or
   first-time digital users, and a short "don't pay" from a relative is the most effective control.
2. **An institution layer.** Schools, farmer-producer organisations, cooperative banks and NGOs have the trust and the
   reach, but no tool that shows them local scam trends and lets them alert their people. This is also the paying customer.
3. **Rural and student vertical.** Crop-insurance, subsidy, fertiliser, mandi and scholarship scams, in regional languages and by voice.
4. **Open, auditable intelligence.** A public, signed rule-pack and indicator feed that banks, telcos and researchers can
   use, with privacy by design (hashed indicators, no message content).

## What would prove or kill this idea

- 20 interviews (farmers, students, FPO/cooperative staff, school teachers): do they forward suspicious messages to someone today? To whom?
- 3 institutions willing to pilot the dashboard for free for 90 days.
- A measured detection quality on a labelled Hindi/Marathi corpus (target: high precision first, because false alarms destroy trust).

If interviews show people do not want a "Saathi" notified (shame, privacy), the guardian loop changes or goes.

## Business model (hypothesis)

Open-source core (app, engine, rule packs) under Apache-2.0 for trust and adoption. Revenue from the **hosted institution
dashboard, alert broadcasting, threat-feed API and support** sold to cooperative banks, FPOs, schools, NGOs and later
telcos and fintechs. The moat is data, relationships and brand, not the licence. Check trademark availability for the name
"ScamSaathi" before spending on branding.
