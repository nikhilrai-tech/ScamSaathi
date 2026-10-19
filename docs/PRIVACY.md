# Privacy

*Plain-language summary for people using ScamSaathi and for institutions deciding whether to trust it. Not legal advice: have a lawyer review
this before you run a public service under India's Digital Personal Data Protection Act, 2023.*

## The short version

- The message you check is analysed **on your phone** (or in your browser tab for the web demo) and is **not stored and not sent anywhere**.
- There are **no accounts, no ads, no analytics, no access to your SMS, contacts or files**. The app asks for the internet permission only.
- Anything that leaves your phone does so **only if you turn it on or tap Send**, and the list below is complete.

## What stays on your phone

Your language, your chosen "Saathi" (a name and phone number you type), your own name for the note to your Saathi, your district if you
give one, a cache of the community scam list (hashes only), and a random install id used to count you once in anonymous reports.
You can delete all of it by clearing the app's data. The Android backup is switched off so none of it is copied to the cloud.

## What can leave your phone

| What | When | What exactly is sent | Can it be linked to you? |
|---|---|---|---|
| Rule updates and the community scam list | The app asks the server in the background (only in a build that has a server) | A request for a file; like any web request the server sees your IP address | The operator's server logs may keep IP addresses for a short time; the database stores none |
| Anonymous report of a scam link | **Only if you switch on reporting, and then only after you tap "report"** | A SHA-256 hash of the link's domain or UPI ID, the kind of scam, your district, and a hash of your random install id. Never the message | Not by us. The hash of a random id is not a phone number or an account |
| "This result is wrong" | **Only after you read the text and tap Send** | The message with personal details hidden (below), your label (scam / normal), what the app said, the language | No. See below |
| The note to your Saathi | You tap it; your own SMS or WhatsApp app opens and **you** send it | The kind of scam ("a fake bank KYC message") and your name. Never the message, a link, a number or a UPI ID | It goes from you to the person you chose |

## The "This result is wrong" messages

If you tap Send, you donate a message so we can fix mistakes.

- **Hidden before it leaves your phone** (and hidden again on the server): phone numbers, OTPs and other long numbers (Aadhaar, account, card), PAN, email addresses,
  UPI IDs, and everything after the website name in a link. The scam's own website name is kept: it is the useful part.
- **Not hidden automatically: names and free text.** You see the exact text in an editable box. Remove anything private before you send.
- **We store only** that text, your label, what the app said, the language and the date. **No account, phone number, device id, IP address or reporter id is stored with it.**
- Because nothing identifies you, **a donated message cannot be traced back to you, so it also cannot be deleted on request.** Send only what you are comfortable with.
- A person reads each message before it is accepted, and rejects any that still identify someone.
- Accepted messages are used on the maintainers' own machines to **test and train** the detector. They are **never published in the repository**.
  The trained model's weights are public (they are part of the signed rule pack); to reduce what they can reveal, rare word fragments are dropped
  (a word fragment is kept only if it appears at least twice in the training texts; it is counted over all texts, so a fragment repeated inside one message can still be kept). That lowers the risk of a message being recoverable from the model but cannot reduce it to zero, which is why masking and review come first.

## What we do not do

No analytics or tracking libraries, no advertising, no sale or sharing of data, no reading of your SMS or WhatsApp (the app sees a message only when **you** paste or share it),
no contacts access (you type your Saathi's number yourself), no location.

## The web demo

The demo runs the same engine in your browser tab. The page loads its code and fonts from its own server only (a browser test checks that no other host is contacted),
and has no server for reports or feedback, so it can send nothing.

## Institutions

Organisations get a district dashboard of **counts by kind of scam** and can publish verified alerts without links. They never see individual messages, people or phone numbers.

## Running your own server

If you operate the API: keep web-server access logs short, do not log request bodies, use HTTPS, restrict the admin site, back up the database, and read donated messages before accepting them.
The operator decides how long data is kept; this repository sets no retention limit, so set one.

## Contact

Questions or concerns: open an issue at <https://github.com/nikhilrai-tech/ScamSaathi/issues> (do not include personal data) or report a vulnerability privately via the Security tab.
