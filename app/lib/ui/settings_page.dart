import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/saathi.dart';
import 'strings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppController get c => widget.controller;
  late final _name = TextEditingController(text: c.settings.ownName);
  late final _district = TextEditingController(text: c.settings.district);
  late final _saathiName = TextEditingController(text: c.settings.saathi?.name ?? '');
  late final _saathiPhone = TextEditingController(text: c.settings.saathi?.phone ?? '');

  @override
  void dispose() {
    for (final t in [_name, _district, _saathiName, _saathiPhone]) {
      t.dispose();
    }
    super.dispose();
  }

  void _saveSaathi() {
    final phone = _saathiPhone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (_saathiName.text.trim().isEmpty || phone.length < 7) return;
    c.saveSaathi(Saathi(_saathiName.text.trim(), phone), ownName: _name.text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = c.lang;
    final big = const TextStyle(fontSize: 18);
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings', lang))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(tr('language', lang), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [for (final e in languages.entries) ButtonSegment(value: e.key, label: Text(e.value, style: big))],
            selected: {lang},
            onSelectionChanged: (s) {
              c.setLanguage(s.first);
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          Text(tr('saathiSection', lang), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(tr('saathiHelp', lang)),
          const SizedBox(height: 12),
          TextField(controller: _name, style: big, decoration: InputDecoration(labelText: tr('yourName', lang), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _saathiName, style: big, decoration: InputDecoration(labelText: tr('saathiName', lang), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: _saathiPhone,
            style: big,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('saathiPhone', lang), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton(onPressed: _saveSaathi, style: FilledButton.styleFrom(minimumSize: const Size(0, 52)), child: Text(tr('save', lang), style: big))),
            if (c.settings.saathi != null) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  c.saveSaathi(null);
                  _saathiName.clear();
                  _saathiPhone.clear();
                  setState(() {});
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                child: Text(tr('remove', lang), style: big),
              ),
            ],
          ]),
          if (c.apiBase != null) ...[
            const SizedBox(height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('reportingSwitch', lang), style: big),
              subtitle: Text(tr('reportingHelp', lang)),
              value: c.settings.reportingEnabled,
              onChanged: (v) {
                c.setReportingEnabled(v);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _district,
              style: big,
              decoration: InputDecoration(labelText: tr('district', lang), border: const OutlineInputBorder()),
              onChanged: (v) => c.settings.district = v,
            ),
          ],
        ]),
      ),
    );
  }
}
