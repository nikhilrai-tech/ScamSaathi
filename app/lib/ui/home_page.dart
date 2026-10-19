import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../engine/engine.dart';
import 'settings_page.dart';
import 'strings.dart';

class _VerdictStyle {
  final Color color, background;
  final IconData icon;
  final String titleKey, adviceKey;
  const _VerdictStyle(this.color, this.background, this.icon, this.titleKey, this.adviceKey);
}

// Meaning is carried by icon and words as well as colour, so it works for colour-blind users and in sunlight.
const _styles = {
  'dangerous': _VerdictStyle(Color(0xFFB3261E), Color(0xFFFDECEA), Icons.dangerous_outlined, 'dangerousTitle', 'dangerousAdvice'),
  'suspicious': _VerdictStyle(Color(0xFF8A5A00), Color(0xFFFFF4DB), Icons.warning_amber_rounded, 'suspiciousTitle', 'suspiciousAdvice'),
  'safe': _VerdictStyle(Color(0xFF1B6E3C), Color(0xFFE6F4EA), Icons.info_outline, 'safeTitle', 'safeAdvice'),
};

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
      appBar: AppBar(
        title: Text(tr('appName', lang)),
        actions: [
          TextButton(
            onPressed: () => c.setLanguage(lang == 'hi' ? 'en' : 'hi'),
            child: Text(lang == 'hi' ? languages['en']! : languages['hi']!, style: const TextStyle(fontSize: 18)),
          ),
          IconButton(tooltip: tr('settings', lang), icon: const Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('tagline', lang), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.lock_outline, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('privacy', lang))),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 10,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: tr('hint', lang)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: Text(tr('paste', lang), style: const TextStyle(fontSize: 18)),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => c.check(_text.text),
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(tr('check', lang), style: const TextStyle(fontSize: 20)),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                ),
              ),
            ]),
            if (c.result != null) ...[
              const SizedBox(height: 20),
              _ResultCard(c: c, a: c.result!, onTell: _tell),
              const SizedBox(height: 12),
              TextButton(onPressed: () => c.clear(), child: Text(tr('clear', lang))),
            ],
            const SizedBox(height: 24),
            Text(tr('unsure', lang), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('${tr('rules', lang)}: ${c.packStore.current.version}', style: Theme.of(context).textTheme.bodySmall),
          ],
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
    final lang = c.lang, st = _styles[a.verdict]!;
    return Semantics(
      container: true,
      label: tr(st.titleKey, lang),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: st.background, border: Border.all(color: st.color, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(st.icon, color: st.color, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(tr(st.titleKey, lang), style: TextStyle(color: st.color, fontSize: 22, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          Text(tr(st.adviceKey, lang), style: const TextStyle(fontSize: 18, color: Colors.black87)),
          if (a.reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(tr('why', lang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            for (final r in a.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  ', style: TextStyle(fontSize: 18, color: Colors.black87)),
                  Expanded(child: Text(r.text[lang] ?? r.text['en'] ?? '', style: const TextStyle(fontSize: 17, color: Colors.black87))),
                ]),
              ),
          ],
          if (a.verdict != 'safe') ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => onTell(),
              icon: const Icon(Icons.sms_outlined),
              label: Text(c.settings.saathi == null ? tr('setSaathiFirst', lang) : tr('tellSaathi', lang), style: const TextStyle(fontSize: 18)),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: st.color),
            ),
            if (c.settings.saathi != null)
              TextButton.icon(
                onPressed: () => onTell(whatsapp: true),
                icon: const Icon(Icons.chat_outlined),
                label: Text(tr('tellSaathiWhatsApp', lang), style: const TextStyle(fontSize: 17)),
              ),
          ],
          if (a.verdict == 'dangerous')
            TextButton.icon(
              onPressed: () => c.callHelpline(),
              icon: const Icon(Icons.call),
              label: Text(tr('call1930', lang), style: const TextStyle(fontSize: 17)),
            ),
          if (c.canReport && c.reportOutcome == ReportOutcome.none)
            TextButton.icon(
              onPressed: () => c.report(),
              icon: const Icon(Icons.flag_outlined),
              label: Text(tr('report', lang), style: const TextStyle(fontSize: 17)),
            ),
          if (c.reportOutcome == ReportOutcome.sent) Text(tr('reported', lang), style: const TextStyle(fontSize: 17, color: Colors.black87)),
          if (c.reportOutcome == ReportOutcome.failed) Text(tr('reportFailed', lang), style: const TextStyle(fontSize: 17, color: Colors.black87)),
        ]),
      ),
    );
  }
}
