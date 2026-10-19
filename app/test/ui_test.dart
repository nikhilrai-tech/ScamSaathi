import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamsaathi/app_controller.dart';
import 'package:scamsaathi/services/feed.dart';
import 'package:scamsaathi/services/pack_store.dart';
import 'package:scamsaathi/services/saathi.dart';
import 'package:scamsaathi/services/settings.dart';
import 'package:scamsaathi/ui/home_page.dart';
import 'package:scamsaathi/ui/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const scam = 'SBI KYC update karo warna account block ho jayega. Link: http://sbi-kyc-update.xyz/verify';
const fine = 'Meeting rescheduled to 4 pm tomorrow. Please confirm.';

Future<(AppController, List<Uri>, List<String>)> setup({bool reporting = false, Uri? api, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({if (reporting) 'report_opt_in': true, ...prefs});
  final settings = AppSettings(await SharedPreferences.getInstance());
  final bytes = File('test/fixtures/pack.json').readAsBytesSync();
  final store = await PackStore.load(
    verifier: PackVerifier(File('test/fixtures/test.pub').readAsStringSync()),
    storage: MemoryPackStorage(),
    bundled: bytes,
  );
  final launched = <Uri>[];
  final posted = <String>[];
  final client = MockClient((req) async {
    posted.add(req.body);
    return http.Response('{}', 201);
  });
  final c = AppController(
    packStore: store, settings: settings, feed: Feed(), client: client, apiBase: api,
    launch: (u) async {
      launched.add(u);
      return true;
    },
  );
  return (c, launched, posted);
}

Future<void> pump(WidgetTester t, AppController c) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: HomePage(controller: c)));
}

Future<void> check(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField), text);
  await t.tap(find.text(tr('check', 'hi')).first);
  await t.pumpAndSettle(); // the result card animates in
}

void main() {
  testWidgets('opens in Hindi and shows a dangerous verdict with reasons', (t) async {
    final (c, _, _) = await setup();
    await pump(t, c);
    await check(t, scam);
    expect(find.text(tr('dangerousTitle', 'hi')), findsOneWidget);
    expect(find.textContaining('केवाईसी'), findsWidgets);
    expect(find.text(tr('call1930', 'hi')), findsOneWidget);
  });

  testWidgets('English toggle changes the same verdict to English', (t) async {
    final (c, _, _) = await setup();
    await pump(t, c);
    await check(t, scam);
    await t.tap(find.text('English'));
    await t.pump();
    expect(find.text(tr('dangerousTitle', 'en')), findsOneWidget);
  });

  testWidgets('a normal message never claims to be 100% safe and offers no scam actions', (t) async {
    final (c, _, _) = await setup();
    await pump(t, c);
    await check(t, fine);
    expect(find.text(tr('safeTitle', 'hi')), findsOneWidget);
    expect(find.text(tr('safeAdvice', 'hi')), findsOneWidget);
    expect(find.text(tr('call1930', 'hi')), findsNothing);
    expect(find.text(tr('setSaathiFirst', 'hi')), findsNothing);
    expect(find.text(tr('tellSaathi', 'hi')), findsNothing);
  });

  testWidgets('without a Saathi the button sends you to settings, with one it opens the SMS app with a safe note', (t) async {
    final (c, launched, _) = await setup();
    await pump(t, c);
    await check(t, scam);
    await t.tap(find.text(tr('setSaathiFirst', 'hi')));
    await t.pumpAndSettle();
    expect(find.text(tr('saathiSection', 'hi')), findsWidgets);
    expect(launched, isEmpty);

    c.saveSaathi(const Saathi('Son', '+910000000000'));
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.text(tr('tellSaathi', 'hi')));
    await t.pump();
    expect(launched.single.scheme, 'sms');
    final body = launched.single.queryParameters['body']!;
    expect(body.contains('http'), isFalse);
    expect(body.contains('sbi-kyc'), isFalse);
  });

  testWidgets('1930 opens the dialler', (t) async {
    final (c, launched, _) = await setup();
    await pump(t, c);
    await check(t, scam);
    await t.tap(find.text(tr('call1930', 'hi')));
    await t.pump();
    expect((launched.single.scheme, launched.single.path), ('tel', '1930'));
  });

  testWidgets('the report button is hidden unless the user opted in and the build has a server', (t) async {
    var (c, _, _) = await setup(api: Uri.parse('https://api.example.test'));
    await pump(t, c);
    await check(t, scam);
    expect(find.text(tr('report', 'hi')), findsNothing, reason: 'opt-in is off by default');

    (c, _, _) = await setup(reporting: true); // opted in but this is an offline build
    await pump(t, c);
    await check(t, scam);
    expect(find.text(tr('report', 'hi')), findsNothing);
  });

  testWidgets('opted in: reporting sends hashes only, after the tap', (t) async {
    final (c, _, posted) = await setup(reporting: true, api: Uri.parse('https://api.example.test'));
    await pump(t, c);
    await check(t, scam);
    expect(posted, isEmpty, reason: 'checking alone sends nothing');
    await t.tap(find.text(tr('report', 'hi')));
    await t.pumpAndSettle();
    expect(posted, isNotEmpty);
    expect(posted.join().contains('sbi-kyc'), isFalse);
    expect(find.text(tr('reported', 'hi')), findsOneWidget);
  });

  testWidgets('text shared from another app is checked and shown', (t) async {
    final (c, _, _) = await setup();
    await pump(t, c);
    c.check(scam);
    await t.pumpAndSettle();
    expect(find.text(tr('dangerousTitle', 'hi')), findsOneWidget);
    expect(find.text(scam), findsOneWidget); // also visible in the box
  });

  testWidgets('settings: reporting switch is not even shown in an offline build', (t) async {
    final (c, _, _) = await setup();
    await pump(t, c);
    await t.tap(find.byIcon(Icons.settings));
    await t.pumpAndSettle();
    expect(find.text(tr('reportingSwitch', 'hi')), findsNothing);
  });

  test('every user-facing string exists in every language', () {
    final keys = RegExp(r"tr\('(\w+)'").allMatches(
      Directory('lib/ui').listSync().whereType<File>().map((f) => f.readAsStringSync()).join(),
    ).map((m) => m.group(1)!).toSet();
    for (final lang in languages.keys) {
      for (final k in keys) {
        expect(tr(k, lang), isNot(k), reason: 'missing "$k" in $lang');
      }
    }
  });
}
