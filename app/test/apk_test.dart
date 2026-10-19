import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamsaathi/engine/apk.dart';
import 'package:scamsaathi/engine/engine.dart';

final dir = Directory('../packs/core/apk');
final truth = jsonDecode(File('${dir.path}/expected.json').readAsStringSync()) as Map<String, dynamic>;
final pack = Pack.fromBytes(File('../packs/core/pack.json').readAsBytesSync());

ApkInfo info(String name) {
  final i = parseApk(File('${dir.path}/$name.apk').readAsBytesSync());
  i.fileName = name;
  return i;
}

void main() {
  for (final entry in truth.entries) {
    test('the Dart reader recovers exactly what ${entry.key} was built with (same truth as Python)', () {
      final t = entry.value as Map<String, dynamic>;
      final got = parseApk(File('${dir.path}/${entry.key}').readAsBytesSync());
      expect(got.package, t['package']);
      expect(got.label, t['label']);
      expect(got.permissions, (t['permissions'] as List).cast<String>());
      expect(got.componentPermissions, (t['component_permissions'] as List).cast<String>());
      expect(got.actions, (t['actions'] as List).cast<String>());
      expect((got.minSdk, got.targetSdk), (t['min_sdk'], t['target_sdk']));
      expect(got.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  }

  test('a file that is not an app is an ApkError, never another exception', () {
    for (final name in ['empty_zip.apk', 'not_an_apk.apk']) {
      expect(() => parseApk(File('${dir.path}/$name').readAsBytesSync()), throwsA(isA<ApkError>()), reason: name);
    }
    expect(() => parseApk(Uint8List(0)), throwsA(isA<ApkError>()));
  });

  test('every truncation and random damage of a real manifest is handled without crashing', () {
    final apk = File('${dir.path}/banking_trojan.apk').readAsBytesSync();
    final manifest = parseApk(apk); // sanity
    expect(manifest.permissions, isNotEmpty);
    // find the raw manifest by re-reading through the same public path: damage the whole file instead
    for (var n = 0; n < apk.length; n += 7) {
      try {
        parseApk(Uint8List.sublistView(apk, 0, n));
      } on ApkError {
        // the only acceptable failure
      }
    }
    final rng = Random(7);
    for (var k = 0; k < 400; k++) {
      final damaged = Uint8List.fromList(apk);
      for (var j = 0; j < 4; j++) {
        damaged[rng.nextInt(damaged.length)] = rng.nextInt(256);
      }
      try {
        parseApk(damaged);
      } on ApkError {
        // fine
      }
    }
  });

  test('benign apps are safe; fake-looking apps are caught and explained in both languages', () {
    for (final n in ['benign_minimal', 'torch_ok']) {
      expect(analyze('', pack, apk: info(n)).verdict, 'safe', reason: n);
    }
    final r = analyze('', pack, apk: info('fake_pmkisan'));
    expect(r.verdict, 'dangerous');
    expect(r.reasons.map((x) => x.id), contains('apk.reads_sms'));
    expect(r.reasons.every((x) => (x.text['en'] ?? '').isNotEmpty && (x.text['hi'] ?? '').isNotEmpty), isTrue);
    expect(analyze('', pack, apk: info('banking_trojan')).verdict, 'dangerous');
    expect(analyze('', pack, apk: info('call_forwarder')).verdict, 'suspicious');
  });

  test('the file hash is an indicator and the app summary is returned', () {
    final r = analyze('', pack, apk: info('fake_pmkisan'));
    expect(r.indicators['apk_sha256']!.length, 1);
    expect(r.apk!.package, 'com.pmkisan.yojana.free');
    expect(analyze('hello', pack).indicators['apk_sha256'], isEmpty);
  });
}
