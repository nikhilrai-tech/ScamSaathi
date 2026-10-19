import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'strings.dart';

enum InfoKind { privacy, how }

/// Short, plain pages in the person's language: what happens to their data, and how a verdict is made (including that it can be wrong).
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.controller, required this.kind});
  final AppController controller;
  final InfoKind kind;

  @override
  Widget build(BuildContext context) {
    final lang = controller.lang;
    final isPrivacy = kind == InfoKind.privacy;
    final keys = isPrivacy ? ['p1', 'p2', 'p3', 'p4'] : ['h1', 'h2', 'h3', 'h4', 'h5'];
    return Scaffold(
      appBar: AppBar(title: Text(tr(isPrivacy ? 'aboutPrivacy' : 'aboutHow', lang))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(isPrivacy ? Icons.lock_outline : Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(tr(k, lang), style: const TextStyle(fontSize: 18, height: 1.4))),
              ]),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => controller.launch(Uri.parse(isPrivacy
                ? 'https://github.com/nikhilrai-tech/ScamSaathi/blob/main/docs/PRIVACY.md'
                : 'https://github.com/nikhilrai-tech/ScamSaathi/blob/main/docs/EVALUATION.md')),
            icon: const Icon(Icons.open_in_new),
            label: Text(tr('readMore', lang), style: const TextStyle(fontSize: 17)),
          ),
        ]),
      ),
    );
  }
}
