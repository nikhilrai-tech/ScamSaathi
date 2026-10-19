import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../services/saathi.dart';
import 'strings.dart';
import 'theme.dart';

/// Messages people can try with one tap. All made up; none is a real person's message.
const samples = <(String, String)>[
  ('sampleKyc', 'SBI KYC update karo warna account block ho jayega. Link: http://sbi-kyc-update.xyz/verify'),
  ('sampleApk', 'PM Kisan ki nayi list aayi hai. Yeh file install karo: PM-Kisan-Yojana.apk'),
  ('sampleUpi', 'Sir, aapka refund pending hai. UPI collect request approve karein aur enter UPI PIN to receive money.'),
  ('sampleOk', 'बेटा, कल शाम 4 बजे मीटिंग है, समय से आ जाना।'),
];

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.lang, required this.onLanguage, required this.onSettings});
  final String lang;
  final VoidCallback onLanguage, onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brandDark, brandMid]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 22),
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Image.asset('assets/logo.png', width: 36, height: 36, semanticLabel: 'ScamSaathi logo'),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('ScamSaathi', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ),
            TextButton(
              onPressed: onLanguage,
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white24),
              child: Text(lang == 'hi' ? languages['en']! : languages['hi']!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            IconButton(tooltip: tr('settings', lang), color: Colors.white, icon: const Icon(Icons.settings), onPressed: onSettings),
          ]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(tr('tagline', lang), style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.3, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(child: Text(tr('privacy', lang), style: const TextStyle(color: Colors.white, fontSize: 15))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class SampleChips extends StatelessWidget {
  const SampleChips({super.key, required this.lang, required this.onPick});
  final String lang;
  final void Function(String text) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('trySample', lang), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (key, text) in samples)
          ActionChip(
            label: Text(tr(key, lang), style: const TextStyle(fontSize: 16)),
            onPressed: () => onPick(text),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          ),
      ]),
    ]);
  }
}

/// Three pills, not a percentage: a number would look like a probability, which it is not.
class WarningMeter extends StatelessWidget {
  const WarningMeter({super.key, required this.palette, required this.lang});
  final VerdictPalette palette;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final names = [tr('levelLow', lang), tr('levelMid', lang), tr('levelHigh', lang)];
    return Semantics(
      label: '${tr('level', lang)}: ${names[palette.level - 1]}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${tr('level', lang)}: ${names[palette.level - 1]}',
            style: TextStyle(color: palette.text, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Container(
                height: 10,
                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i <= palette.level ? palette.accent : palette.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class ReasonTile extends StatelessWidget {
  const ReasonTile({super.key, required this.reason, required this.lang, required this.palette});
  final Reason reason;
  final String lang;
  final VerdictPalette palette;

  static IconData iconFor(String id) {
    if (id.startsWith('url.') || id == 'feed.confirmed') return Icons.link;
    if (id.contains('apk') || id == 'install.ask') return Icons.android;
    return switch (id) {
      'otp.ask' || 'kyc.ask' => Icons.password,
      'upi.collect' || 'money.receive' => Icons.currency_rupee,
      'urgency' => Icons.timer_outlined,
      'threat.contacts' || 'threat.secrecy' || 'impersonation' => Icons.record_voice_over_outlined,
      'fee.advance' || 'prize' || 'loan.instant' => Icons.payments_outlined,
      'remote.access' => Icons.screen_share_outlined,
      _ => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: palette.accent.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(iconFor(reason.id), size: 20, color: palette.accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(reason.text[lang] ?? reason.text['en'] ?? '', style: TextStyle(fontSize: 17, height: 1.35, color: palette.text))),
      ]),
    );
  }
}

class KindChip extends StatelessWidget {
  const KindChip({super.key, required this.family, required this.lang, required this.palette});
  final String family, lang;
  final VerdictPalette palette;

  @override
  Widget build(BuildContext context) {
    final label = familyLabels[family]?[lang];
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: palette.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
      child: Text('${tr('kindOfScam', lang)}: $label', style: TextStyle(color: palette.text, fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

class RulesCard extends StatelessWidget {
  const RulesCard({super.key, required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    final rules = ['rule1', 'rule2', 'rule3'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.rule, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(tr('rulesTitle', lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          for (var i = 0; i < rules.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 13, child: Text('${i + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Text(tr(rules[i], lang), style: const TextStyle(fontSize: 17, height: 1.35))),
              ]),
            ),
        ]),
      ),
    );
  }
}
