"""The APK reader is fed files that strangers send us, so it must never crash, hang or trust what the file claims."""
import json
import random
import zipfile
from pathlib import Path

import pytest

from scamsaathi import analyze, load_pack
from scamsaathi.apk import ApkError, parse_apk, parse_manifest

APK_DIR = Path(__file__).resolve().parents[2] / "packs" / "core" / "apk"
TRUTH = json.loads((APK_DIR / "expected.json").read_text(encoding="utf-8"))
PACK = load_pack(APK_DIR.parent / "pack.json")


def info(name):
    d = parse_apk((APK_DIR / f"{name}.apk").read_bytes())
    d["file_name"] = name
    return d


@pytest.mark.parametrize("name", sorted(TRUTH))
def test_parser_recovers_exactly_what_the_fixture_was_built_with(name):
    got = parse_apk((APK_DIR / name).read_bytes())
    sha = got.pop("sha256")
    assert len(sha) == 64
    assert got == TRUTH[name]


def test_not_an_apk_is_an_error_not_a_crash():
    for name in ("empty_zip.apk", "not_an_apk.apk"):
        with pytest.raises(ApkError):
            parse_apk((APK_DIR / name).read_bytes())
    with pytest.raises(ApkError):
        parse_apk(b"")


def test_a_manifest_that_is_not_binary_xml_is_refused():
    import io
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("AndroidManifest.xml", "<manifest package='x'/>")  # plain text XML is not what Android ships
    with pytest.raises(ApkError):
        parse_apk(buf.getvalue())


def test_every_truncation_of_a_real_manifest_is_handled():
    with zipfile.ZipFile(APK_DIR / "banking_trojan.apk") as z:
        raw = z.read("AndroidManifest.xml")
    for n in range(len(raw)):
        try:
            parse_manifest(raw[:n])
        except ApkError:
            pass  # the only acceptable failure


def test_random_damage_to_a_real_manifest_never_crashes_the_reader():
    with zipfile.ZipFile(APK_DIR / "fake_pmkisan.apk") as z:
        raw = bytearray(z.read("AndroidManifest.xml"))
    rng = random.Random(7)
    for _ in range(3000):
        damaged = bytearray(raw)
        for _ in range(rng.randint(1, 6)):
            damaged[rng.randrange(len(damaged))] = rng.randrange(256)
        try:
            parse_manifest(bytes(damaged))
        except ApkError:
            pass


def test_benign_apps_are_safe():
    for name in ("benign_minimal", "torch_ok"):
        assert analyze("", PACK, info(name))["verdict"] == "safe", name


def test_malicious_looking_apps_are_caught_and_explained():
    r = analyze("", PACK, info("fake_pmkisan"))
    assert r["verdict"] == "dangerous" and "apk.reads_sms" in [x["id"] for x in r["reasons"]]
    assert all(x["text"]["en"] and x["text"]["hi"] for x in r["reasons"])
    assert analyze("", PACK, info("banking_trojan"))["verdict"] == "dangerous"
    assert analyze("", PACK, info("call_forwarder"))["verdict"] == "suspicious"


def test_one_permission_alone_is_never_dangerous():
    only_sms = {"package": "io.example.x", "label": "X", "permissions": ["android.permission.READ_SMS"], "component_permissions": [],
                "actions": [], "min_sdk": 21, "target_sdk": 34, "sha256": "0" * 64}
    r = analyze("", PACK, only_sms)
    assert r["verdict"] == "suspicious" and len(r["reasons"]) == 1


def test_the_file_hash_is_reported_as_an_indicator_and_the_app_summary_is_returned():
    r = analyze("", PACK, info("fake_pmkisan"))
    assert len(r["indicators"]["apk_sha256"]) == 1 and r["apk"]["package"] == "com.pmkisan.yojana.free"
    assert analyze("hello", PACK)["indicators"]["apk_sha256"] == [] and analyze("hello", PACK)["apk"] is None


def test_apk_signals_stay_quiet_for_plain_text():
    assert analyze("Meeting at 4 pm", PACK)["verdict"] == "safe"
    ids = [x["id"] for x in analyze("PM-Kisan-Yojana.apk install karo", PACK)["reasons"]]
    assert not [i for i in ids if i.startswith("apk.")]


def test_command_line_checks_an_app_file(capsys):
    from scamsaathi.__main__ import main
    assert main(["--apk", str(APK_DIR / "fake_pmkisan.apk")]) == 0
    out = capsys.readouterr().out
    assert "DANGEROUS" in out and "com.pmkisan.yojana.free" in out
    assert main(["--apk", str(APK_DIR / "not_an_apk.apk")]) == 2
