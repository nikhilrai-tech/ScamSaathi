from io import StringIO

from django.core.management import call_command
from testutil import ApiTestCase, hx

from intel.hashing import sha256_hex
from intel.models import Indicator
from orgs.models import Alert, Organization


def make_org(slug="coop-nashik", district="nashik", verified=True):
    out = StringIO()
    call_command("createorg", name=slug.title(), slug=slug, district=district, kind="coop_bank",
                 verified=verified, stdout=out)
    return out.getvalue().strip().split(": ")[-1]


ALERT = {"title": "Fake crop insurance app", "body_en": "A fake crop insurance app is going around. Do not install it.",
         "body_hi": "फसल बीमा का नकली ऐप फैल रहा है। इसे इंस्टॉल न करें।", "family": "fake_apk", "days": 5}


class AuthTests(ApiTestCase):
    def test_key_is_printed_once_and_only_its_hash_is_stored(self):
        key = make_org()
        org = Organization.objects.get()
        self.assertTrue(key.startswith("ssk_"))
        self.assertEqual(org.api_key_hash, sha256_hex(key))
        self.assertNotIn(key, org.api_key_hash)

    def test_no_key_or_wrong_key_is_rejected(self):
        make_org()
        self.assertEqual(self.client.get("/v1/org/dashboard").status_code, 401)
        r = self.client.get("/v1/org/dashboard", HTTP_AUTHORIZATION="Api-Key ssk_wrong")
        self.assertEqual(r.status_code, 401)
        r = self.client.get("/v1/org/dashboard", HTTP_AUTHORIZATION="Api-Key")
        self.assertEqual(r.status_code, 401)

    def test_deactivated_org_loses_access_at_once(self):
        key = make_org()
        Organization.objects.update(active=False)
        r = self.client.get("/v1/org/dashboard", HTTP_AUTHORIZATION=f"Api-Key {key}")
        self.assertEqual(r.status_code, 401)


class AlertTests(ApiTestCase):
    def auth(self, key):
        return {"HTTP_AUTHORIZATION": f"Api-Key {key}"}

    def test_unverified_org_cannot_publish(self):
        key = make_org(verified=False)
        r = self.client.post("/v1/org/alerts", ALERT, format="json", **self.auth(key))
        self.assertEqual(r.status_code, 403)
        self.assertEqual(Alert.objects.count(), 0)

    def test_alerts_with_links_are_refused(self):
        key = make_org()
        for bad in ("Install from http://evil.top/a", "see www.evil.com", "go to kisan-help.xyz now", "get PM-Kisan.apk"):
            r = self.client.post("/v1/org/alerts", {**ALERT, "body_en": bad}, format="json", **self.auth(key))
            self.assertEqual(r.status_code, 400, bad)
        self.assertEqual(Alert.objects.count(), 0)

    def test_publish_and_public_listing_is_scoped_to_district_and_expiry(self):
        key = make_org()
        other = make_org("coop-pune", "pune")
        self.assertEqual(self.client.post("/v1/org/alerts", ALERT, format="json", **self.auth(key)).status_code, 201)
        self.client.post("/v1/org/alerts", {**ALERT, "title": "Pune only"}, format="json", **self.auth(other))
        mine = self.client.get("/v1/alerts", {"district": "NASHIK"}).json()
        self.assertEqual([a["title"] for a in mine], ["Fake crop insurance app"])
        self.assertEqual(mine[0]["organisation"], "Coop-Nashik")
        Alert.objects.filter(district="nashik").update(expires_at="2000-01-01T00:00:00Z")
        self.assertEqual(self.client.get("/v1/alerts", {"district": "nashik"}).json(), [])

    def test_unverified_org_alerts_are_never_public(self):
        key = make_org()
        self.client.post("/v1/org/alerts", ALERT, format="json", **self.auth(key))
        Organization.objects.update(verified=False)  # verification withdrawn later
        self.assertEqual(self.client.get("/v1/alerts", {"district": "nashik"}).json(), [])

    def test_district_is_required(self):
        self.assertEqual(self.client.get("/v1/alerts").status_code, 400)

    def test_days_are_limited(self):
        key = make_org()
        r = self.client.post("/v1/org/alerts", {**ALERT, "days": 400}, format="json", **self.auth(key))
        self.assertEqual(r.status_code, 400)


