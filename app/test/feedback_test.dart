import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamsaathi/app_controller.dart';
import 'package:scamsaathi/services/feed.dart';
import 'package:scamsaathi/services/masking.dart';
import 'package:scamsaathi/services/pack_store.dart';
import 'package:scamsaathi/services/settings.dart';
import 'package:scamsaathi/ui/home_page.dart';
import 'package:scamsaathi/ui/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const scam = 'Call 9876543210 now, update KYC at http://sbi-kyc-update.xyz/verify?id=7 or your account will be blocked';

Future<(AppController, List<Map<String, dynamic>>)> setup({Uri? api, int status = 201}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings(await SharedPreferences.getInstance());
  final store = await PackStore.load(
    verifier: PackVerifier(File('test/fixtures/test.pub').readAsStringSync()),
    storage: MemoryPackStorage(),
    bundled: File('test/fixtures/pack.json').readAsBytesSync(),
  );
  final posted = <Map<String, dynamic>>[];
  final client = MockClient((req) async {
    posted.add({'path': req.url.path, ...jsonDecode(req.body) as Map<String, dynamic>});
    return http.Response('{}', status);
  });
  return (
    AppController(packStore: store, settings: settings, feed: Feed(), client: client, apiBase: api, launch: (_) async => true),
    posted,
  );
}

Future<void> pump(WidgetTester t, AppController c) async {
  t.view.physicalSize = const Size(800, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: HomePage(controller: c)));
  await t.enterText(find.byType(TextField).first, scam);
  await t.tap(find.text(tr('check', 'hi')).first);
  await t.pumpAndSettle();
}

void main() {
  test('masking gives the same answer as the server on every shared vector', () {
    final cases = (jsonDecode(File('../packs/core/masking_cases.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
    expect(cases.length, greaterThanOrEqualTo(15));
    for (final c in cases) {
      expect(maskText(c['in'] as String), c['out'], reason: c['in'] as String);
    }
  });

  test('masking twice changes nothing', () {
    final once = maskText('Call 9876543210, OTP 482913, mail a.b@gmail.com, pay x.y@ybl, see http://evil.xyz/a?b=1');
    expect(maskText(once), once);
  });

  testWidgets('an offline build never offers to send anything', (t) async {
    final (c, _) = await setup();
    await pump(t, c);
    expect(find.text(tr('wrongResult', 'hi')), findsNothing);
  });

  testWidgets('nothing is sent until Send; the sheet shows the masked text; the right label is suggested', (t) async {
    final (c, posted) = await setup(api: Uri.parse('https://api.example.test'));
    await pump(t, c);
    await t.tap(find.text(tr('wrongResult', 'hi')));
    await t.pumpAndSettle();
    expect(posted, isEmpty);
    final field = t.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, contains('9XXXXXXXXX'));
    expect(field.controller!.text, isNot(contains('9876543210')));
    expect(field.controller!.text, contains('sbi-kyc-update.xyz'), reason: 'the scam website is the useful part');
    expect(field.controller!.text, isNot(contains('id=7')));
    await t.tap(find.text(tr('fbSend', 'hi')));
    await t.pumpAndSettle();
    expect(posted.length, 1);
    final body = posted.single;
    expect((body['path'], body['label'], body['app_verdict']), ('/v1/feedback', 'normal', 'dangerous')); // it said dangerous -> "normal" is the likely complaint
    expect(body['text'], isNot(contains('9876543210')));
    expect(body.keys.toSet(), {'path', 'text', 'label', 'app_verdict', 'family', 'lang'}, reason: 'no identifier of any kind');
    expect(find.text(tr('fbThanks', 'hi')), findsOneWidget);
  });

  testWidgets('a number the person types is masked before sending', (t) async {
    final (c, posted) = await setup(api: Uri.parse('https://api.example.test'));
    await pump(t, c);
    await t.tap(find.text(tr('wrongResult', 'hi')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Ramesh here, call me on 9123456780, OTP 112233, this is a real bank message');
    await t.pump();
    await t.tap(find.text(tr('fbSend', 'hi')));
    await t.pumpAndSettle();
    expect(posted.single['text'], 'Ramesh here, call me on 9XXXXXXXXX, OTP XXXXXX, this is a real bank message');
  });

  testWidgets('Cancel sends nothing', (t) async {
    final (c, posted) = await setup(api: Uri.parse('https://api.example.test'));
    await pump(t, c);
    await t.tap(find.text(tr('wrongResult', 'hi')));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('fbCancel', 'hi')));
    await t.pumpAndSettle();
    expect(posted, isEmpty);
  });

  testWidgets('a server error is reported honestly, not as thanks', (t) async {
    final (c, _) = await setup(api: Uri.parse('https://api.example.test'), status: 500);
    await pump(t, c);
    await t.tap(find.text(tr('wrongResult', 'hi')));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('fbSend', 'hi')));
    await t.pumpAndSettle();
    expect(find.text(tr('fbFailed', 'hi')), findsOneWidget);
    expect(find.text(tr('fbThanks', 'hi')), findsNothing);
  });
}
