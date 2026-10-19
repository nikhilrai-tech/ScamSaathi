import json
from pathlib import Path

import pytest

from scamsaathi import PackError, analyze, load_pack, validate_pack
from scamsaathi.extract import extract, split_url
from scamsaathi.normalize import contains, normalize

PACK_FILE = Path(__file__).resolve().parents[2] / "packs" / "core" / "pack.json"
PACK = load_pack(PACK_FILE)
LISTS = PACK["lists"]


def test_normalize_fullwidth_zero_width_digits_and_spaces():
    assert normalize("ＫＹＣ​  ｕｐｄａｔｅ") == "kyc update"
    assert normalize("OTP  १२३४") == "otp 1234"
    assert normalize("  a \n b\t") == "a b"


def test_fullwidth_obfuscation_does_not_evade():
    r = analyze("Ｙｏｕｒ ＫＹＣ ｕｐｄａｔｅ，will be blocked", PACK)
    assert {x["id"] for x in r["reasons"]} >= {"kyc.ask", "urgency"}


def test_contains_word_mode_respects_boundaries():
    assert contains("use anydesk now", "anydesk", "word")
    assert not contains("myanydeskapp", "anydesk", "word")
    assert contains("myanydeskapp", "anydesk", "substring")


def test_split_url_handles_userinfo_port_and_path():
    assert split_url("http://user:pw@evil.xyz:8080/a/b?x=1") == ("evil.xyz", "/a/b?x=1")
    assert split_url("https://sbi.co.in.") == ("sbi.co.in", "")


def test_trailing_danda_and_punctuation_are_not_part_of_the_url():
    e = extract(normalize("देखें http://evil-kyc.top/x।"), LISTS)
    assert e.domains == {"evil-kyc.top"}
    e = extract(normalize("go to bit.ly/abc, now!"), LISTS)
    assert e.domains == {"bit.ly"} and "url.shortener" in e.features


def test_email_and_upi_are_not_mistaken_for_domains():
    e = extract(normalize("pay ramesh@oksbi or mail a.b@gmail.com"), LISTS)
    assert e.upi_ids == {"ramesh@oksbi"}
    assert "oksbi" not in " ".join(e.domains)


def test_idn_and_ip_hosts():
    e = extract(normalize("http://xn--sbi-bank-kyc.com/login http://10.0.0.1/a"), LISTS)
    assert {"url.punycode", "url.ip_host"} <= e.features


def test_official_domains_are_not_flagged():
    e = extract(normalize("https://www.sbi.co.in/x and https://pmkisan.gov.in"), LISTS)
    assert not ({"url.lookalike_brand", "url.lookalike_gov"} & e.features)


def test_single_signal_can_never_be_dangerous():
    pack = json.loads(PACK_FILE.read_text(encoding="utf-8"))
    pack["signals"][0]["weight"] = 60  # file.apk alone, above the dangerous threshold
    pack["thresholds"]["dangerous"] = 50
    validate_pack(pack)
    r = analyze("open update.apk", pack)  # fires file.apk and nothing else
    assert r["score"] == 60 and r["verdict"] == "suspicious"


def test_analyze_is_deterministic_and_has_reasons_for_every_non_safe_verdict():
    text = "SBI KYC update karo warna account block ho jayega http://sbi-kyc.xyz/v"
    assert analyze(text, PACK) == analyze(text, PACK)
    r = analyze(text, PACK)
    assert r["verdict"] != "safe" and r["reasons"] and all(x["text"]["en"] and x["text"]["hi"] for x in r["reasons"])


def test_indicators_carry_no_message_text():
    r = analyze("Install Fake-App.apk from http://evil.top/a and pay demo.user@ybl", PACK)
    assert r["indicators"] == {"domains": ["evil.top"], "apk_files": ["fake-app.apk"], "upi_ids": ["demo.user@ybl"]}


@pytest.mark.parametrize("mutate,msg", [
    (lambda p: p.update(schema_version=2), "schema_version"),
    (lambda p: p["signals"].append(dict(p["signals"][0])), "duplicate"),
    (lambda p: p["signals"][8].update(weight=0), "weight"),
    (lambda p: p["signals"][8].update(family="nope"), "family"),
    (lambda p: p["signals"][8]["reason"].pop("hi"), "reason"),
    (lambda p: p["signals"][8]["phrases"].append("Not Normalised"), "normalised"),
    (lambda p: p["signals"][8].update(match="regex"), "match"),
    (lambda p: p["thresholds"].update(suspicious=90), "thresholds"),
])
def test_bad_packs_are_rejected(mutate, msg):
    pack = json.loads(PACK_FILE.read_text(encoding="utf-8"))
    mutate(pack)
    with pytest.raises(PackError, match=msg):
        validate_pack(pack)
