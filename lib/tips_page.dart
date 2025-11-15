import 'package:flutter/material.dart';

class TipsWidget extends StatefulWidget {
  const TipsWidget({super.key});

  @override
  State<TipsWidget> createState() => _TipsWidgetState();
}

class _TipsWidgetState extends State<TipsWidget> {
  final List<String> _tips = const [
    'Start your day with a glass of water to kickstart hydration.',
    'Keep a reusable bottle nearby to remind you to sip frequently.',
    'Add fruit slices for a refreshing flavor boost without sugar.',
    'Break large goals into small sips — try a glass every hour.',
    'Set gentle reminders rather than forcing big intakes at once.',
    'Hydrate before meals to help digestion and reduce overeating.',
    'Drink water after exercise to replace fluids and recover faster.',
  ];

  int _index = DateTime.now().day % 7;

  void _next() {
    setState(() {
      _index = (_index + 1) % _tips.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Expanded(child: Text(_tips[_index], style: Theme.of(context).textTheme.bodyLarge)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Next tip',
              onPressed: _next,
            )
          ],
        ),
      ),
    );
  }
}
