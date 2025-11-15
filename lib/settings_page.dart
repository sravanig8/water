import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
 
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SharedPreferences _prefs;
  int _goal = 8;
  bool _reminders = true;
  String _interval = 'hourly'; // 'off','hourly','daily'
  bool _sound = true;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _goal = _prefs.getInt('dailyGoal') ?? 8;
      _reminders = _prefs.getBool('reminders') ?? true;
      _interval = _prefs.getString('reminderInterval') ?? 'hourly';
      _sound = _prefs.getBool('soundEnabled') ?? true;
      _dark = _prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _save() async {
    await _prefs.setInt('dailyGoal', _goal);
    await _prefs.setBool('reminders', _reminders);
    await _prefs.setString('reminderInterval', _interval);
    await _prefs.setBool('soundEnabled', _sound);
    await _prefs.setBool('darkMode', _dark);
  }

  Future<void> _showExportDialog() async {
    final data = <String, dynamic>{};
    data['dailyCount'] = _prefs.getInt('dailyCount') ?? 0;
    data['streak'] = _prefs.getInt('streak') ?? 0;
    data['lastDate'] = _prefs.getString('lastDate');
    data['history'] = jsonDecode(_prefs.getString('history') ?? '{}');
    final payload = const JsonEncoder.withIndent('  ').convert(data);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export data'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(payload)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.of(ctx);
              // copy to clipboard, don't await using ctx after async gap
              Clipboard.setData(ClipboardData(text: payload));
              nav.pop();
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import data (paste JSON below)'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(hintText: '{ "history": {...} }'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Import')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final Map<String, dynamic> parsed = jsonDecode(controller.text) as Map<String, dynamic>;
      // Validate and apply
      if (parsed.containsKey('history')) {
        final hist = parsed['history'];
        await _prefs.setString('history', jsonEncode(hist));
      }
      if (parsed.containsKey('dailyCount')) await _prefs.setInt('dailyCount', (parsed['dailyCount'] as num).toInt());
      if (parsed.containsKey('streak')) await _prefs.setInt('streak', (parsed['streak'] as num).toInt());
      if (parsed.containsKey('lastDate')) {
        final ld = parsed['lastDate'];
        if (ld != null) await _prefs.setString('lastDate', ld.toString());
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(const SnackBar(content: Text('Import successful')));
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                const Text('Daily goal:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 20,
                    divisions: 19,
                    value: _goal.toDouble(),
                    label: '$_goal',
                    onChanged: (v) => setState(() => _goal = v.toInt()),
                    onChangeEnd: (_) => _save(),
                  ),
                ),
                Text('$_goal'),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Enable reminders'),
              value: _reminders,
              onChanged: (v) { setState(() => _reminders = v); _save(); },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Reminder interval'),
              subtitle: Text(_interval),
              trailing: DropdownButton<String>(
                value: _interval,
                items: const [
                  DropdownMenuItem(value: 'off', child: Text('Off')),
                  DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                ],
                onChanged: (v) { if (v!=null) setState(() { _interval=v; _save(); }); },
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Play click sound'),
              value: _sound,
              onChanged: (v) { setState(() => _sound = v); _save(); },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Dark theme'),
              value: _dark,
              onChanged: (v) { setState(() => _dark = v); _save(); },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save and apply'),
              onPressed: () async {
                final nav = Navigator.of(context);
                await _save();
                nav.pop(true);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Export / Import'),
              subtitle: const Text('Export your history as JSON or paste JSON to import'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'export') await _showExportDialog();
                  if (v == 'import') await _showImportDialog();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'export', child: Text('Export')),
                  PopupMenuItem(value: 'import', child: Text('Import')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Reminder importance'),
              subtitle: const Text('Choose how intrusive reminder notifications are'),
              trailing: DropdownButton<String>(
                value: _prefs.getString('reminderImportance') ?? 'default',
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'default', child: Text('Default')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await _prefs.setString('reminderImportance', v);
                  // update channel importance immediately
                  NotificationService().setReminderImportance(v);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Notification permissions'),
              subtitle: const Text('Request Android notification permission (Android 13+)'),
              trailing: ElevatedButton(
                child: const Text('Request'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final granted = await NotificationService().requestPermission();
                  if (mounted) {
                    messenger.showSnackBar(SnackBar(content: Text(granted ? 'Permission granted' : 'Permission denied')));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
