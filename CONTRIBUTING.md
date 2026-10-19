# Contributing

Thanks for helping. The most valuable contributions are **new scam patterns, new languages and false-positive reports**.

## Ground rules

- `main` is protected: work on a branch and open a pull request. CI must pass.
- **No real data.** Never put real messages, phone numbers, UPI IDs, names or ID numbers in code, tests, issues or screenshots. Use made-up examples.
- A new detection rule needs corpus cases for the scam **and** at least two normal messages that must stay `safe`.
- Every verdict must come with a plain-language reason. A rule without an explanation is not merged.
- Rules are data (`packs/`). Do not hard-code scam patterns in the Python or Dart engine.
- Keep it small: one change per pull request.

## Sign-off

By contributing you agree your work is licensed under Apache-2.0. Please sign off your commits (`git commit -s`), which adds a
`Signed-off-by` line certifying the [Developer Certificate of Origin](https://developercertificate.org/).

## Reporting a false alarm

Open an issue with a **made-up** example that looks like the message, what verdict you got, and what you expected.
