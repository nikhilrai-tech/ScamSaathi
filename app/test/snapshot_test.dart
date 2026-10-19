// The Python engine recorded its answer for every message we have (packs/core/snapshot.json). The Dart engine must give exactly
// the same verdict, score, family and signals for all of them, including the wording model.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamsaathi/engine/engine.dart';

void main() {
  final pack = Pack.fromBytes(File('../packs/core/pack.json').readAsBytesSync());
  final rows = (jsonDecode(File('../packs/core/snapshot.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

  test('the snapshot is large enough to mean something', () => expect(rows.length, greaterThan(400)));

  test('Dart matches Python on every message in the snapshot', () {
    final bad = <String>[];
    for (final r in rows) {
      final a = analyze(r['text'] as String, pack);
      final got = '${a.verdict}|${a.score}|${a.family}|${a.reasons.map((x) => x.id).join(',')}';
      final want = '${r['verdict']}|${r['score']}|${r['family']}|${(r['signals'] as List).join(',')}';
      if (got != want) bad.add('${r['id']}: want $want, got $got');
    }
    expect(bad, isEmpty, reason: '${bad.length} differ, first: ${bad.take(3).join(' || ')}');
  });
}
