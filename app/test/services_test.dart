import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as hash;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamsaathi/engine/engine.dart';
import 'package:scamsaathi/services/feed.dart';
import 'package:scamsaathi/services/pack_store.dart';
import 'package:scamsaathi/services/reporter.dart';
import 'package:scamsaathi/services/saathi.dart';
import 'package:scamsaathi/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

final fixturePack = File('test/fixtures/pack.json').readAsBytesSync();
final fixtureSig = jsonDecode(File('test/fixtures/pack.sig.json').readAsStringSync()) as Map<String, dynamic>;
final fixturePub = File('test/fixtures/test.pub').readAsStringSync();

/// A fresh key pair, to sign "server" packs inside tests.
Future<(SimpleKeyPair, String)> newKey() async {
  final kp = await Ed25519().newKeyPair();
  final pub = await kp.extractPublicKey();
  return (kp, base64.encode(pub.bytes));
}

Future<Map<String, dynamic>> signWith(SimpleKeyPair kp, String pubB64, List<int> bytes) async {
  final sig = await Ed25519().sign(bytes, keyPair: kp);
  return {
    'alg': 'ed25519',
    'key_id': hash.sha256.convert(base64.decode(pubB64)).toString().substring(0, 16),
    'version': Pack.fromBytes(bytes).version,
    'sha256': hash.sha256.convert(bytes).toString(),
    'signature': base64.encode(sig.bytes),
  };
}

List<int> bump(List<int> bytes, int to) => utf8.encode(utf8.decode(bytes).replaceFirst('"version": 1', '"version": $to'));

MockClient server(SimpleKeyPair kp, String pubB64, List<int> packBytes, {Map<String, dynamic>? sigOverride, int? versionClaim}) {
  return MockClient((req) async {
    final sig = sigOverride ?? await signWith(kp, pubB64, packBytes);
    if (req.url.path == '/v1/packs/core/manifest') {
      return http.Response(jsonEncode({...sig, 'version': versionClaim ?? sig['version'], 'url': '/v1/packs/core/pack.json'}), 200);
    }
    if (req.url.path == '/v1/packs/core/pack.json') return http.Response.bytes(packBytes, 200);
    return http.Response('', 404);
  });
}

final base = Uri.parse('https://api.example.test');

