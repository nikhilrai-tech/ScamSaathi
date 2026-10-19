import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../engine/engine.dart';
import 'settings_page.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _text = TextEditingController();
  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_sync);
    _text.text = c.text;
  }

  void _sync() {
    if (_text.text != c.text) _text.text = c.text; // text shared in from another app
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _text.text = data!.text!;
      c.check(_text.text);
    }
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage(controller: c)));

  Future<void> _tell({bool whatsapp = false}) async {
    if (c.settings.saathi == null) {
      _openSettings();
      return;
    }
    await c.tellSaathi(whatsapp: whatsapp);
  }

  @override
  Widget build(BuildContext context) {
    final lang = c.lang;
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BrandHeader(lang: lang, onLanguage: () => c.setLanguage(lang == 'hi' ? 'en' : 'hi'), onSettings: _openSettings),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 10,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(hintText: tr('hint', lang)),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste),
                      label: Text(tr('paste', lang), style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => c.check(_text.text),
                        icon: const Icon(Icons.shield_outlined),
                        label: Text(tr('check', lang), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  SampleChips(lang: lang, onPick: c.check),
                  AnimatedSize(
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: c.result == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              _ResultCard(c: c, a: c.result!, onTell: _tell),
                              TextButton(onPressed: c.clear, child: Text(tr('clear', lang))),
                            ]),
                          ),
                  ),
                  const SizedBox(height: 16),
                  RulesCard(lang: lang),
                  const SizedBox(height: 20),
                  Text(tr('unsure', lang), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('${tr('rules', lang)}: ${c.packStore.current.version}', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.c, required this.a, required this.onTell});
  final AppController c;
  final Analysis a;
  final Future<void> Function({bool whatsapp}) onTell;

  @override
  Widget build(BuildContext context) {
    final lang = c.lang, p = paletteFor(a.verdict, Theme.of(context).brightness);
    final titleKey = '${a.verdict}Title', adviceKey = '${a.verdict}Advice';
    return Semantics(
      container: true,
      label: tr(titleKey, lang),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: p.background, border: Border.all(color: p.accent, width: 2), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(p.icon, color: p.accent, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Text(tr(titleKey, lang), style: TextStyle(color: p.accent, fontSize: 23, fontWeight: FontWeight.w800, height: 1.2))),
          ]),
          const SizedBox(height: 14),
          WarningMeter(palette: p, lang: lang),
          const SizedBox(height: 14),
          Text(tr(adviceKey, lang), style: TextStyle(fontSize: 18, height: 1.35, color: p.text)),
          if (a.verdict != 'safe') ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: KindChip(family: a.family, lang: lang, palette: p)),
          ],
          if (a.reasons.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(tr('why', lang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.text)),
            for (final r in a.reasons) ReasonTile(reason: r, lang: lang, palette: p),
          ],
          if (a.verdict != 'safe') ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => onTell(),
              icon: const Icon(Icons.sms_outlined),
              label: Text(c.settings.saathi == null ? tr('setSaathiFirst', lang) : tr('tellSaathi', lang), style: const TextStyle(fontSize: 18)),
              style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.background),
            ),
            if (c.settings.saathi != null)
              TextButton.icon(
                onPressed: () => onTell(whatsapp: true),
                icon: const Icon(Icons.chat_outlined),
                label: Text(tr('tellSaathiWhatsApp', lang), style: TextStyle(fontSize: 17, color: p.text)),
              ),
          ],
          if (a.verdict == 'dangerous')
            TextButton.icon(
              onPressed: c.callHelpline,
              icon: Icon(Icons.call, color: p.text),
              label: Text(tr('call1930', lang), style: TextStyle(fontSize: 17, color: p.text)),
            ),
          if (c.canReport && c.reportOutcome == ReportOutcome.none)
            TextButton.icon(
              onPressed: c.report,
              icon: Icon(Icons.flag_outlined, color: p.text),
              label: Text(tr('report', lang), style: TextStyle(fontSize: 17, color: p.text)),
            ),
          if (c.reportOutcome == ReportOutcome.sent) Text(tr('reported', lang), style: TextStyle(fontSize: 17, color: p.text)),
          if (c.reportOutcome == ReportOutcome.failed) Text(tr('reportFailed', lang), style: TextStyle(fontSize: 17, color: p.text)),
        ]),
      ),
    );
  }
}
