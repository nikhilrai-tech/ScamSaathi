import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamsaathi/app_controller.dart';
import 'package:scamsaathi/services/feed.dart';
import 'package:scamsaathi/services/pack_store.dart';
import 'package:scamsaathi/services/settings.dart';
import 'package:scamsaathi/ui/home_page.dart';
import 'package:scamsaathi/ui/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List fixture(String name) => File('../packs/core/apk/$name').readAsBytesSync();

Future<(AppController, List<Map<String, dynamic>>)> setup({
  String? picks,
  Uint8List? bytes,
  int? size,
  bool picker = true,
  Feed? feed,
  Uri? api,
  bool reporting = false,
}) async {
  SharedPreferences.setMockInitialValues({if (reporting) 'report_opt_in': true});
  final settings = AppSettings(await SharedPreferences.getInstance());
  final store = await PackStore.load(
    verifier: PackVerifier(File('test/fixtures/test.pub').readAsStringSync()),
    storage: MemoryPackStorage(),
    bundled: File('../packs/core/pack.json').readAsBytesSync(), // the real pack: it has the app-file rules
  );
  final posted = <Map<String, dynamic>>[];
  final client = MockClient((req) async {
    posted.add({'path': req.url.path, ...jsonDecode(req.body) as Map<String, dynamic>});
    return http.Response('{}', 201);
  });
  final data = bytes ?? (picks != null ? fixture(picks) : Uint8List(0));
  return (
    AppController(
      packStore: store,
      settings: settings,
      feed: feed ?? Feed(),
      client: client,
      apiBase: api,
      launch: (_) async => true,
      pickApk: picker ? () async => PickedApk(picks ?? 'file.apk', size ?? data.length, () async => data) : null,
    ),
    posted,
  );
}

Future<void> pump(WidgetTester t, AppController c) async {
  t.view.physicalSize = const Size(800, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: HomePage(controller: c)));
}

Future<void> choose(WidgetTester t) async {
  await t.tap(find.text(tr('checkApk', 'hi')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('without a way to pick files there is no app-file button', (t) async {
    final (c, _) = await setup(picker: false);
    await pump(t, c);
    expect(find.text(tr('checkApk', 'hi')), findsNothing);
  });

  testWidgets('a fake-looking app is dangerous, and what it asks for is listed in plain words', (t) async {
    final (c, _) = await setup(picks: 'fake_pmkisan.apk');
    await pump(t, c);
    await choose(t);
    expect(find.text(tr('dangerousTitle', 'hi')), findsOneWidget);
    expect(find.text(tr('apkAsks', 'hi')), findsOneWidget);
    expect(find.textContaining('com.pmkisan.yojana.free'), findsOneWidget);
    expect(find.textContaining('आपके टेक्स्ट मैसेज पढ़ना'), findsOneWidget);
    expect(find.text(tr('apkNote', 'hi')), findsOneWidget);
    expect(find.text(tr('apkPrivate', 'hi')), findsOneWidget);
  });

  testWidgets('a harmless app gets "no warning signs"', (t) async {
    final (c, _) = await setup(picks: 'torch_ok.apk');
    await pump(t, c);
    await choose(t);
    expect(find.text(tr('safeTitle', 'hi')), findsOneWidget);
    expect(find.textContaining('टॉर्च इस्तेमाल करना'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('a file that is not an app gives a clear message and no verdict', (t) async {
    final (c, _) = await setup(picks: 'not_an_apk.apk');
    await pump(t, c);
    await choose(t);
    expect(find.text(tr('apkNotApp', 'hi')), findsOneWidget);
    expect(find.text(tr('dangerousTitle', 'hi')), findsNothing);
    expect(find.text(tr('safeTitle', 'hi')), findsNothing);
  });

  testWidgets('a huge file is refused before it is read', (t) async {
    var read = false;
    final (c, _) = await setup(picks: 'torch_ok.apk', size: maxApkBytes + 1);
    final picker = c.pickApk!;
    expect(picker, isNotNull);
    await c.checkApk(PickedApk('big.apk', maxApkBytes + 1, () async {
      read = true;
      return Uint8List(0);
    }));
    expect(c.apkMessage, 'apkTooBig');
    expect(read, isFalse);
    expect(c.result, isNull);
  });

  testWidgets('the bundled sample app files work and are explained', (t) async {
    final (c, _) = await setup(picker: true);
    await pump(t, c);
    await t.tap(find.text(tr('sampleApkFake', 'hi')));
    await t.pumpAndSettle();
    expect(find.text(tr('dangerousTitle', 'hi')), findsOneWidget);
    await t.tap(find.text(tr('sampleApkOk', 'hi')));
    await t.pumpAndSettle();
    expect(find.text(tr('safeTitle', 'hi')), findsOneWidget);
  });

  testWidgets('an app file that others already reported is dangerous even if its permissions look fine', (t) async {
    final feed = Feed();
    final (probe, _) = await setup(picks: 'torch_ok.apk');
    await probe.checkApk(await probe.pickApk!() as PickedApk);
    final sha = probe.result!.apk!.sha256;
    feed.families['apk_sha256:$sha'] = 'fake_apk';
    final (c, _) = await setup(picks: 'torch_ok.apk', feed: feed);
    await pump(t, c);
    await choose(t);
    expect(find.text(tr('dangerousTitle', 'hi')), findsOneWidget);
  });

  testWidgets('reporting an app file sends its SHA-256 and never the file or its name', (t) async {
    final (c, posted) = await setup(picks: 'fake_pmkisan.apk', api: Uri.parse('https://api.example.test'), reporting: true);
    await pump(t, c);
    await choose(t);
    await t.tap(find.text(tr('report', 'hi')));
    await t.pumpAndSettle();
    final apk = posted.where((p) => p['kind'] == 'apk_sha256').toList();
    expect(apk.length, 1);
    expect(apk.single['value_hash'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(apk.single['value_hash'], c.result!.apk!.sha256);
    final all = jsonEncode(posted);
    for (final secret in ['pmkisan', 'fake_pmkisan', 'READ_SMS', 'com.pmkisan']) {
      expect(all.contains(secret), isFalse, reason: 'leaked "$secret"');
    }
  });
}