void main() {
  group('signature (Python-made fixture verified by Dart)', () {
    test('a signature made by tools/packsign.py verifies in Dart', () async {
      expect(await PackVerifier(fixturePub).verify(fixturePack, fixtureSig), isTrue);
    });

    test('any change to the pack, the key or the signature fields is rejected', () async {
      final v = PackVerifier(fixturePub);
      expect(await v.verify([...fixturePack, 32], fixtureSig), isFalse);
      expect(await v.verify(fixturePack, {...fixtureSig, 'alg': 'rsa'}), isFalse);
      expect(await v.verify(fixturePack, {...fixtureSig, 'version': 9}), isFalse);
      expect(await v.verify(fixturePack, {...fixtureSig, 'signature': base64.encode(List.filled(64, 0))}), isFalse);
      expect(await v.verify(fixturePack, {...fixtureSig, 'signature': 'not base64!'}), isFalse);
      final (_, otherPub) = await newKey();
      expect(await PackVerifier(otherPub).verify(fixturePack, fixtureSig), isFalse);
    });
  });

  group('PackStore', () {
    test('the bundled pack is used when nothing was downloaded', () async {
      final s = await PackStore.load(verifier: PackVerifier(fixturePub), storage: MemoryPackStorage(), bundled: fixturePack);
      expect(s.current.version, 1);
    });

    test('a newer, correctly signed pack is installed and survives a restart', () async {
      final (kp, pub) = await newKey();
      final storage = MemoryPackStorage();
      final store = await PackStore.load(verifier: PackVerifier(pub), storage: storage, bundled: fixturePack);
      final v2 = bump(fixturePack, 2);
      expect(await store.update(server(kp, pub, v2), base), UpdateResult.updated);
      expect(store.current.version, 2);
      final again = await PackStore.load(verifier: PackVerifier(pub), storage: storage, bundled: fixturePack);
      expect(again.current.version, 2);
    });

    test('a pack signed by another key is rejected and nothing is stored', () async {
      final (_, pub) = await newKey();
      final (attackerKey, attackerPub) = await newKey();
      final storage = MemoryPackStorage();
      final store = await PackStore.load(verifier: PackVerifier(pub), storage: storage, bundled: fixturePack);
      expect(await store.update(server(attackerKey, attackerPub, bump(fixturePack, 2)), base), UpdateResult.rejected);
      expect(storage.value, isNull);
      expect(store.current.version, 1);
    });

    test('a downgrade or the same version is never installed', () async {
      final (kp, pub) = await newKey();
      final store = await PackStore.load(verifier: PackVerifier(pub), storage: MemoryPackStorage(), bundled: bump(fixturePack, 5));
      expect(await store.update(server(kp, pub, fixturePack), base), UpdateResult.upToDate);
      expect(store.current.version, 5);
    });

    test('a manifest that lies about the version is rejected', () async {
      final (kp, pub) = await newKey();
      final store = await PackStore.load(verifier: PackVerifier(pub), storage: MemoryPackStorage(), bundled: fixturePack);
      // the served pack is really version 1 (signed as 1) but the manifest claims 9 to look newer
      expect(await store.update(server(kp, pub, fixturePack, versionClaim: 9), base), UpdateResult.rejected);
    });

    test('a tampered stored pack is ignored on load', () async {
      final (kp, pub) = await newKey();
      final v2 = bump(fixturePack, 2);
      final storage = MemoryPackStorage()..value = ([...v2, 32], await signWith(kp, pub, v2));
      final s = await PackStore.load(verifier: PackVerifier(pub), storage: storage, bundled: fixturePack);
      expect(s.current.version, 1);
    });

    test('network failure leaves the current pack working', () async {
      final store = await PackStore.load(verifier: PackVerifier(fixturePub), storage: MemoryPackStorage(), bundled: fixturePack);
      final r = await store.update(MockClient((_) async => throw http.ClientException('no network')), base);
      expect(r, UpdateResult.offline);
      expect(store.current.version, 1);
    });
  });

  group('hashing matches the server', () {
    test('sha256Hex gives the same hashes as Python', () {
      expect(sha256Hex('sbi.co.in'), 'e3979cfd7701dbb4acc6715e7272c7e8aea776b9b2323797cbf042d0a594d65b');
      expect(sha256Hex('evil-kyc.xyz'), '1ca60940c14d3c6d62ae45cf8465217be0885560578ffd9fc4f9db9c28d1f8dd');
      expect(sha256Hex('demo.user@ybl'), '6a24700e4593ecff78559b7ff85581f5812297405d9ef26247a046391dc9db34');
    });
  });

  group('Feed', () {
    final pack = Pack.fromBytes(fixturePack);

    test('a link confirmed by others turns an otherwise quiet message dangerous, locally', () {
      final a = analyze('look at evil-kyc.xyz', pack);
      expect(a.verdict, isNot('dangerous'));
      final feed = Feed()..families['domain:${sha256Hex('evil-kyc.xyz')}'] = 'kyc_bank';
      final b = feed.apply(a);
      expect((b.verdict, b.family, b.reasons.first.id), ('dangerous', 'kyc_bank', 'feed.confirmed'));
    });

    test('an unknown link leaves the verdict alone', () {
      final a = analyze('look at example.com/page', pack);
      expect(Feed().apply(a).verdict, a.verdict);
    });

    test('sync pages through the feed and remembers where it stopped', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (req.url.queryParameters['since'] == null) {
          return http.Response(jsonEncode({'indicators': [{'kind': 'domain', 'hash': 'a' * 64, 'family': 'fake_apk'}], 'next_since': '2026-01-01T00:00:00+00:00'}), 200);
        }
        return http.Response(jsonEncode({'indicators': [{'kind': 'upi', 'hash': 'b' * 64, 'family': 'upi_collect'}], 'next_since': null}), 200);
      });
      final feed = Feed();
      await feed.sync(client, base);
      expect((calls, feed.families.length), (2, 2));
      final copy = Feed()..loadJson(jsonDecode(jsonEncode(feed.toJson())) as Map<String, dynamic>);
      expect(copy.families, feed.families);
    });
  });

  group('Reporter', () {
    final pack = Pack.fromBytes(fixturePack);
    const text = 'Your SBI account will be blocked. Update KYC at http://sbi-secure.top/v and pay demo.user@ybl';

    test('sends hashes only: never the message, a raw domain or a raw UPI ID', () async {
      final bodies = <String>[];
      final client = MockClient((req) async {
        bodies.add(req.body);
        return http.Response('{}', 201);
      });
      final sent = await Reporter(client, base, 'install-123').report(analyze(text, pack), district: 'Nashik');
      expect(sent, 2);
      final all = bodies.join(' ');
      for (final secret in ['sbi-secure', 'secure.top', 'demo.user', 'blocked', 'install-123', 'http']) {
        expect(all.contains(secret), isFalse, reason: 'leaked "$secret"');
      }
      final first = jsonDecode(bodies.first) as Map<String, dynamic>;
      expect(first.keys.toSet(), {'kind', 'value_hash', 'family', 'reporter_hash', 'district'});
      expect(first['value_hash'], matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('a safe message sends nothing', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 201);
      });
      expect(await Reporter(client, base, 'x').report(analyze('Meeting at 4 pm tomorrow', pack)), 0);
      expect(calls, 0);
    });
  });

  group('scam family labels', () {
    test('every family in the pack has a label in every language, so the "kind of scam" chip and the Saathi note work', () {
      final pack = Pack.fromBytes(File('../packs/core/pack.json').readAsBytesSync()); // the real pack, not the signed test fixture
      final families = (pack.raw['families'] as List).cast<String>();
      expect(families.length, greaterThanOrEqualTo(15));
      for (final f in families) {
        for (final lang in ['en', 'hi']) {
          expect(familyLabels[f]?[lang], isNotNull, reason: 'no $lang label for family $f');
        }
      }
    });
  });

  group('Saathi message', () {
    final pack = Pack.fromBytes(fixturePack);
    final a = analyze('Update KYC at http://sbi-secure.top/v now, share OTP', pack);

    test('names the kind of scam but never the message, link, number or UPI ID', () {
      for (final lang in ['en', 'hi']) {
        final m = buildSaathiMessage(a, lang, fromName: 'Ramesh');
        expect(m, contains('Ramesh'));
        for (final bad in ['http', 'sbi-secure', 'secure.top', '@', 'www', 'update kyc']) {
          expect(m.toLowerCase().contains(bad), isFalse, reason: '$lang message contains "$bad"');
        }
      }
      expect(buildSaathiMessage(a, 'en'), contains('DANGEROUS'));
    });

    test('builds sms and WhatsApp links for the user to send themselves', () {
      const s = Saathi('Son', '+91 00000 00000');
      expect(saathiSmsUri(s, 'hi there').scheme, 'sms');
      expect(saathiWhatsAppUri(s, 'hi there').host, 'wa.me');
      expect(saathiWhatsAppUri(s, 'hi there').path, '/910000000000');
    });
  });

  group('AppSettings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('private by default: Hindi, reporting off, no Saathi', () async {
      final s = AppSettings(await SharedPreferences.getInstance());
      expect((s.language, s.reportingEnabled, s.saathi), ('hi', false, null));
    });

    test('install id is random, stable and 32 hex characters', () async {
      final s = AppSettings(await SharedPreferences.getInstance());
      expect(s.installId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(s.installId, s.installId);
    });

    test('Saathi can be saved and removed', () async {
      final s = AppSettings(await SharedPreferences.getInstance());
      s.setSaathi(const Saathi('Son', '+910000000000'));
      expect(s.saathi?.name, 'Son');
      s.setSaathi(null);
      expect(s.saathi, isNull);
    });
  });
}
