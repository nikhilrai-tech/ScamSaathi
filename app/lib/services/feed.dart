import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:http/http.dart' as http;

import '../engine/engine.dart';

String sha256Hex(String value) => hash.sha256.convert(utf8.encode(value)).toString();

/// Community-confirmed scam indicators, kept on the phone as hashes. Matching is done locally, so what a user
/// receives is never sent anywhere to be checked.
class Feed {
  final Map<String, String> families = {}; // "kind:hash" -> scam family
  String? since;

  static String key(String kind, String h) => '$kind:$h';

  Future<void> sync(http.Client client, Uri base) async {
    for (var page = 0; page < 20; page++) {
      final uri = base.resolve('/v1/feed').replace(queryParameters: {'since': ?since});
      final res = await client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      for (final i in (body['indicators'] as List).cast<Map<String, dynamic>>()) {
        families[key(i['kind'] as String, i['hash'] as String)] = i['family'] as String;
      }
      final next = body['next_since'] as String?;
      if (next == null) return;
      since = next;
    }
  }

  Map<String, dynamic> toJson() => {'since': since, 'families': families};

  String toJsonString() => jsonEncode(toJson());

  void loadJson(Map<String, dynamic> json) {
    since = json['since'] as String?;
    families
      ..clear()
      ..addAll((json['families'] as Map<String, dynamic>).cast<String, String>());
  }

  /// If something in the message was confirmed as a scam by other people, say so. Three independent reporters, or a
  /// verified organisation, is stronger evidence than any wording rule, so this alone makes the verdict dangerous.
  Analysis apply(Analysis a) {
    String? family;
    for (final d in a.indicators['domains'] ?? const <String>[]) {
      family ??= families[key('domain', sha256Hex(d))];
    }
    for (final u in a.indicators['upi_ids'] ?? const <String>[]) {
      family ??= families[key('upi', sha256Hex(u))];
    }
    for (final h in a.indicators['apk_sha256'] ?? const <String>[]) {
      family ??= families[key('apk_sha256', h)]; // an app file is identified by its own SHA-256, which is already a hash
    }
    if (family == null) return a;
    const reason = Reason('feed.confirmed', 60, {
      'en': 'Other people and trusted organisations have already reported this link, UPI ID or app file as a scam.',
      'hi': 'दूसरे लोगों और भरोसेमंद संस्थाओं ने इस लिंक, UPI आईडी या ऐप फ़ाइल को पहले ही ठगी बताया है।',
    });
    return Analysis('dangerous', 100, family, [reason, ...a.reasons], a.indicators, apk: a.apk);
  }
}
