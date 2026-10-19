#!/usr/bin/env python3
"""Build tiny test APKs (a real binary AndroidManifest.xml and nothing else) with aapt2, so the APK analyser can be tested on files that
contain exactly the permissions we want. They are NOT working apps: they cannot be installed or run.

    AAPT2=~/Android/Sdk/build-tools/36.1.0/aapt2 ANDROID_JAR=~/Android/Sdk/platforms/android-34/android.jar python tools/make_apk_fixtures.py
"""
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "packs" / "core" / "apk"
AAPT2 = os.path.expanduser(os.environ.get("AAPT2", "~/Android/Sdk/build-tools/36.1.0/aapt2"))
JAR = os.path.expanduser(os.environ.get("ANDROID_JAR", "~/Android/Sdk/platforms/android-34/android.jar"))
P = "android.permission."

APPS = {
    "benign_minimal": dict(pkg="io.example.minimal", label="Minimal", perms=["INTERNET"]),
    "torch_ok": dict(pkg="io.example.torch", label="Torch", perms=["CAMERA", "FLASHLIGHT", "VIBRATE"]),
    "fake_pmkisan": dict(pkg="com.pmkisan.yojana.free", label="PM Kisan Yojana",
                         perms=["INTERNET", "READ_SMS", "RECEIVE_SMS", "SEND_SMS", "READ_CONTACTS"],
                         receivers=[dict(name=".SmsReceiver", actions=["android.provider.Telephony.SMS_RECEIVED"])]),
    "banking_trojan": dict(pkg="com.secure.bank.update", label="Bank Security Update",
                           perms=["INTERNET", "READ_SMS", "RECEIVE_SMS", "SYSTEM_ALERT_WINDOW", "REQUEST_INSTALL_PACKAGES"],
                           services=[dict(name=".Helper", permission=P + "BIND_ACCESSIBILITY_SERVICE",
                                          actions=["android.accessibilityservice.AccessibilityService"])],
                           receivers=[dict(name=".Admin", permission=P + "BIND_DEVICE_ADMIN",
                                           actions=["android.app.action.DEVICE_ADMIN_ENABLED"])]),
    "loan_app": dict(pkg="com.quick.cash.loan", label="Quick Cash",
                     perms=["INTERNET", "READ_CONTACTS", "READ_CALL_LOG", "CAMERA", "READ_EXTERNAL_STORAGE", "ACCESS_FINE_LOCATION", "READ_PHONE_STATE"]),
    "call_forwarder": dict(pkg="com.rto.challan.pay", label="RTO Challan",
                           perms=["INTERNET", "CALL_PHONE", "PROCESS_OUTGOING_CALLS", "READ_PHONE_STATE", "ANSWER_PHONE_CALLS"]),
}


def manifest(a):
    def comp(tag, c):
        perm = f' android:permission="{c["permission"]}"' if c.get("permission") else ""
        actions = "".join(f'<action android:name="{x}"/>' for x in c["actions"])
        return f'<{tag} android:name="{c["name"]}" android:exported="true"{perm}><intent-filter>{actions}</intent-filter></{tag}>'
    perms = "".join(f'<uses-permission android:name="{P}{p}"/>' for p in a["perms"])
    comps = "".join(comp("service", c) for c in a.get("services", [])) + "".join(comp("receiver", c) for c in a.get("receivers", []))
    return (f'<?xml version="1.0" encoding="utf-8"?><manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{a["pkg"]}">'
            f'{perms}<application android:label="{a["label"]}">{comps}</application></manifest>')


def build(name, a):
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "AndroidManifest.xml").write_text(manifest(a), encoding="utf-8")
        subprocess.run([AAPT2, "link", "-o", str(OUT / f"{name}.apk"), "-I", JAR, "--manifest", str(Path(d) / "AndroidManifest.xml"),
                        "--min-sdk-version", "21", "--target-sdk-version", "34", "--version-code", "1", "--version-name", "1.0"],
                       check=True, capture_output=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, a in APPS.items():
        build(name, a)
    with zipfile.ZipFile(OUT / "empty_zip.apk", "w") as z:  # a zip with no manifest
        z.writestr("readme.txt", "not an app")
    (OUT / "not_an_apk.apk").write_bytes(bytes(range(256)) * 4)  # not even a zip
    # what each fixture really contains, straight from the spec above (NOT from our parser), so the parser is tested against independent truth
    import json
    truth = {}
    for name, a in APPS.items():
        comps = a.get("services", []) + a.get("receivers", [])
        truth[name + ".apk"] = {
            "package": a["pkg"], "label": a["label"],
            "permissions": sorted(P + p for p in a["perms"]),
            "component_permissions": sorted({c["permission"] for c in comps if c.get("permission")}),
            "actions": sorted({x for c in comps for x in c["actions"]}),
            "min_sdk": 21, "target_sdk": 34,
        }
    (OUT / "expected.json").write_text(json.dumps(truth, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print("fixtures:", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
