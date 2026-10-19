import 'dart:convert';

import 'package:http/http.dart' as http;

import '../engine/engine.dart';
import 'feed.dart';

/// Anonymous, opt-in reporting. Sends hashes of the domains and UPI IDs found in a message, the scam family, a
/// district the user chose, and a hash of a random install id. Never the message, never a phone number.
class Reporter {
  final http.Client client;
  final Uri base;
  final String installId; // random, generated once on the phone

  Reporter(this.client, this.base, this.installId);

  Future<int> report(Analysis a, {String district = ''}) async {
    if (a.verdict == 'safe' || a.family == 'none' || a.family == 'unknown') return 0;
    final reporterHash = sha256Hex(installId);
    var sent = 0;
    final items = <(String, String)>[
      for (final d in a.indicators['domains'] ?? const <String>[]) ('domain', sha256Hex(d)),
      for (final u in a.indicators['upi_ids'] ?? const <String>[]) ('upi', sha256Hex(u)),
    ];
    for (final (kind, h) in items) {
      final res = await client.post(
        base.resolve('/v1/reports'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kind': kind, 'value_hash': h, 'family': a.family, 'reporter_hash': reporterHash, 'district': district,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) sent++;
    }
    return sent;
  }
}
