import hashlib
import json
from unittest import mock

from testutil import ApiTestCase, hx

from intel.hashing import sha256_hex
from intel.models import Indicator
from intel.views import ReportThrottle


def body(**kw):
    base = {"kind": "domain", "value_hash": hx("a"), "family": "kyc_bank", "reporter_hash": hx("1"), "district": "Nashik"}
    base.update(kw)
    return base


class PackTests(ApiTestCase):
    def test_manifest_matches_the_served_bytes(self):
        m = self.client.get("/v1/packs/core/manifest").json()
        raw = self.client.get(m["url"]).content
        self.assertEqual(hashlib.sha256(raw).hexdigest(), m["sha256"])
        self.assertEqual((m["alg"], m["name"]), ("ed25519", "core"))
        self.assertEqual(m["version"], json.loads(raw)["version"])

    def test_tampered_pack_is_never_served(self):
        p = self.pack_dir / "pack.json"
        original = p.read_bytes()
        p.write_bytes(original + b" ")  # any change at all, whatever the pack says
        self.assertNotEqual(p.read_bytes(), original)
        for url in ("/v1/packs/core/manifest", "/v1/packs/core/pack.json"):
            r = self.client.get(url)
            self.assertEqual(r.status_code, 503)
            self.assertNotIn("signature", r.content.decode())

    def test_unsigned_pack_is_never_served(self):
        (self.pack_dir / "pack.sig.json").unlink()
        self.assertEqual(self.client.get("/v1/packs/core/manifest").status_code, 503)

    def test_forged_signature_with_correct_hash_and_key_id_is_refused(self):
        import base64
        sig_file = self.pack_dir / "pack.sig.json"
        sig = json.loads(sig_file.read_text())
        sig["signature"] = base64.b64encode(b"\x00" * 64).decode()  # right sha256 and key_id, garbage signature
        sig_file.write_text(json.dumps(sig))
        self.assertEqual(self.client.get("/v1/packs/core/manifest").status_code, 503)
        self.assertEqual(self.client.get("/v1/packs/core/pack.json").status_code, 503)

    def test_pack_signed_by_another_key_is_refused(self):
        import packsign
        other_private, other_public = self.pack_dir.parent / "o.private", self.pack_dir.parent / "o.pub"
        packsign.genkey(other_private, other_public)
        packsign.sign(other_private, self.pack_dir / "pack.json")  # valid signature, but not by the pinned key
        self.assertEqual(self.client.get("/v1/packs/core/manifest").status_code, 503)


class PackSignToolTests(ApiTestCase):
    def test_verify_accepts_the_signed_pack_and_rejects_any_change(self):
        import packsign
        pack = self.pack_dir / "pack.json"
        self.assertTrue(packsign.verify(self.public, pack))
        pack.write_bytes(pack.read_bytes() + b" ")
        self.assertFalse(packsign.verify(self.public, pack))

    def test_private_key_is_owner_only_and_never_overwritten(self):
        import os
        import packsign
        self.assertEqual(os.stat(self.private).st_mode & 0o777, 0o600)
        with self.assertRaises(FileExistsError):
            packsign.genkey(self.private, self.public.with_name("other.pub"))


