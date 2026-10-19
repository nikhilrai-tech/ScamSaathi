// The organisation dashboard, driven in real Chrome against a real Django server started just for this test (temporary database and a
// temporary, throw-away signing key). Needs Python with the API requirements installed:  PYTHON=/path/to/python npm test
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn, execFileSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const puppeteer = require('puppeteer-core');

const ROOT = path.join(__dirname, '..');
const PYTHON = process.env.PYTHON || 'python3';
const CHROME = process.env.CHROME_PATH || '/usr/bin/google-chrome';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let server, browser, base, tmp, keys = {};

function manage(env, ...args) {
  return execFileSync(PYTHON, [path.join(ROOT, 'api', 'manage.py'), ...args], { env, encoding: 'utf8' });
}

test.before(async () => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-dash-'));
  const packs = path.join(tmp, 'core');
  fs.mkdirSync(packs);
  fs.copyFileSync(path.join(ROOT, 'packs/core/pack.json'), path.join(packs, 'pack.json'));
  const sign = (...a) => execFileSync(PYTHON, [path.join(ROOT, 'tools/packsign.py'), ...a], { encoding: 'utf8' });
  sign('genkey', '--private', path.join(tmp, 'k.private'), '--public', path.join(tmp, 'k.pub'));
  sign('sign', '--private', path.join(tmp, 'k.private'), '--pack', path.join(packs, 'pack.json'));
  const port = 20000 + Math.floor(Math.random() * 20000);
  const env = { ...process.env, SCAMSAATHI_DEBUG: '1', SCAMSAATHI_SECRET_KEY: 'e2e-only', SCAMSAATHI_DB: path.join(tmp, 'db.sqlite3'),
    SCAMSAATHI_PACKS_DIR: packs, SCAMSAATHI_PACK_PUBLIC_KEY: path.join(tmp, 'k.pub') };
  manage(env, 'migrate', '-v0');
  const make = (slug, name, extra) => /ssk_[\w-]+/.exec(manage(env, 'createorg', '--name', name, '--slug', slug, '--district', 'nashik', '--kind', 'fpo', ...extra))[0];
  keys.verified = make('fpo-nashik', 'Nashik FPO', ['--verified']);
  keys.unverified = make('school-nashik', 'Nashik School', []);
  server = spawn(PYTHON, [path.join(ROOT, 'api', 'manage.py'), 'runserver', `127.0.0.1:${port}`, '--noreload'], { env, stdio: 'ignore' });
  base = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 100; i++) { try { if ((await fetch(base + '/healthz')).ok) break; } catch (_) { /* not up yet */ } await sleep(200); }
  // two confirmed indicators in the district, reported by the verified organisation
  const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
  for (const [v, family] of [['evil-kyc-a.xyz', 'kyc_bank'], ['evil-kyc-b.xyz', 'kyc_bank'], ['fake-yojana.top', 'govt_scheme']]) {
    const r = await fetch(base + '/v1/org/reports', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Api-Key ' + keys.verified },
      body: JSON.stringify({ kind: 'domain', value_hash: sha(v), family }) });
    assert.ok(r.ok, `seeding failed: ${r.status}`);
  }
  browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
});

test.after(async () => {
  await browser?.close();
  server?.kill();
  if (tmp) fs.rmSync(tmp, { recursive: true, force: true });
});

async function open() {
  const page = await browser.newPage();
  const requests = [];
  page.on('request', (r) => requests.push({ method: r.method(), url: r.url(), body: r.postData() || '' }));
  await page.setViewport({ width: 900, height: 1400 });
  await page.goto(base + '/org/', { waitUntil: 'networkidle0' });
  await page.select('#aDays', '7').catch(() => {});
  return { page, requests };
}
async function login(page, key) {
  await page.type('#key', key);
  await page.click('#loginBtn');
}
async function text(page, sel) { return page.$eval(sel, (e) => e.textContent); }
async function waitFor(page, fn, arg, ms = 8000) { await page.waitForFunction(fn, { timeout: ms }, arg); }

test('a wrong key is refused clearly', async () => {
  const { page } = await open();
  await page.click('#lang'); // English
  await login(page, 'ssk_wrong');
  await waitFor(page, () => document.getElementById('loginError').textContent.length > 0);
  assert.match(await text(page, '#loginError'), /not valid/);
  assert.equal(await page.$eval('#app', (e) => e.hidden), true);
  await page.close();
});

test('the verified organisation sees its district numbers by kind of scam, with no messages or people', async () => {
  const { page } = await open();
  await page.click('#lang');
  await login(page, keys.verified);
  await waitFor(page, () => !document.getElementById('app').hidden);
  assert.equal(await text(page, '#orgName'), 'Nashik FPO');
  const bars = await page.$$eval('#bars li', (lis) => lis.map((l) => l.textContent.replace(/\s+/g, ' ').trim()));
  assert.ok(bars.some((b) => b.includes('Fake bank KYC') && b.endsWith('2')), bars.join(' | '));
  assert.ok(bars.some((b) => b.includes('Fake government scheme') && b.endsWith('1')), bars.join(' | '));
  assert.match(await text(page, '#verified'), /Verified organisation/);
  await page.screenshot({ path: path.join(__dirname, 'artifacts', 'dashboard.png') });
  await page.close();
});

