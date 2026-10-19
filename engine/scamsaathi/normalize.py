"""Text normalisation. Deliberately simple and explicit so the Dart engine can reproduce it exactly
(no Unicode NFKC, which Dart's standard library does not have)."""

ZERO_WIDTH = "​‌‍⁠﻿"
WHITESPACE = " \t\n\r\v\f    　"


def normalize(text: str) -> str:
    out = []
    for ch in text:
        if ch in ZERO_WIDTH:
            continue
        o = ord(ch)
        if 0xFF01 <= o <= 0xFF5E:  # full-width ASCII, often used to dodge filters
            ch = chr(o - 0xFEE0)
        elif 0x0966 <= o <= 0x096F:  # Devanagari digits -> ASCII digits
            ch = chr(o - 0x0966 + 48)
        elif ch in WHITESPACE:
            ch = " "
        out.append(ch)
    return " ".join(p for p in "".join(out).lower().split(" ") if p)


def _is_ascii_alnum(ch: str) -> bool:
    return ("a" <= ch <= "z") or ("0" <= ch <= "9")


def contains(text: str, phrase: str, mode: str) -> bool:
    """`substring`: plain containment. `word`: the phrase must not touch another ASCII letter/digit."""
    start = 0
    while True:
        i = text.find(phrase, start)
        if i < 0:
            return False
        if mode == "substring":
            return True
        before = text[i - 1] if i > 0 else " "
        after = text[i + len(phrase)] if i + len(phrase) < len(text) else " "
        left_ok = not (_is_ascii_alnum(phrase[0]) and _is_ascii_alnum(before))
        right_ok = not (_is_ascii_alnum(phrase[-1]) and _is_ascii_alnum(after))
        if left_ok and right_ok:
            return True
        start = i + 1
