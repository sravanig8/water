import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  String? _achieved7Date;
  String? _achieved30Date;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _achieved7Date = prefs.getString('achieved_7_date');
      _achieved30Date = prefs.getString('achieved_30_date');
    });
  }

  Widget _badgeTile(BuildContext context, String title, String desc, String? date, IconData icon, Color color) {
    final earned = date != null;
    final parsed = date != null ? DateTime.tryParse(date) : null;
    final subtitle = earned
      ? 'Earned: ${parsed != null ? parsed.toLocal().toString().split('.').first : date}'
      : 'Locked';
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
      title: Text(title),
      subtitle: Text('$desc\n$subtitle'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (earned)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Copy achievement text',
              onPressed: () {
                final text = '$title — $desc\nEarned: ${parsed != null ? parsed.toLocal().toString().split('.').first : date}';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Achievement copied to clipboard')));
              },
            ),
          earned ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.lock_outline),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _badgeTile(context, 'Bronze Hydrator', 'Reach a 7-day streak', _achieved7Date, Icons.star_border, Colors.brown),
          const SizedBox(height: 12),
          _badgeTile(context, 'Gold Hydrator', 'Reach a 30-day streak', _achieved30Date, Icons.emoji_events, Colors.amber),
        ],
      ),
    );
  }
}
