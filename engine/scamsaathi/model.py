"""The wording model: a character n-gram Naive Bayes trained on labelled messages (tools/train_model.py).

It exists because phrase rules only catch wording someone already thought of. The model notices wording that is *similar* to scam
messages, so it also catches new spellings and phrasings. Everything here is integer arithmetic so the Dart engine gives exactly
the same answer. The model can add a warning but can never, on its own, make a message "dangerous"."""
from __future__ import annotations

import re

from .extract import url_pattern

_DIGIT = re.compile(r"[0-9]")
MODEL_ID = "model.wording"


def prepare(norm: str, lists) -> list:
    """Normalised text -> words: links become `urltok`, every digit becomes 0 (so amounts and numbers do not matter)."""
    text = url_pattern(lists).sub(" urltok ", norm)
    text = _DIGIT.sub("0", text)
    return [w for w in text.split(" ") if w]


def score_parts(norm: str, model: dict, lists) -> tuple:
    """-> (sum of integer weights over all n-grams, number of n-grams)."""
    weights = model["weights"]
    total, count = 0, 0
    for word in prepare(norm, lists):
        s = " " + word + " "
        for n in model["ngrams"]:
            for i in range(len(s) - n + 1):
                total += weights.get(s[i:i + n], 0)
                count += 1
    return total, count


def model_fires(norm: str, model: dict, lists) -> bool:
    total, count = score_parts(norm, model, lists)
    return count > 0 and total > model["threshold"] * count  # length-normalised, integers only
