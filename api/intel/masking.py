"""Remove personal details from a message before it is stored. The app does the same on the phone first (app/lib/services/masking.dart);
the server repeats it so a modified client cannot send raw numbers. Both are tested against packs/core/masking_cases.json.

It hides phone numbers, long digit runs (OTPs, Aadhaar, account and card numbers), PAN, email addresses, UPI IDs and the path of links.
It cannot hide names or free-text details: the person sending a message must still read what is sent."""
import re

_DIGITS = "0-9०-९"
_ADDRESS = re.compile(r"([A-Za-z0-9._%+\-]{2,})@([A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*)")
_URL = re.compile(r"(https?://[^\s/<>\"']+|www\.[^\s/<>\"']+)([^\s<>\"']*)")
_PHONE = re.compile(rf"(?<![{_DIGITS}])(?:\+?91[\-\s]?)?[6-9][0-9]{{4}}[\-\s]?[0-9]{{5}}(?![{_DIGITS}])")
_GROUPED = re.compile(r"(?<![0-9])[0-9]{4}[\-\s][0-9]{4}[\-\s][0-9]{4}(?:[\-\s][0-9]{4})?(?![0-9])")
_PAN = re.compile(r"[A-Z]{5}[0-9]{4}[A-Z]")
_LONG = re.compile(rf"[{_DIGITS}]{{6,}}")


def _address(m):
    return "user@example.com" if "." in m.group(2) else "user@upi"  # an email has a dot after the @, a UPI ID does not


def _url(m):
    return m.group(1) + ("/…" if m.group(2) else "")


def mask(text: str) -> str:
    text = _ADDRESS.sub(_address, text)
    text = _URL.sub(_url, text)
    text = _PHONE.sub("9XXXXXXXXX", text)
    text = _GROUPED.sub(lambda m: re.sub(r"[0-9]", "X", m.group(0)), text)
    text = _PAN.sub("AAAAA0000A", text)
    return _LONG.sub(lambda m: "X" * len(m.group(0)), text)
