import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/masking.dart';
import 'strings.dart';

/// "This result is wrong": the person sees exactly what would be sent (already masked), can edit it, and nothing leaves the phone
/// until they tap Send.
Future<void> showFeedbackSheet(BuildContext context, AppController c) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FeedbackSheet(controller: c),
    ),
  );
}

class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key, required this.controller});
  final AppController controller;

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  late final _text = TextEditingController(text: maskText(widget.controller.text));
  // the app said "no warning signs" -> the person most likely means a missed scam, and the other way round
  late FeedbackLabel _label = widget.controller.result?.verdict == 'safe' ? FeedbackLabel.scam : FeedbackLabel.normal;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final c = widget.controller, lang = c.lang;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    final ok = await c.sendFeedback(label: _label, text: maskText(_text.text).trim()); // masked again, in case the person typed a number
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(tr(ok ? 'fbThanks' : 'fbFailed', lang))));
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.lang;
    final long = _text.text.trim().length < 5 || _text.text.length > 600;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('fbTitle', lang), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(tr('fbIntro', lang)),
          const SizedBox(height: 12),
          RadioGroup<FeedbackLabel>(
            groupValue: _label,
            onChanged: (v) => setState(() => _label = v ?? _label),
            child: Column(children: [
              RadioListTile<FeedbackLabel>(value: FeedbackLabel.scam, title: Text(tr('fbLabelScam', lang), style: const TextStyle(fontSize: 17))),
              RadioListTile<FeedbackLabel>(value: FeedbackLabel.normal, title: Text(tr('fbLabelNormal', lang), style: const TextStyle(fontSize: 17))),
            ]),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 8,
            maxLength: 600,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('fbEdit', lang), helperText: tr('fbNames', lang), helperMaxLines: 2),
          ),
          const SizedBox(height: 8),
          Text(tr('fbStored', lang), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _sending ? null : () => Navigator.of(context).pop(), child: Text(tr('fbCancel', lang)))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _sending || long ? null : _send, child: Text(tr('fbSend', lang)))),
          ]),
        ]),
      ),
    );
  }
}
