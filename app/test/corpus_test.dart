// The golden corpus is the contract between the Python and Dart engines.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamsaathi/engine/engine.dart';

void main() {
  final packBytes = File('../packs/core/pack.json').readAsBytesSync();
  final pack = Pack.fromBytes(packBytes);
  final cases = File('../packs/core/corpus.jsonl')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();

  test('the corpus is loaded', () => expect(cases.length, greaterThanOrEqualTo(36)));

  for (final c in cases) {
    test('corpus: ${c['id']}', () {
      final r = analyze(c['text'] as String, pack);
      expect(r.verdict, c['verdict']);
      expect(r.family, c['family']);
      expect(r.reasons.map((x) => x.id).toList()..sort(), (List<String>.from(c['signals'] as List))..sort());
    });
  }

  test('the bundled pack is byte-identical to packs/core/pack.json', () {
    expect(File('assets/pack.json').readAsBytesSync(), packBytes);
  });

  test('the bundled public key is the one in packs/keys', () {
    expect(File('assets/release.pub').readAsStringSync(), File('../packs/keys/release.pub').readAsStringSync());
  });
}