class ReportTests(ApiTestCase):
    def post(self, **kw):
        return self.client.post("/v1/reports", body(**kw), format="json")

    def test_three_distinct_reporters_confirm_an_indicator(self):
        self.assertFalse(self.post(reporter_hash=hx("1")).json()["confirmed"])
        self.assertFalse(self.post(reporter_hash=hx("2")).json()["confirmed"])
        self.assertTrue(self.post(reporter_hash=hx("3")).json()["confirmed"])

    def test_the_same_reporter_counts_once(self):
        for _ in range(5):
            r = self.post(reporter_hash=hx("1"))
        self.assertFalse(r.json()["confirmed"])
        self.assertEqual(Indicator.objects.get().reporter_weight, 1)
        self.assertEqual(r.status_code, 200)

    def test_official_domains_cannot_be_reported(self):
        r = self.post(value_hash=sha256_hex("sbi.co.in"))
        self.assertEqual(r.status_code, 400)
        self.assertEqual(Indicator.objects.count(), 0)

    def test_official_domain_rule_only_applies_to_domains(self):
        self.assertEqual(self.post(kind="upi", value_hash=sha256_hex("sbi.co.in")).status_code, 201)

    def test_rejects_raw_values_and_unknown_families(self):
        self.assertEqual(self.post(value_hash="evil.xyz").status_code, 400)           # must be a hash, never raw text
        self.assertEqual(self.post(value_hash="A" * 64).status_code, 400)             # lowercase hex only
        self.assertEqual(self.post(family="nonsense").status_code, 400)
        self.assertEqual(self.post(kind="phone").status_code, 400)
        self.assertEqual(self.post(district="x" * 80).status_code, 400)

    def test_response_and_storage_carry_no_message_text(self):
        extra = {"text": "your kyc is pending", "message": "secret"}
        r = self.post(**extra)
        self.assertNotIn("kyc", r.content.decode())
        fields = {f.name for f in Indicator._meta.get_fields()} | {f.name for f in Indicator.reports.rel.related_model._meta.get_fields()}
        self.assertFalse({"text", "message", "body", "content"} & fields)

    def test_first_report_decides_the_family(self):
        self.post(reporter_hash=hx("1"), family="kyc_bank")
        self.post(reporter_hash=hx("2"), family="fake_apk")
        self.assertEqual(Indicator.objects.get().family, "kyc_bank")

    def test_reports_are_rate_limited(self):
        with mock.patch.object(ReportThrottle, "rate", "3/min"):
            codes = [self.post(reporter_hash=hx(str(i))).status_code for i in range(5)]
        self.assertEqual(codes[:3], [201, 201, 201])
        self.assertEqual(codes[3:], [429, 429])

    def test_get_is_not_allowed_on_reports(self):
        self.assertEqual(self.client.get("/v1/reports").status_code, 405)


class FeedTests(ApiTestCase):
    def confirm(self, value, family="kyc_bank"):
        for i in "123":
            self.client.post("/v1/reports", body(value_hash=value, reporter_hash=hx(i), family=family), format="json")

    def test_only_confirmed_and_not_revoked_indicators_are_listed(self):
        self.confirm(hx("a"))
        self.client.post("/v1/reports", body(value_hash=hx("b")), format="json")  # one reporter: not confirmed
        self.confirm(hx("c"))
        Indicator.objects.filter(value_hash=hx("c")).update(revoked=True)
        feed = self.client.get("/v1/feed").json()["indicators"]
        self.assertEqual([i["hash"] for i in feed], [hx("a")])
        self.assertEqual(set(feed[0]), {"kind", "hash", "family"})  # nothing else leaks

    def test_since_returns_only_newer_confirmations(self):
        self.confirm(hx("a"))
        first = Indicator.objects.get(value_hash=hx("a")).confirmed_at.isoformat()
        self.confirm(hx("b"))
        feed = self.client.get("/v1/feed", {"since": first}).json()["indicators"]
        self.assertEqual([i["hash"] for i in feed], [hx("b")])

    def test_paging(self):
        for c in "abc":
            self.confirm(hx(c))
        with self.settings(FEED_PAGE_SIZE=2):
            page = self.client.get("/v1/feed").json()
        self.assertEqual(len(page["indicators"]), 2)
        self.assertTrue(page["next_since"])