test('alerts: a link is refused with the reason, a good alert is published and is public for the district', async () => {
  const { page } = await open();
  await page.click('#lang');
  await login(page, keys.verified);
  await waitFor(page, () => !document.getElementById('app').hidden);
  await page.type('#aTitle', 'Fake crop insurance app');
  await page.type('#aEn', 'Install it from http://evil.top/a');
  await page.type('#aHi', 'यह ऐप इंस्टॉल न करें।');
  await page.click('#aBtn');
  await waitFor(page, () => document.getElementById('aMsg').textContent.length > 0);
  assert.match(await text(page, '#aMsg'), /links/i);
  await page.$eval('#aEn', (e) => { e.value = 'A fake crop insurance app is going around. Do not install it.'; });
  await page.click('#aBtn');
  await waitFor(page, () => document.getElementById('aMsg').textContent === 'Alert published.');
  assert.ok((await text(page, '#alerts')).includes('Fake crop insurance app'));
  const pub = await (await fetch(base + '/v1/alerts?district=nashik')).json();
  assert.ok(pub.some((a) => a.title === 'Fake crop insurance app' && a.organisation === 'Nashik FPO'));
  await page.close();
});

test('server text can never become page markup (an alert titled with HTML is shown as plain text)', async () => {
  const { page } = await open();
  await page.click('#lang');
  await login(page, keys.verified);
  await waitFor(page, () => !document.getElementById('app').hidden);
  const evil = '<img src=x onerror=window.pwned=1>';
  await page.type('#aTitle', evil);
  await page.type('#aEn', 'Plain words only, nothing else here.');
  await page.type('#aHi', 'सिर्फ़ सादा शब्द।');
  await page.click('#aBtn');
  await waitFor(page, () => document.getElementById('aMsg').textContent === 'Alert published.');
  assert.ok((await text(page, '#alerts')).includes(evil), 'shown literally');
  assert.equal(await page.$$eval('#alerts img', (n) => n.length), 0, 'no element was created from it');
  assert.equal(await page.evaluate(() => window.pwned), undefined, 'no script ran');
  await page.close();
});

test('confirming a scam website sends only its hash; a real bank site is refused', async () => {
  const { page, requests } = await open();
  await page.click('#lang');
  await login(page, keys.verified);
  await waitFor(page, () => !document.getElementById('app').hidden);
  await page.type('#rValue', 'HTTP://Evil-Kyc-C.XYZ/verify?id=9');
  await page.click('#rBtn');
  await waitFor(page, () => document.getElementById('rMsg').textContent === 'Recorded.');
  const body = requests.filter((r) => r.method === 'POST' && r.url.endsWith('/v1/org/reports')).map((r) => r.body).join('\n');
  assert.ok(!/evil-kyc-c/i.test(body), 'the website must not appear in the request');
  const want = crypto.createHash('sha256').update('evil-kyc-c.xyz').digest('hex');
  assert.ok(body.includes(want), 'normalised and hashed in the browser');
  const feed = await (await fetch(base + '/v1/feed')).json();
  assert.ok(feed.indicators.some((i) => i.hash === want));
  await page.$eval('#rValue', (e) => { e.value = ''; });
  await page.type('#rValue', 'sbi.co.in');
  await page.click('#rBtn');
  await waitFor(page, () => document.getElementById('rMsg').className === 'error' && document.getElementById('rMsg').textContent.length > 0);
  assert.match(await text(page, '#rMsg'), /official/i);
  await page.close();
});

test('an unverified organisation can look but not publish or confirm', async () => {
  const { page } = await open();
  await page.click('#lang');
  await login(page, keys.unverified);
  await waitFor(page, () => !document.getElementById('app').hidden);
  assert.match(await text(page, '#verified'), /not verified/);
  assert.equal(await page.$eval('#aBtn', (b) => b.disabled), true);
  assert.equal(await page.$eval('#rBtn', (b) => b.disabled), true);
  await page.close();
});

test('the key is never saved: nothing in storage, and a reload asks again; the language switch works', async () => {
  const { page } = await open();
  await login(page, keys.verified);
  await waitFor(page, () => !document.getElementById('app').hidden);
  assert.deepEqual(await page.evaluate(() => [localStorage.length, sessionStorage.length, document.cookie]), [0, 0, '']);
  assert.match(await text(page, '#trendTitle'), /आपके ज़िले/);
  await page.click('#lang');
  assert.match(await text(page, '#trendTitle'), /In your district/);
  await page.reload({ waitUntil: 'networkidle0' });
  assert.equal(await page.$eval('#login', (e) => e.hidden), false);
  assert.equal(await page.$eval('#app', (e) => e.hidden), true);
  await page.close();
});
