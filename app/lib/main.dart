import 'dart:convert';

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
import 'ui/home_page.dart';

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
  );

  final intake = ShareIntake();
  intake.listen(controller.check);
  runApp(ScamSaathiApp(controller));
  final shared = await intake.initial();
  if (shared != null) controller.check(shared);
  controller.refresh();
}

class ScamSaathiApp extends StatelessWidget {
  const ScamSaathiApp(this.controller, {super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScamSaathi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FA5)), useMaterial3: true),
      home: HomePage(controller: controller),
    );
  }
}
