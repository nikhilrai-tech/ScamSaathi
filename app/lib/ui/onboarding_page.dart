import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/saathi.dart';
import 'strings.dart';
import 'theme.dart';

/// Three short screens the first time the app opens: what it does, that it is private, and an optional Saathi. Skippable at any point.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller, required this.onDone});
  final AppController controller;
  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  int _i = 0;

  AppController get c => widget.controller;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _finish() {
    final phone = _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (_name.text.trim().isNotEmpty && phone.length >= 7) c.saveSaathi(Saathi(_name.text.trim(), phone));
    c.settings.onboarded = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: c, builder: (context, _) => _screen(context)); // the language switch must redraw this screen

  Widget _screen(BuildContext context) {
    final lang = c.lang;
    final icons = [Icons.shield_outlined, Icons.lock_outline, Icons.people_outline];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandMid])),
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                  onPressed: () => c.setLanguage(lang == 'hi' ? 'en' : 'hi'),
                  child: Text(lang == 'hi' ? languages['en']! : languages['hi']!, style: const TextStyle(color: Colors.white, fontSize: 17)),
                ),
                TextButton(onPressed: _finish, child: Text(tr('obSkip', lang), style: const TextStyle(color: Colors.white, fontSize: 17))),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (v) => setState(() => _i = v),
                children: [
                  for (var n = 0; n < 3; n++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(icons[n], size: 88, color: Colors.white),
                        const SizedBox(height: 28),
                        Text(tr('ob${n + 1}Title', lang), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        Text(tr('ob${n + 1}Body', lang), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.4)),
                        if (n == 2) ...[
                          const SizedBox(height: 20),
                          _field(_name, tr('saathiName', lang), TextInputType.name),
                          const SizedBox(height: 10),
                          _field(_phone, tr('saathiPhone', lang), TextInputType.phone),
                        ],
                      ]),
                    ),
                ],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var n = 0; n < 3; n++)
                Container(
                  margin: const EdgeInsets.all(4),
                  width: n == _i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: n == _i ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brandDark),
                  onPressed: _i < 2 ? () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : _finish,
                  child: Text(tr(_i < 2 ? 'obNext' : 'obStart', lang), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, TextInputType type) => TextField(
        controller: c,
        keyboardType: type,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white),
      );
}
