// Organisation dashboard. No framework, no storage: the API key lives in a JS variable and disappears on reload.
// Every piece of text that comes from the server is put on the page with textContent, never as HTML.
(() => {
  'use strict';
  const T = {
    hi: {
      title: 'ScamSaathi संस्था डैशबोर्ड', loginTitle: 'संस्था में प्रवेश',
      loginHelp: 'अपनी संस्था की API कुंजी डालें। कुंजी सिर्फ इस पेज की मेमोरी में रहती है और पेज बंद या रीलोड करते ही मिट जाती है।',
      keyLabel: 'API कुंजी', loginBtn: 'प्रवेश', badKey: 'कुंजी सही नहीं है।', network: 'सर्वर से बात नहीं हो पाई। बाद में कोशिश करें।',
      logout: 'बाहर निकलें', district: 'ज़िला',
      verifiedYes: 'सत्यापित संस्था: आप चेतावनी भेज सकते हैं और संकेत पक्के कर सकते हैं।',
      verifiedNo: 'यह संस्था अभी सत्यापित नहीं है, इसलिए चेतावनी भेजना और संकेत पक्का करना बंद है। आँकड़े देखे जा सकते हैं।',
      trendTitle: 'आपके ज़िले में पिछले 30 दिन', trendHelp: 'पुष्ट ठगी संकेत (लिंक, UPI आईडी, ऐप फ़ाइल) किस प्रकार के आए। कोई मैसेज या व्यक्ति नहीं दिखता।',
      noData: 'अभी आपके ज़िले में कोई पुष्ट संकेत नहीं है।',
      alertsTitle: 'ज़िले के लोगों को चेतावनी', alertsHelp: 'सिर्फ सत्यापित संस्थाएँ चेतावनी भेज सकती हैं। चेतावनी में लिंक या वेब पता नहीं हो सकता।',
      aTitle: 'शीर्षक', aEn: 'अंग्रेज़ी में संदेश', aHi: 'हिन्दी में संदेश', aFam: 'ठगी का प्रकार (वैकल्पिक)', aDays: 'कितने दिन दिखे', none: '—',
      aBtn: 'चेतावनी प्रकाशित करें', aOk: 'चेतावनी प्रकाशित हो गई।', noAlerts: 'अभी कोई चेतावनी नहीं।', until: 'तक',
      reportTitle: 'ठगी का संकेत पक्का करें',
      reportHelp: 'सत्यापित संस्था की रिपोर्ट तुरंत पक्की मानी जाती है। असली बैंक या सरकारी साइटें स्वीकार नहीं होतीं। आपका ब्राउज़र भेजने से पहले मान को हैश कर देता है, इसलिए सर्वर को असली वेबसाइट या आईडी नहीं दिखती।',
      rKind: 'प्रकार', rFam: 'ठगी का प्रकार', rValue: 'मान', rBtn: 'पक्का करें', rOk: 'दर्ज हो गया।',
      kDomain: 'वेबसाइट', kUpi: 'UPI आईडी', kApk: 'ऐप फ़ाइल का SHA-256',
      badValue: 'यह मान सही रूप में नहीं है।', foot: 'यह पेज आपकी कुंजी कहीं सहेजता नहीं।',
      other: { notVerified: 'आपकी संस्था सत्यापित नहीं है।', throttled: 'बहुत ज़्यादा अनुरोध। थोड़ी देर बाद कोशिश करें।', failed: 'यह नहीं हो सका।' },
    },
    en: {
      title: 'ScamSaathi organisation dashboard', loginTitle: 'Organisation sign-in',
      loginHelp: "Enter your organisation's API key. It stays in this page's memory only and is gone when you close or reload the page.",
      keyLabel: 'API key', loginBtn: 'Sign in', badKey: 'That key is not valid.', network: 'Could not reach the server. Please try again later.',
      logout: 'Sign out', district: 'District',
      verifiedYes: 'Verified organisation: you can publish alerts and confirm indicators.',
      verifiedNo: 'This organisation is not verified yet, so publishing alerts and confirming indicators is off. You can see the numbers.',
      trendTitle: 'In your district, last 30 days', trendHelp: 'Confirmed scam indicators (links, UPI IDs, app files) by kind of scam. No messages or people are shown.',
      noData: 'No confirmed indicators in your district yet.',
      alertsTitle: 'Alerts to people in your district', alertsHelp: 'Only verified organisations can publish alerts. Alerts cannot contain links or web addresses.',
      aTitle: 'Title', aEn: 'Message in English', aHi: 'Message in Hindi', aFam: 'Kind of scam (optional)', aDays: 'Show for how many days', none: '—',
      aBtn: 'Publish alert', aOk: 'Alert published.', noAlerts: 'No alerts yet.', until: 'until',
      reportTitle: 'Confirm a scam indicator',
      reportHelp: "A verified organisation's report is confirmed at once. Real bank and government sites are refused. Your browser hashes the value before sending, so the server never sees the website or ID.",
      rKind: 'Kind', rFam: 'Kind of scam', rValue: 'Value', rBtn: 'Confirm', rOk: 'Recorded.',
      kDomain: 'Website', kUpi: 'UPI ID', kApk: 'App file SHA-256',
      badValue: 'That value is not in a valid form.', foot: 'This page never saves your key.',
      other: { notVerified: 'Your organisation is not verified.', throttled: 'Too many requests. Try again in a little while.', failed: 'That did not work.' },
    },
  };
  const FAMILY = {
    fake_apk: ['नकली ऐप फ़ाइल', 'Fake app file'], kyc_bank: ['नकली बैंक केवाईसी / ओटीपी', 'Fake bank KYC / OTP'], upi_collect: ['UPI से पैसे निकालने की चाल', 'UPI money-request trick'],
    job_scholarship: ['नकली नौकरी / स्कॉलरशिप', 'Fake job or scholarship'], loan_app: ['नकली लोन / ब्लैकमेल', 'Fake loan or blackmail'], govt_scheme: ['नकली सरकारी योजना', 'Fake government scheme'],
    prize_lottery: ['नकली इनाम / लॉटरी', 'Fake prize or lottery'], advance_fee: ['पहले पैसे माँगना', 'Asking for money first'], impersonation: ['पुलिस / अधिकारी बनकर डराना', 'Pretending to be police or an officer'],
    remote_access: ['रिमोट कंट्रोल ऐप', 'Remote-control app'], utility_threat: ['बिजली / गैस कटने की धमकी', 'Electricity or gas cut-off threat'], courier_parcel: ['नकली कूरियर / कस्टम पार्सल', 'Fake courier or customs parcel'],
    investment_scam: ['नकली निवेश / पैसे दोगुने', 'Fake investment or doubling'], family_emergency: ['रिश्तेदार बनकर पैसे माँगना', 'Pretending to be a relative in trouble'], marketplace_scam: ['नकली खरीदार / विक्रेता', 'Fake buyer or seller'],
  };
  const $ = (id) => document.getElementById(id);
  let lang = 'hi', key = null, families = [], me = null;

  const t = () => T[lang];
  const famName = (f) => (FAMILY[f] ? FAMILY[f][lang === 'hi' ? 0 : 1] : f);

  function setText() {
    const s = t();
    document.documentElement.lang = lang;
    const map = { title: 'title', loginTitle: 'loginTitle', loginHelp: 'loginHelp', keyLabel: 'keyLabel', loginBtn: 'loginBtn', logout: 'logout',
      trendTitle: 'trendTitle', trendHelp: 'trendHelp', noData: 'noData', alertsTitle: 'alertsTitle', alertsHelp: 'alertsHelp',
      aTitleL: 'aTitle', aEnL: 'aEn', aHiL: 'aHi', aFamL: 'aFam', aDaysL: 'aDays', aBtn: 'aBtn', reportTitle: 'reportTitle', reportHelp: 'reportHelp',
      rKindL: 'rKind', rFamL: 'rFam', rValueL: 'rValue', rBtn: 'rBtn', foot: 'foot' };
    for (const [id, k] of Object.entries(map)) $(id).textContent = s[k];
    $('lang').textContent = lang === 'hi' ? 'English' : 'हिन्दी';
    const kinds = $('rKind').options;
    kinds[0].textContent = s.kDomain; kinds[1].textContent = s.kUpi; kinds[2].textContent = s.kApk;
    fillSelect($('aFam'), true); fillSelect($('rFam'), false);
    fillDays();
    if (me) render(me);
  }

  function fillSelect(sel, optional) {
    const keep = sel.value;
    sel.replaceChildren();
    if (optional) { const o = document.createElement('option'); o.value = ''; o.textContent = t().none; sel.append(o); }
    for (const f of families) { const o = document.createElement('option'); o.value = f; o.textContent = famName(f); sel.append(o); }
    if (keep) sel.value = keep;
  }

  function fillDays() {
    const sel = $('aDays'), keep = sel.value || '7';
    sel.replaceChildren();
    for (const d of [1, 3, 7, 14, 30]) { const o = document.createElement('option'); o.value = String(d); o.textContent = String(d); sel.append(o); }
    sel.value = keep;
  }

  async function api(path, options = {}) {
    const res = await fetch(path, { ...options, headers: { 'Content-Type': 'application/json', Authorization: 'Api-Key ' + key, ...(options.headers || {}) }, cache: 'no-store' });
    let body = null;
    try { body = await res.json(); } catch (_) { /* not JSON */ }
    return { status: res.status, body };
  }

  function explain(res) {
    const o = t().other;
    if (res.status === 401) return t().badKey;
    if (res.status === 403) return o.notVerified;
    if (res.status === 429) return o.throttled;
    if (res.status === 400 && res.body && typeof res.body === 'object') {
      const parts = [];
      for (const v of Object.values(res.body)) parts.push(Array.isArray(v) ? v.join(' ') : String(v));
      if (parts.length) return parts.join(' ');
    }
    return o.failed;
  }

  function render(d) {
    const s = t();
    $('orgName').textContent = d.organisation;
    $('orgMeta').textContent = s.district + ': ' + d.district;
    $('verified').textContent = d.verified ? s.verifiedYes : s.verifiedNo;
    for (const id of ['aBtn', 'rBtn']) $(id).disabled = !d.verified;
    const bars = $('bars'); bars.replaceChildren();
    const entries = Object.entries(d.confirmed_indicators_by_family).sort((a, b) => b[1] - a[1]);
    $('noData').hidden = entries.length > 0;
    const max = Math.max(1, ...entries.map((e) => e[1]));
    for (const [fam, n] of entries) {
      const li = document.createElement('li'), name = document.createElement('div'), track = document.createElement('div'), fill = document.createElement('div');
      name.className = 'name'; track.className = 'track'; fill.className = 'fill'; fill.style.width = Math.round((100 * n) / max) + '%';
      const a = document.createElement('span'), b = document.createElement('strong'); a.textContent = famName(fam); b.textContent = String(n);
      name.append(a, b); track.append(fill); li.append(name, track); bars.append(li);
    }
  }

  async function loadAlerts() {
    const res = await api('/v1/org/alerts');
    const ul = $('alerts'); ul.replaceChildren();
    if (res.status !== 200) return;
    if (!res.body.length) { const li = document.createElement('li'); li.className = 'meta'; li.textContent = t().noAlerts; ul.append(li); return; }
    for (const a of res.body) {
      const li = document.createElement('li'), h = document.createElement('strong'), p = document.createElement('div'), m = document.createElement('div');
      h.textContent = a.title; p.textContent = lang === 'hi' ? a.body_hi : a.body_en; m.className = 'meta';
      m.textContent = [a.family ? famName(a.family) : '', t().until + ' ' + new Date(a.expires_at).toLocaleDateString()].filter(Boolean).join(' · ');
      li.append(h, p, m); ul.append(li);
    }
  }

  async function loadFamilies() {
    try {
      const res = await fetch('/v1/packs/core/pack.json', { cache: 'no-store' });
      const body = await res.json();
      families = Array.isArray(body.families) ? body.families : Object.keys(FAMILY);  // an unavailable pack must not break the page
    } catch (_) { families = Object.keys(FAMILY); }
    families = families.filter((f) => f !== 'generic');
  }

  async function show() {
    const res = await api('/v1/org/dashboard');
    if (res.status !== 200) { $('loginError').textContent = res.status === 401 ? t().badKey : explain(res); key = null; return false; }
    me = res.body;
    $('login').hidden = true; $('app').hidden = false; $('logout').hidden = false;
    await loadFamilies(); setText(); await loadAlerts();
    return true;
  }

  async function sha256Hex(text) {
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
  }

  function normalise(kind, raw) {
    let v = raw.trim().toLowerCase();
    if (kind === 'domain') {
      v = v.replace(/^[a-z]+:\/\//, '').split(/[/?#]/)[0].replace(/^.*@/, '').replace(/:\d+$/, '').replace(/\.+$/, '');
      return /^[a-z0-9][a-z0-9.-]*\.[a-z0-9-]{2,}$/.test(v) ? v : null;
    }
    if (kind === 'upi') return /^[a-z0-9._-]{2,}@[a-z]{2,}$/.test(v) ? v : null;
    return /^[0-9a-f]{64}$/.test(v) ? v : null;
  }

  $('lang').addEventListener('click', () => { lang = lang === 'hi' ? 'en' : 'hi'; setText(); if (me) loadAlerts(); });
  $('logout').addEventListener('click', () => { key = null; me = null; $('app').hidden = true; $('login').hidden = false; $('logout').hidden = true; $('key').value = ''; $('alerts').replaceChildren(); });

  $('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault(); $('loginError').textContent = '';
    key = $('key').value.trim(); $('key').value = '';
    try { await show(); } catch (_) { $('loginError').textContent = t().network; key = null; }
  });

  $('alertForm').addEventListener('submit', async (e) => {
    e.preventDefault(); const msg = $('aMsg'); msg.className = ''; msg.textContent = '';
    const body = { title: $('aTitle').value, body_en: $('aEn').value, body_hi: $('aHi').value, family: $('aFam').value, days: Number($('aDays').value) };
    const res = await api('/v1/org/alerts', { method: 'POST', body: JSON.stringify(body) });
    if (res.status === 201) {
      $('alertForm').reset(); fillDays();
      await loadAlerts();  // refresh the list first, so the message never appears before the list it talks about
      const d = await api('/v1/org/dashboard'); if (d.status === 200) { me = d.body; render(me); }
      msg.className = 'ok'; msg.textContent = t().aOk;
    }
    else { msg.className = 'error'; msg.textContent = explain(res); }
  });

  $('reportForm').addEventListener('submit', async (e) => {
    e.preventDefault(); const msg = $('rMsg'); msg.className = ''; msg.textContent = '';
    const kind = $('rKind').value, value = normalise(kind, $('rValue').value);
    if (!value) { msg.className = 'error'; msg.textContent = t().badValue; return; }
    const hash = kind === 'apk_sha256' ? value : await sha256Hex(value);
    const res = await api('/v1/org/reports', { method: 'POST', body: JSON.stringify({ kind, value_hash: hash, family: $('rFam').value }) });
    if (res.status === 200 || res.status === 201) {
      msg.className = 'ok'; msg.textContent = t().rOk; $('rValue').value = '';
      const d = await api('/v1/org/dashboard'); if (d.status === 200) { me = d.body; render(me); }
    } else { msg.className = 'error'; msg.textContent = explain(res); }
  });

  setText();
})();
