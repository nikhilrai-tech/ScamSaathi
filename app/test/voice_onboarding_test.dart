import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamsaathi/app_controller.dart';
import 'package:scamsaathi/main.dart' show ScamSaathiApp;
import 'package:scamsaathi/services/feed.dart';
import 'package:scamsaathi/services/pack_store.dart';
import 'package:scamsaathi/services/settings.dart';
import 'package:scamsaathi/services/speaker.dart';
import 'package:scamsaathi/ui/home_page.dart';
import 'package:scamsaathi/ui/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSpeaker implements Speaker {
  final spoken = <(String, String)>[];
  var stops = 0;
  @override
  Future<void> speak(String text, String lang) async => spoken.add((text, lang));
  @override
  Future<void> stop() async => stops++;
}

const scam = 'Call 9876543210 now, update KYC at http://sbi-kyc-update.xyz/verify or your account will be blocked';

Future<(AppController, FakeSpeaker, List<Uri>)> setup({bool onboarded = true, bool speaker = true}) async {
  SharedPreferences.setMockInitialValues({'onboarded': onboarded});
  final settings = AppSettings(await SharedPreferences.getInstance());
  final store = await PackStore.load(
    verifier: PackVerifier(File('test/fixtures/test.pub').readAsStringSync()),
    storage: MemoryPackStorage(),
    bundled: File('../packs/core/pack.json').readAsBytesSync(),
  );
  final fake = FakeSpeaker();
  final launched = <Uri>[];
  return (
    AppController(
      packStore: store,
      settings: settings,
      feed: Feed(),
      client: MockClient((_) async => http.Response('{}', 200)),
      launch: (u) async {
        launched.add(u);
        return true;
      },
      speaker: speaker ? fake : null,
    ),
    fake,
    launched,
  );
}

