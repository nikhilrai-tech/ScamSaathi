import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'saathi.dart';

/// Everything here stays on the phone.
class AppSettings {
  final SharedPreferences _p;
  AppSettings(this._p);

  String get language => _p.getString('lang') ?? 'hi';
  set language(String v) => _p.setString('lang', v);

  /// Off by default. Turning it on lets the app send hashed indicators (never messages) after the user taps "report".
  bool get reportingEnabled => _p.getBool('report_opt_in') ?? false;
  set reportingEnabled(bool v) => _p.setBool('report_opt_in', v);

  String get district => _p.getString('district') ?? '';
  set district(String v) => _p.setString('district', v.trim());

  String get ownName => _p.getString('own_name') ?? '';
  set ownName(String v) => _p.setString('own_name', v.trim());

  /// Cached community feed (hashes only), so matching works offline after the first sync.
  String? get feedCache => _p.getString('feed_cache');
  set feedCache(String? v) => v == null ? _p.remove('feed_cache') : _p.setString('feed_cache', v);

  Saathi? get saathi {
    final raw = _p.getString('saathi');
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return Saathi(m['name'] as String, m['phone'] as String);
  }

  void setSaathi(Saathi? s) {
    if (s == null) {
      _p.remove('saathi');
    } else {
      _p.setString('saathi', jsonEncode({'name': s.name, 'phone': s.phone}));
    }
  }

  /// Random id made once, used only to count a person once in reports. It is hashed before it leaves the phone.
  String get installId {
    var id = _p.getString('install_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _p.setString('install_id', id);
    }
    return id;
  }
}
