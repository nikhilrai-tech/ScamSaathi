import 'package:flutter/material.dart';

import '../engine/apk.dart';
import 'permission_labels.dart';
import 'strings.dart';
import 'theme.dart';

/// What an app file asks for, in plain words. Shown under the verdict when an APK was checked.
class ApkDetails extends StatelessWidget {
  const ApkDetails({super.key, required this.apk, required this.lang, required this.palette});
  final ApkInfo apk;
  final String lang;
  final VerdictPalette palette;

  @override
  Widget build(BuildContext context) {
    final all = {...apk.permissions, ...apk.componentPermissions}.toList()..sort();
    final known = [for (final p in all) if (permissionLabels.containsKey(p)) p];
    // dangerous requests first, then the harmless ones
    known.sort((a, b) => (permissionLabels[b]!.risky ? 1 : 0) - (permissionLabels[a]!.risky ? 1 : 0));
    final others = all.length - known.length;
    final style = TextStyle(fontSize: 16, height: 1.35, color: palette.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text(tr('apkAsks', lang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.text)),
      const SizedBox(height: 4),
      Text('${tr('apkPackage', lang)}: ${apk.package}', style: style.copyWith(fontSize: 14)),
      for (final p in known)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(permissionLabels[p]!.risky ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: 20, color: permissionLabels[p]!.risky ? palette.accent : palette.text.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Expanded(child: Text(lang == 'hi' ? permissionLabels[p]!.hi : permissionLabels[p]!.en, style: style)),
          ]),
        ),
      if (others > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('+ $others ${tr('apkMore', lang)}', style: style.copyWith(fontSize: 14))),
      const SizedBox(height: 10),
      Text(tr('apkNote', lang), style: style.copyWith(fontSize: 14)),
      Text(tr('apkPrivate', lang), style: style.copyWith(fontSize: 14)),
    ]);
  }
}
