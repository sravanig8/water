import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  final Map<String, int> history;
  final int todayCount;
  final int goal;

  const HistoryPage({super.key, required this.history, required this.todayCount, required this.goal});

  List<MapEntry<String, int>> _last7Days(Map<String, int> history, int todayCount) {
    final now = DateTime.now();
    final List<MapEntry<String, int>> list = [];
    for (int i = 6; i >= 0; i--) {
      final dt = now.subtract(Duration(days: i));
      final key = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final count = (key == _formatDateKey(now)) ? todayCount : (history[key] ?? 0);
      list.add(MapEntry(key, count));
    }
    return list;
  }

  String _formatDateKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _displayDate(String key) {
    try {
      final parts = key.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final dt = DateTime(y, m, d);
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _last7Days(history, todayCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly History'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = days[index];
                  final dateLabel = _displayDate(entry.key);
                  final count = entry.value;
                  final progress = (goal > 0) ? (count / goal).clamp(0.0, 1.0) : 0.0;

                  return Row(
                    children: [
                      SizedBox(width: 72, child: Text(dateLabel, style: Theme.of(context).textTheme.bodyLarge)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(Colors.blue.shade600)),
                            const SizedBox(height: 6),
                            Text('$count glasses', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
