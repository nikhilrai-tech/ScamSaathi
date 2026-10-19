import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'engine/engine.dart';
import 'services/feed.dart';
import 'services/pack_store.dart';
import 'services/reporter.dart';
import 'services/saathi.dart';
import 'services/settings.dart';

typedef Launch = Future<bool> Function(Uri uri);

enum ReportOutcome { none, sent, failed }

/// What the person says is true about a message the app got wrong.
enum FeedbackLabel { scam, normal }

/// Everything the screens need. Holds no message text beyond the one being checked, and never writes it to disk.
class AppController extends ChangeNotifier {
  AppController({
    required this.packStore,
    required this.settings,
    required this.feed,
    required this.client,
    required this.launch,
    this.apiBase,
  });

  final PackStore packStore;
  final AppSettings settings;
  final Feed feed;
  final http.Client client;
  final Launch launch;
  final Uri? apiBase; // null = fully offline build: no updates, no feed, no reports

  Analysis? result;
  String text = '';
  ReportOutcome reportOutcome = ReportOutcome.none;

  String get lang => settings.language;
  bool get canReport => apiBase != null && settings.reportingEnabled && result != null && result!.family != 'none' && result!.family != 'unknown';

  void setLanguage(String code) {
    settings.language = code;
    notifyListeners();
  }

  void check(String input) {
    text = input;
    reportOutcome = ReportOutcome.none;
    result = input.trim().isEmpty ? null : feed.apply(analyze(input, packStore.current));
    notifyListeners();
  }

  void clear() => check('');

  void saveSaathi(Saathi? saathi, {String? ownName}) {
    settings.setSaathi(saathi);
    if (ownName != null) settings.ownName = ownName;
    notifyListeners();
  }

  void setReportingEnabled(bool on) {
    settings.reportingEnabled = on;
    notifyListeners();
  }

  Future<bool> tellSaathi({bool whatsapp = false}) async {
    final s = settings.saathi, a = result;
    if (s == null || a == null) return false;
    final msg = buildSaathiMessage(a, lang, fromName: settings.ownName);
    return launch(whatsapp ? saathiWhatsAppUri(s, msg) : saathiSmsUri(s, msg));
  }

  /// "This result is wrong" is offered only when the build has a server. Nothing is sent until the person taps Send in the sheet.
  bool get canGiveFeedback => apiBase != null && result != null;

  /// Sends one message the person chose to send. [text] is already masked on the phone, and the server masks it again.
  Future<bool> sendFeedback({required FeedbackLabel label, required String text}) async {
    final a = result, base = apiBase;
    if (a == null || base == null) return false;
    try {
      final res = await client.post(
        base.resolve('/v1/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'label': label == FeedbackLabel.scam ? 'scam' : 'normal',
          'app_verdict': a.verdict,
          'family': familyLabels.containsKey(a.family) ? a.family : '',
          'lang': lang,
        }),
      );
      return res.statusCode == 201;
    } on Exception {
      return false;
    }
  }

  Future<bool> callHelpline() => launch(Uri(scheme: 'tel', path: '1930'));

  Future<void> report() async {
    final a = result, base = apiBase;
    if (!canReport || a == null || base == null) return;
    try {
      final n = await Reporter(client, base, settings.installId).report(a, district: settings.district);
      reportOutcome = n > 0 ? ReportOutcome.sent : ReportOutcome.failed;
    } on Exception {
      reportOutcome = ReportOutcome.failed;
    }
    notifyListeners();
  }

  /// Quietly refresh rules and the scam feed when online. Failure changes nothing.
  Future<void> refresh() async {
    final base = apiBase;
    if (base == null) return;
    await packStore.update(client, base);
    try {
      await feed.sync(client, base);
      settings.feedCache = feed.toJsonString();
    } on Exception {
      // offline: keep what we have
    }
    notifyListeners();
  }
}