Future<void> big(WidgetTester t) async {
  t.view.physicalSize = const Size(800, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> check(WidgetTester t, AppController c) async {
  await t.pumpWidget(MaterialApp(home: HomePage(controller: c)));
  await t.enterText(find.byType(TextField).first, scam);
  await t.tap(find.text(tr('check', 'hi')).first);
  await t.pumpAndSettle();
}

void main() {
  group('reading aloud', () {
    testWidgets('speaks the verdict and the reasons, never the message, a link or a number', (t) async {
      await big(t);
      final (c, fake, _) = await setup();
      await check(t, c);
      await t.tap(find.text(tr('listen', 'hi')));
      await t.pumpAndSettle();
      expect(fake.spoken.length, 1);
      final (text, lang) = fake.spoken.single;
      expect(lang, 'hi');
      expect(text, contains(tr('dangerousTitle', 'hi')));
      expect(text, contains(tr('dangerousAdvice', 'hi')));
      for (final secret in ['9876543210', 'sbi-kyc-update', 'http', 'update KYC at']) {
        expect(text.contains(secret), isFalse, reason: 'spoke "$secret"');
      }
    });

    testWidgets('the button turns into Stop and stops; checking something else stops the voice', (t) async {
      await big(t);
      final (c, fake, _) = await setup();
      await check(t, c);
      await t.tap(find.text(tr('listen', 'hi')));
      await t.pumpAndSettle();
      expect(find.text(tr('stopListening', 'hi')), findsOneWidget);
      await t.tap(find.text(tr('stopListening', 'hi')));
      await t.pumpAndSettle();
      expect(fake.stops, 1);
      expect(find.text(tr('listen', 'hi')), findsOneWidget);
      await t.tap(find.text(tr('listen', 'hi')));
      await t.pumpAndSettle();
      c.check('Meeting at 4 pm tomorrow');
      await t.pumpAndSettle();
      expect(fake.stops, 2, reason: 'a new check must not keep reading the old result');
      expect(c.speaking, isFalse);
    });

    testWidgets('it speaks in the language chosen, and there is no button where speech is unavailable', (t) async {
      await big(t);
      var (c, fake, _) = await setup();
      c.setLanguage('en');
      await t.pumpWidget(MaterialApp(home: HomePage(controller: c)));
      await t.enterText(find.byType(TextField).first, scam);
      await t.tap(find.text(tr('check', 'en')).first);
      await t.pumpAndSettle();
      await t.tap(find.text(tr('listen', 'en')));
      await t.pumpAndSettle();
      expect(fake.spoken.single.$2, 'en');
      expect(fake.spoken.single.$1, contains(tr('dangerousTitle', 'en')));

      (c, fake, _) = await setup(speaker: false);
      await check(t, c);
      expect(find.text(tr('listen', 'hi')), findsNothing);
    });
  });

  group('first run', () {
    testWidgets('a new install shows the three screens, then the home screen', (t) async {
      await big(t);
      final (c, _, _) = await setup(onboarded: false);
      await t.pumpWidget(ScamSaathiApp(c));
      await t.pumpAndSettle();
      expect(find.text(tr('ob1Title', 'hi')), findsOneWidget);
      await t.tap(find.text(tr('obNext', 'hi')));
      await t.pumpAndSettle();
      expect(find.text(tr('ob2Title', 'hi')), findsOneWidget);
      await t.tap(find.text(tr('obNext', 'hi')));
      await t.pumpAndSettle();
      expect(find.text(tr('ob3Title', 'hi')), findsOneWidget);
      await t.tap(find.text(tr('obStart', 'hi')));
      await t.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(c.settings.onboarded, isTrue);
      expect(c.settings.saathi, isNull, reason: 'choosing a Saathi is optional');
    });

    testWidgets('a Saathi typed on the last screen is saved; Skip goes straight in', (t) async {
      await big(t);
      var (c, _, _) = await setup(onboarded: false);
      await t.pumpWidget(ScamSaathiApp(c));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('obNext', 'hi')));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('obNext', 'hi')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Ramesh');
      await t.enterText(find.byType(TextField).last, '+91 00000 00000');
      await t.tap(find.text(tr('obStart', 'hi')));
      await t.pumpAndSettle();
      expect((c.settings.saathi?.name, c.settings.saathi?.phone), ('Ramesh', '+910000000000'));

      (c, _, _) = await setup(onboarded: false);
      await t.pumpWidget(ScamSaathiApp(c, key: UniqueKey()));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('obSkip', 'hi')));
      await t.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(c.settings.onboarded, isTrue);
    });

    testWidgets('the language can be switched on the first screen, and a returning user never sees it again', (t) async {
      await big(t);
      var (c, _, _) = await setup(onboarded: false);
      await t.pumpWidget(ScamSaathiApp(c));
      await t.pumpAndSettle();
      await t.tap(find.text('English'));
      await t.pumpAndSettle();
      expect(find.text(tr('ob1Title', 'en')), findsOneWidget);

      (c, _, _) = await setup(onboarded: true);
      await t.pumpWidget(ScamSaathiApp(c, key: UniqueKey()));
      await t.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text(tr('ob1Title', 'hi')), findsNothing);
    });
  });

  group('privacy and how it works', () {
    testWidgets('both pages are reachable from settings, say what matters, and the details link opens GitHub', (t) async {
      await big(t);
      final (c, _, launched) = await setup();
      await t.pumpWidget(MaterialApp(home: HomePage(controller: c)));
      await t.tap(find.byIcon(Icons.settings));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('aboutPrivacy', 'hi')));
      await t.pumpAndSettle();
      for (final k in ['p1', 'p2', 'p3', 'p4']) {
        expect(find.text(tr(k, 'hi')), findsOneWidget, reason: k);
      }
      await t.tap(find.text(tr('readMore', 'hi')));
      await t.pump();
      expect(launched.single.toString(), endsWith('docs/PRIVACY.md'));
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.text(tr('aboutHow', 'hi')));
      await t.pumpAndSettle();
      expect(find.text(tr('h3', 'hi')), findsOneWidget, reason: 'the page says plainly that it can be wrong');
    });

    test('every new text exists in both languages', () {
      for (final k in ['listen', 'stopListening', 'obNext', 'obSkip', 'obStart', 'ob1Title', 'ob1Body', 'ob2Title', 'ob2Body', 'ob3Title', 'ob3Body',
        'aboutSection', 'aboutPrivacy', 'aboutHow', 'readMore', 'p1', 'p2', 'p3', 'p4', 'h1', 'h2', 'h3', 'h4', 'h5']) {
        for (final lang in languages.keys) {
          expect(tr(k, lang), isNot(k), reason: '$k missing in $lang');
          expect(tr(k, lang).trim(), isNotEmpty);
        }
      }
    });
  });
}
