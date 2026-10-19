// Real-browser end-to-end tests: drive the built web app in Chrome like a user would.
//   cd app && flutter build web --release && cd ../e2e && npm ci && npm test
// Flutter draws to a canvas, so we switch on its accessibility (semantics) tree and read/click that.
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require('puppeteer-core');

const WEB_DIR = process.env.WEB_DIR || path.join(__dirname, '..', 'app', 'build', 'web');
const CHROME = process.env.CHROME_PATH || '/usr/bin/google-chrome';
const ART = path.join(__dirname, 'artifacts');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm',
  '.png': 'image/png', '.otf': 'font/otf', '.ttf': 'font/ttf', '.ico': 'image/x-icon', '.css': 'text/css' };

// BASE_URL=https://host/path runs the same tests against a deployed site instead of the local build
let server, base, browser;

test.before(async () => {
  if (process.env.BASE_URL) {
    base = process.env.BASE_URL.replace(/\/$/, '');
    browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
    fs.mkdirSync(ART, { recursive: true });
    return;
  }
  assert.ok(fs.existsSync(path.join(WEB_DIR, 'index.html')), `no web build in ${WEB_DIR}; run flutter build web --release first`);
  server = http.createServer((req, res) => {
    const file = path.join(WEB_DIR, decodeURIComponent(new URL(req.url, 'http://x').pathname).replace(/\/$/, '/index.html'));
    if (!file.startsWith(WEB_DIR) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
  browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  fs.mkdirSync(ART, { recursive: true });
});

test.after(async () => {
  await browser?.close();
  server?.close();
});

const sleep = ms => new Promise(r => setTimeout(r, ms));
const pageText = page => page.evaluate(() => [...document.querySelectorAll('flt-semantics, input, textarea')].map(n => n.textContent + ' ' + (n.getAttribute('aria-label') || '')).join(' | '));

async function waitForText(page, needle, ms = 15000) {
  const end = Date.now() + ms;
  let last = '';
  while (Date.now() < end) {
    last = await pageText(page);
    if (last.includes(needle)) return last;
    await sleep(200);
  }
  throw new Error(`"${needle}" did not appear. Page text was: ${last.slice(0, 600)}`);
}

async function open(query = '?lang=en&theme=light') {
  const page = await browser.newPage();
  const requests = [], errors = [];
  page.on('request', r => requests.push({ method: r.method(), url: r.url(), body: r.postData() || '' }));
  page.on('pageerror', e => errors.push(e.message));
  await page.setViewport({ width: 430, height: 1500 });
  await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
  await page.goto(base + '/' + query, { waitUntil: 'networkidle0', timeout: 60000 });
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click()); // enable the accessibility tree
  await waitForText(page, 'golden rules');
  return { page, requests, errors };
}

async function click(page, { role, text, label }) {
  const rect = await page.evaluate(({ role, text, label }) => {
    const n = [...document.querySelectorAll('flt-semantics')].find(el =>
      (!role || el.getAttribute('role') === role) &&
      (label ? el.getAttribute('aria-label') === label : el.textContent.trim() === text));
    if (!n) return null;
    const r = n.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, { role, text, label });
  assert.ok(rect, `no ${role} with ${label || text}`);
  await page.mouse.click(rect.x, rect.y);
}

async function typeMessage(page, text) {
  await page.waitForSelector('textarea');
  await page.focus('textarea');
  await page.keyboard.type(text, { delay: 5 });
}

const shot = (page, name) => page.screenshot({ path: path.join(ART, name + '.png') });

test('loads in English with the examples and no browser errors', async () => {
  const { page, errors } = await open();
  const t = await pageText(page);
  for (const s of ['ScamSaathi', 'Your message is checked on this phone', 'Web demo: your message is checked inside this browser tab', 'Fake bank KYC', 'Fake PM-Kisan app', 'Normal message', '3 golden rules']) {
    assert.ok(t.includes(s), `missing "${s}"`);
  }
  assert.deepEqual(errors, []);
  await shot(page, 'home');
  await page.close();
});

test('tapping the fake-KYC example shows a dangerous verdict with reasons', async () => {
  const { page } = await open();
  await click(page, { role: 'checkbox', label: 'Fake bank KYC' });
  const t = await waitForText(page, 'DANGEROUS');
  for (const s of ['Warning level: High', "not that company's real website", 'Kind of scam', 'Call 1930']) {
    assert.ok(t.includes(s), `missing "${s}"`);
  }
  await shot(page, 'kyc-dangerous');
  await page.close();
});

test('a normal message gets "no warning signs", never "safe" and never a scam action', async () => {
  const { page } = await open();
  await typeMessage(page, 'Meeting rescheduled to 4 pm tomorrow. Please confirm.');
  await click(page, { role: 'button', text: 'Check' });
  const t = await waitForText(page, 'No warning signs found');
  assert.ok(t.includes('does not guarantee'));
  assert.ok(!t.includes('DANGEROUS') && !t.includes('Call 1930') && !t.includes('Tell my Saathi'));
  assert.ok(!/\bSAFE\b/.test(t), 'must never say SAFE');
  await shot(page, 'normal-message');
  await page.close();
});

test('a typed Hinglish scam is caught, and the language switch changes the verdict to Hindi', async () => {
  const { page } = await open();
  await typeMessage(page, 'PM Kisan ki nayi list aayi hai. Yeh file install karo: PM-Kisan-Yojana.apk');
  await click(page, { role: 'button', text: 'Check' });
  const t = await waitForText(page, 'DANGEROUS');
  assert.ok(t.includes('an .apk file'));
  await click(page, { role: 'button', text: 'हिन्दी' });
  await waitForText(page, 'ख़तरनाक');
  await shot(page, 'apk-hindi');
  await page.close();
});

test('settings opens and an offline build does not offer reporting', async () => {
  const { page } = await open();
  await click(page, { role: 'button', text: 'Settings' });
  const t = await waitForText(page, 'My Saathi');
  assert.ok(t.includes('Saathi phone number'));
  assert.ok(!t.includes('Allow anonymous reports'), 'reporting must not exist in an offline build');
  await page.close();
});

test('privacy: checking messages sends nothing out, and no request contains the message', async () => {
  const { page, requests } = await open();
  const mark = requests.length;
  const secret = 'SBI KYC update karo warna account block ho jayega http://sbi-kyc-update.xyz/verify';
  await typeMessage(page, secret);
  await click(page, { role: 'button', text: 'Check' });
  await waitForText(page, 'DANGEROUS');
  await click(page, { role: 'checkbox', label: 'UPI refund trick' });
  await waitForText(page, 'UPI');
  await sleep(1500);
  const after = requests.slice(mark);
  assert.deepEqual(after.filter(r => r.method !== 'GET'), [], 'no POST/PUT while checking');
  const all = requests.map(r => decodeURIComponent(r.url) + ' ' + r.body).join('\n');
  for (const frag of ['sbi-kyc-update', 'block ho jayega', 'UPI collect', 'refund pending']) {
    assert.ok(!all.includes(frag), `a request leaked "${frag}"`);
  }
  // nothing third-party at all: the rendering engine and fonts are bundled, so no CDN ever sees the visitor
  const hosts = new Set(requests.filter(r => /^https?:/.test(r.url)).map(r => new URL(r.url).hostname));
  assert.deepEqual([...hosts], [new URL(base).hostname], `the page contacted other hosts: ${[...hosts]}`);
  await page.close();
});

test('checking an app file in the browser: caught, explained in plain words, and the file never leaves the page', async () => {
  const { page, requests } = await open();
  const mark = requests.length;
  const fixture = path.join(__dirname, '..', 'packs', 'core', 'apk', 'fake_pmkisan.apk');
  const [chooser] = await Promise.all([page.waitForFileChooser({ timeout: 15000 }), click(page, { role: 'button', text: 'Check an APK file' })]);
  await chooser.accept([fixture]);
  const t = await waitForText(page, 'DANGEROUS');
  for (const needle of ['What this app asks for', 'Read your text messages', 'com.pmkisan.yojana.free', 'never leaves this device']) {
    assert.ok(t.includes(needle), `missing "${needle}"`);
  }
  await sleep(1000);
  const after = requests.slice(mark);
  assert.deepEqual(after.filter(r => r.method !== 'GET'), [], 'no upload of any kind');
  assert.ok(!requests.map(r => r.url + ' ' + r.body).join('\n').includes('pmkisan'), 'the file name or contents must not appear in any request');
  await shot(page, 'apk-dangerous');
  await page.close();
});

test('the harmless sample app file is not accused', async () => {
  const { page } = await open();
  await click(page, { role: 'checkbox', label: 'Harmless torch app file' });
  const t = await waitForText(page, 'No warning signs found');
  assert.ok(t.includes('Use the flashlight') && !t.includes('DANGEROUS'));
  await page.close();
});

test('Listen reads the result aloud and Stop stops it, without any network traffic or errors', async () => {
  const { page, requests, errors } = await open();
  await click(page, { role: 'checkbox', label: 'Fake bank KYC' });
  await waitForText(page, 'DANGEROUS');
  const mark = requests.length;
  await click(page, { role: 'button', text: 'Listen' });
  await waitForText(page, 'Stop');
  await click(page, { role: 'button', text: 'Stop' });
  await waitForText(page, 'Listen');
  await sleep(500);
  assert.deepEqual(requests.slice(mark), [], 'reading aloud must not make a request');
  assert.deepEqual(errors, []);
  await page.close();
});

test('first-run screens: three steps, switch to Hindi, then the home screen', async () => {
  const page = await browser.newPage();
  await page.setViewport({ width: 430, height: 900 });
  await page.goto(base + '/?onboarding=1&lang=en&theme=light', { waitUntil: 'networkidle0', timeout: 60000 });
  await page.waitForSelector('flt-semantics-placeholder', { timeout: 30000 });
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  await waitForText(page, 'Check before you trust');
  await click(page, { role: 'button', text: 'Next' });
  await waitForText(page, 'Your message stays on your phone');
  await shot(page, 'onboarding-2');
  await click(page, { role: 'button', text: 'Next' });
  await waitForText(page, 'Choose someone you trust');
  await click(page, { role: 'button', text: 'Get started' });
  await waitForText(page, 'golden rules');
  await page.close();
});
