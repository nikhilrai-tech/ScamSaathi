import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'engine/apk.dart';
import 'ui/strings.dart';
import 'engine/engine.dart';
import 'services/feed.dart';
import 'services/pack_store.dart';
import 'services/reporter.dart';
import 'services/saathi.dart';
import 'services/speaker.dart';
import 'services/settings.dart';

typedef Launch = Future<bool> Function(Uri uri);

/// An app file the person chose. The bytes are read only when needed; the file is never installed or run.
class PickedApk {
  final String name;
  final int? size;
  final Future<Uint8List> Function() read;
  const PickedApk(this.name, this.size, this.read);
}

typedef ApkPicker = Future<PickedApk?> Function();

const maxApkBytes = 150 * 1024 * 1024;

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
    this.pickApk,
    this.speaker,
  });

  final PackStore packStore;
  final AppSettings settings;
  final Feed feed;
  final http.Client client;
  final Launch launch;
  final Speaker? speaker; // null where reading aloud is not available
  bool speaking = false;
  final ApkPicker? pickApk; // null where picking files is not possible
  final Uri? apiBase; // null = fully offline build: no updates, no feed, no reports

  Analysis? result;
  String text = '';
  String? apkMessage; // string key explaining why a chosen file could not be read
  ReportOutcome reportOutcome = ReportOutcome.none;

  String get lang => settings.language;
  bool get canReport => apiBase != null && settings.reportingEnabled && result != null && result!.family != 'none' && result!.family != 'unknown';

  void setLanguage(String code) {
    settings.language = code;
    notifyListeners();
  }

  void check(String input) {
    if (speaking) {
      speaker?.stop();
      speaking = false;
    }
    text = input;
    apkMessage = null;
    reportOutcome = ReportOutcome.none;
    result = input.trim().isEmpty ? null : feed.apply(analyze(input, packStore.current));
    notifyListeners();
  }

  void clear() => check('');

  /// What is read aloud: the verdict, the advice and the reasons. Never the person's message, a link or a number.
  String spokenText() {
    final a = result;
    if (a == null) return '';
    final reasons = [for (final r in a.reasons) r.text[lang] ?? r.text['en'] ?? ''];
    return [tr('${a.verdict}Title', lang), tr('${a.verdict}Advice', lang), ...reasons].join('. ');
  }

  bool get canSpeak => speaker != null && result != null;

  Future<void> toggleSpeaking() async {
    final s = speaker;
    if (s == null || result == null) return;
    if (speaking) {
      speaking = false;
      notifyListeners();
      await s.stop();
      return;
    }
    speaking = true;
    notifyListeners();
    await s.speak(spokenText(), lang);
  }

  /// Check an app file. Only its manifest is read (permissions and names); nothing is installed, run or uploaded.
  Future<void> checkApk(PickedApk picked) async {
    text = picked.name;
    reportOutcome = ReportOutcome.none;
    apkMessage = null;
    result = null;
    if ((picked.size ?? 0) > maxApkBytes) {
      apkMessage = 'apkTooBig';
    } else {
      try {
        final info = parseApk(await picked.read());
        info.fileName = picked.name.toLowerCase().endsWith('.apk') ? picked.name.substring(0, picked.name.length - 4) : picked.name;
        result = feed.apply(analyze('', packStore.current, apk: info));
      } on ApkError {
        apkMessage = 'apkNotApp';
      }
    }
    notifyListeners();
  }

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
