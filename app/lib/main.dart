import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'platform/share_intake.dart';
import 'services/feed.dart';
import 'services/pack_store.dart';
import 'services/settings.dart';
import 'services/speaker.dart';
import 'ui/onboarding_page.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart' show samples;

/// Set at build time, for example `--dart-define=SCAMSAATHI_API=https://api.example.org`.
/// Left empty the app is fully offline: no pack updates, no scam feed, no reports.
const _apiBase = String.fromEnvironment('SCAMSAATHI_API');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final bundled = (await rootBundle.load('assets/pack.json')).buffer.asUint8List();
  final pub = await rootBundle.loadString('assets/release.pub');
  final store = await PackStore.load(
    verifier: PackVerifier(pub),
    storage: kIsWeb ? MemoryPackStorage() : FilePackStorage(),
    bundled: bundled,
  );
  final feed = Feed();
  final cached = settings.feedCache;
  if (cached != null) {
    try {
      feed.loadJson(jsonDecode(cached) as Map<String, dynamic>);
    } on Object {
      settings.feedCache = null; // corrupt cache: start fresh
    }
  }
  final controller = AppController(
    packStore: store,
    settings: settings,
    feed: feed,
    client: http.Client(),
    launch: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    apiBase: _apiBase.isEmpty ? null : Uri.parse(_apiBase),
    pickApk: _pickApkFile,
    speaker: FlutterTtsSpeaker(),
  );

  if (kIsWeb) {
    final q = Uri.base.queryParameters;
    if (q['lang'] == 'en' || q['lang'] == 'hi') settings.language = q['lang']!;
    final i = int.tryParse(q['sample'] ?? '');
    if (i != null && i >= 0 && i < samples.length) controller.check(samples[i].$2);
  }

  final intake = ShareIntake();
  intake.listen(controller.check);
  var mode = ThemeMode.system;
  if (kIsWeb) {
    final t = Uri.base.queryParameters['theme'];
    if (t == 'light') mode = ThemeMode.light;
    if (t == 'dark') mode = ThemeMode.dark;
  }
  runApp(ScamSaathiApp(controller, themeMode: mode));
  final shared = await intake.initial();
  if (shared != null) controller.check(shared);
  controller.refresh();
}

/// Let the person choose an app file. Only .apk files are offered; its bytes are read on the device and never uploaded.
Future<PickedApk?> _pickApkFile() async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['apk']);
  if (f == null) return null;
  return PickedApk(f.name, await f.length(), f.readAsBytes);
}

class ScamSaathiApp extends StatelessWidget {
  const ScamSaathiApp(this.controller, {super.key, this.themeMode = ThemeMode.system});
  final AppController controller;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamSaathi',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      home: _Root(controller: controller),
    );
  }
}

/// First run on a phone: three short screens, then the home screen. The web demo goes straight to the home screen.
class _Root extends StatefulWidget {
  const _Root({required this.controller});
  final AppController controller;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  // the web demo skips the first-run screens unless asked (?onboarding=1), so visitors go straight to trying it
  late bool _onboarding = kIsWeb ? Uri.base.queryParameters['onboarding'] == '1' : !widget.controller.settings.onboarded;

  @override
  Widget build(BuildContext context) {
    if (_onboarding) {
      return OnboardingPage(controller: widget.controller, onDone: () => setState(() => _onboarding = false));
    }
    return HomePage(controller: widget.controller);
  }
}
