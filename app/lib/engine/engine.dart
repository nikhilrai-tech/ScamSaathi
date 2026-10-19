import 'dart:convert';

import 'apk.dart';
import 'extract.dart';
import 'model.dart';
import 'normalize.dart';

class Reason {
  final String id;
  final int weight;
  final Map<String, String> text; // language code -> plain-language explanation
  const Reason(this.id, this.weight, this.text);
}

class Analysis {
  final String verdict; // safe | suspicious | dangerous
  final int score;
  final String family;
  final List<Reason> reasons;
  final Map<String, List<String>> indicators;
  final ApkInfo? apk; // what the app file asks for, when one was checked
  const Analysis(this.verdict, this.score, this.family, this.reasons, this.indicators, {this.apk});
}

class Pack {
  final Map<String, dynamic> raw;
  Pack._(this.raw);

  /// Parse pack bytes. Callers must have verified the signature first (see PackStore).
  factory Pack.fromBytes(List<int> bytes) {
    final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (raw['schema_version'] != 1) throw FormatException('unsupported pack schema_version');
    return Pack._(raw);
  }

  int get version => raw['version'] as int;
  Map<String, dynamic> get lists => raw['lists'] as Map<String, dynamic>;
  Map<String, dynamic> get thresholds => raw['thresholds'] as Map<String, dynamic>;
  List<Map<String, dynamic>> get signals => (raw['signals'] as List).cast<Map<String, dynamic>>();
}

/// Verdict for one message. Port of engine/scamsaathi/engine.py: deterministic, nothing fetched or opened.
/// A single signal can never make a message `dangerous`.
/// Does what an app asks for match this signal? Only the manifest is known, never what the code does.
bool apkHit(Map<String, dynamic> sig, ApkInfo apk, Map<String, dynamic> lists) {
  final perms = {...apk.permissions, ...apk.componentPermissions};
  List<String> strs(Object? v) => ((v as List?) ?? const []).cast<String>();
  if (strs(sig['any_permissions']).any(perms.contains)) return true;
  if (strs(sig['any_actions']).any(apk.actions.contains)) return true;
  if (sig['min_sensitive'] is int) {
    final sensitive = strs(lists['sensitive_permissions']).toSet();
    if (perms.where(sensitive.contains).length >= (sig['min_sensitive'] as int)) return true;
  }
  if (sig['brand_names'] == true) {
    final names = '${apk.package} ${apk.label} ${apk.fileName}'.toLowerCase();
    return strs(lists['apk_brand_words']).any(names.contains);
  }
  return false;
}

Analysis analyze(String text, Pack pack, {ApkInfo? apk}) {
  final norm = normalize(text);
  final found = extract(norm, pack.lists);
  final fired = <Map<String, dynamic>>[];
  for (final sig in pack.signals) {
    bool hit;
    if (sig['type'] == 'feature') {
      hit = found.features.contains(sig['feature']);
    } else if (sig['type'] == 'apk') {
      hit = apk != null && apkHit(sig, apk, pack.lists);
    } else {
      final mode = sig['match'] as String;
      hit = (sig['phrases'] as List).cast<String>().any((p) => containsPhrase(norm, p, mode)) &&
          !((sig['unless'] as List?)?.cast<String>() ?? const <String>[]).any((u) => containsPhrase(norm, u, 'substring'));
    }
    if (hit) fired.add(sig);
  }
  final model = pack.raw['model'] as Map<String, dynamic>?;
  if (model != null && modelFires(norm, model, pack.lists)) {
    fired.add({'id': modelId, 'weight': model['weight'], 'family': 'generic', 'reason': model['reason']});
  }

  final th = pack.thresholds;
  final total = fired.fold<int>(0, (a, s) => a + (s['weight'] as int));
  final score = total > 100 ? 100 : total;
  String verdict;
  final ruleSignals = fired.where((s) => s['id'] != modelId).length; // the model alone can never make a message dangerous
  if (score >= (th['dangerous'] as int) && ruleSignals >= (th['min_signals_dangerous'] as int)) {
    verdict = 'dangerous';
  } else if (score >= (th['suspicious'] as int)) {
    verdict = 'suspicious';
  } else {
    verdict = 'safe';
  }

  final byFamily = <String, int>{};
  for (final s in fired) {
    final f = s['family'] as String;
    if (f != 'generic') byFamily[f] = (byFamily[f] ?? 0) + (s['weight'] as int);
  }
  String family;
  if (verdict == 'safe') {
    family = 'none';
  } else if (byFamily.isNotEmpty) {
    // a "weak" family (such as advance_fee, a pay-first modifier) names the scam only when nothing more specific fired
    final weak = ((pack.raw['weak_families'] as List?) ?? const []).cast<String>().toSet();
    final strong = Map.fromEntries(byFamily.entries.where((e) => !weak.contains(e.key)));
    final entries = (strong.isEmpty ? byFamily : strong).entries.toList()
      ..sort((a, b) => a.value != b.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    family = entries.first.key;
  } else {
    family = 'unknown';
  }

  fired.sort((a, b) {
    final wa = a['weight'] as int, wb = b['weight'] as int;
    return wa != wb ? wb.compareTo(wa) : (a['id'] as String).compareTo(b['id'] as String);
  });
  return Analysis(
    verdict,
    score,
    family,
    [
      for (final s in fired)
        Reason(s['id'] as String, s['weight'] as int, (s['reason'] as Map<String, dynamic>).cast<String, String>()),
    ],
    {
      'domains': found.domains.toList()..sort(),
      'apk_files': found.apkFiles.toList()..sort(),
      'upi_ids': found.upiIds.toList()..sort(),
      'apk_sha256': apk != null && apk.sha256.isNotEmpty ? [apk.sha256] : <String>[],
    },
    apk: apk,
  );
}