class OrgReportAndDashboardTests(ApiTestCase):
    def auth(self, key):
        return {"HTTP_AUTHORIZATION": f"Api-Key {key}"}

    def report(self, key, value="a"):
        return self.client.post("/v1/org/reports", {"kind": "apk_sha256", "value_hash": hx(value), "family": "fake_apk"},
                                format="json", **self.auth(key))

    def test_verified_org_report_confirms_immediately(self):
        r = self.report(make_org())
        self.assertEqual((r.status_code, r.json()["confirmed"]), (201, True))
        self.assertTrue(Indicator.objects.get().confirmed)

    def test_unverified_org_report_is_refused(self):
        self.assertEqual(self.report(make_org(verified=False)).status_code, 403)
        self.assertEqual(Indicator.objects.count(), 0)

    def test_org_still_cannot_confirm_an_official_domain(self):
        key = make_org()
        r = self.client.post("/v1/org/reports", {"kind": "domain", "value_hash": sha256_hex("hdfcbank.com"),
                                                 "family": "kyc_bank"}, format="json", **self.auth(key))
        self.assertEqual(r.status_code, 400)

    def test_dashboard_counts_only_the_orgs_own_district(self):
        nashik, pune = make_org(), make_org("coop-pune", "pune")
        self.report(nashik, "a")
        self.report(nashik, "b")
        self.report(pune, "c")
        d = self.client.get("/v1/org/dashboard", **self.auth(nashik)).json()
        self.assertEqual(d["confirmed_indicators_by_family"], {"fake_apk": 2})
        self.assertEqual(d["district"], "nashik")
        d = self.client.get("/v1/org/dashboard", **self.auth(pune)).json()
        self.assertEqual(d["confirmed_indicators_by_family"], {"fake_apk": 1})


class DashboardPageTests(ApiTestCase):
    def test_the_page_is_served_with_a_strict_content_security_policy(self):
        r = self.client.get("/org/")
        self.assertEqual(r.status_code, 200)
        csp = r["Content-Security-Policy"]
        for part in ("default-src 'none'", "script-src 'self'", "connect-src 'self'", "frame-ancestors 'none'"):
            self.assertIn(part, csp)
        self.assertNotIn("unsafe-inline", csp)
        self.assertEqual((r["X-Content-Type-Options"], r["Referrer-Policy"], r["Cache-Control"]), ("nosniff", "no-referrer", "no-store"))

    def test_the_page_has_no_inline_script_and_loads_only_its_own_files(self):
        import re
        html = self.client.get("/org/").content.decode()
        self.assertFalse(re.search(r"<script(?![^>]*\bsrc=)[^>]*>", html), "inline script found")
        self.assertNotRegex(html, r"https?://(?!www\.w3\.org)")  # no external resources
        for url in re.findall(r'(?:src|href)="(/static/[^"?]+)', html):
            self.assertEqual(self.client.get(url).status_code, 200, url)

    def test_the_script_never_writes_server_text_as_html_or_stores_the_key(self):
        import pathlib
        js = (pathlib.Path(__file__).resolve().parents[1] / "dashboard/static/dashboard/app.js").read_text(encoding="utf-8")
        for banned in ("innerHTML", "outerHTML", "insertAdjacentHTML", "document.write", "eval(", "localStorage", "sessionStorage", "document.cookie"):
            self.assertNotIn(banned, js, banned)

    def test_only_get_is_allowed(self):
        self.assertEqual(self.client.post("/org/").status_code, 405)

    def test_the_dashboard_api_says_whether_the_organisation_is_verified(self):
        key = make_org(verified=False)
        d = self.client.get("/v1/org/dashboard", HTTP_AUTHORIZATION=f"Api-Key {key}").json()
        self.assertIs(d["verified"], False)