class MaskingTests(ApiTestCase):
    def test_masking_matches_the_shared_vectors(self):
        import pathlib

        from intel.masking import mask
        cases = json.loads((pathlib.Path(__file__).resolve().parents[2] / "packs/core/masking_cases.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(cases), 15)
        for c in cases:
            self.assertEqual(mask(c["in"]), c["out"], c["in"])

    def test_masking_is_idempotent(self):
        from intel.masking import mask
        once = mask("Call 9876543210, OTP 482913, mail a.b@gmail.com, pay x.y@ybl, see http://evil.xyz/a?b=1")
        self.assertEqual(mask(once), once)


class FeedbackTests(ApiTestCase):
    def send(self, **kw):
        body = {"text": "Your KYC is pending, call 9876543210 now", "label": "scam", "app_verdict": "safe", "lang": "en"}
        body.update(kw)
        return self.client.post("/v1/feedback", body, format="json")

    def test_personal_details_are_masked_before_storing(self):
        from intel.models import Donation
        r = self.send(text="Ramesh, your OTP is 482913. Call 9876543210 or mail ram.k@gmail.com, pay ram.k@ybl, see https://evil.xyz/a?id=77")
        self.assertEqual(r.status_code, 201)
        stored = Donation.objects.get().text
        for secret in ("482913", "9876543210", "ram.k@gmail.com", "ram.k@ybl", "id=77"):
            self.assertNotIn(secret, stored)
        self.assertIn("evil.xyz", stored)  # the scam's own website is kept: it is the useful part

    def test_the_server_masks_even_if_the_client_did_not(self):
        from intel.models import Donation
        self.send(text="plain 9123456780 number sent by a client that skipped masking")
        self.assertNotIn("9123456780", Donation.objects.get().text)

    def test_answer_is_the_same_for_a_duplicate_and_it_is_stored_once(self):
        from intel.models import Donation
        a, b = self.send(), self.send()
        self.assertEqual((a.status_code, b.status_code, a.json(), b.json()), (201, 201, {"accepted": True}, {"accepted": True}))
        self.assertEqual(Donation.objects.count(), 1)

    def test_validation(self):
        self.assertEqual(self.send(label="maybe").status_code, 400)
        self.assertEqual(self.send(app_verdict="great").status_code, 400)
        self.assertEqual(self.send(text="hi").status_code, 400)
        self.assertEqual(self.send(text="x" * 1001).status_code, 400)
        self.assertEqual(self.send(text="a " * 400).status_code, 400)          # over 600 characters once masked
        self.assertEqual(self.send(family="nonsense").status_code, 400)
        self.assertEqual(self.send(lang="mr").status_code, 400)

    def test_nothing_that_identifies_the_sender_is_stored(self):
        from intel.models import Donation
        names = {f.name for f in Donation._meta.get_fields()}
        self.assertFalse({"ip", "ip_address", "device", "reporter_hash", "user", "session", "user_agent"} & names)
        self.assertEqual(names, {"id", "text", "text_hash", "label", "app_verdict", "family", "lang", "status", "created"})

    def test_feedback_is_rate_limited(self):
        from intel.views import FeedbackThrottle
        with mock.patch.object(FeedbackThrottle, "rate", "2/min"):
            codes = [self.send(text=f"message number {i} that is long enough").status_code for i in range(4)]
        self.assertEqual(codes, [201, 201, 429, 429])

    def test_new_donations_are_not_exported_until_a_person_accepts_them(self):
        import tempfile
        from io import StringIO

        from django.core.management import call_command

        from intel.models import Donation
        self.send(text="first message that is a scam", label="scam", family="kyc_bank")
        self.send(text="second message that is normal", label="normal", app_verdict="dangerous")
        out = tempfile.mkstemp(suffix=".jsonl")[1]
        call_command("export_donations", out=out, stdout=StringIO())
        self.assertEqual(open(out, encoding="utf-8").read(), "")
        Donation.objects.update(status="accepted")
        call_command("export_donations", out=out, stdout=StringIO())
        rows = [json.loads(line) for line in open(out, encoding="utf-8")]
        self.assertEqual({(r["label"], r["family"]) for r in rows}, {("scam", "kyc_bank"), ("benign", "none")})
        self.assertTrue(all(r["id"].startswith("donated-") for r in rows))
