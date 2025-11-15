import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'tips_page.dart';
import 'badges_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications only on Android (do NOT run on Linux)
  // Guard against web where `Platform` getters are not supported in DDC.
  if (!kIsWeb && Platform.isAndroid) {
    await NotificationService().init();
  }

  runApp(const WaterReminderApp());
}

class WaterReminderApp extends StatefulWidget {
  const WaterReminderApp({super.key});

  @override
  State<WaterReminderApp> createState() => _WaterReminderAppState();
}

class _WaterReminderAppState extends State<WaterReminderApp> {
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dark = prefs.getBool('darkMode') ?? false;
    });
  }

  void _onSettingsChanged() => _loadTheme();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Reminder',
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(onSettingsChanged: _onSettingsChanged),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  const HomePage({super.key, this.onSettingsChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _goal = 8;
  int _count = 0;
  int _streak = 0;
  late SharedPreferences _prefs;
  Map<String, int> _history = {};
  bool _soundEnabled = true;
  bool _achieved7 = false;
  bool _achieved30 = false;
  late ConfettiController _confettiController;

  // undo state (single-step)
  int? _lastCountBefore;
  bool _canUndo = false;

  // animation
  double _scale = 1.0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _controller.addListener(() {
      setState(() {
        _scale = 1.0 + _controller.value * 0.08;
      });
    });
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadState();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleNewDayIfNeeded();
    }
  }

  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = _prefs.getInt('dailyCount') ?? 0;
      _streak = _prefs.getInt('streak') ?? 0;
      final hist = _prefs.getString('history') ?? '{}';
      try {
        final decoded = jsonDecode(hist) as Map<String, dynamic>;
        _history = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {
        _history = {};
      }
      _lastCountBefore = _prefs.getInt('lastCountBefore');
      _canUndo = _prefs.getBool('canUndo') ?? false;
      _goal = _prefs.getInt('dailyGoal') ?? 8;
      _soundEnabled = _prefs.getBool('soundEnabled') ?? true;
      _achieved7 = _prefs.getBool('achieved_7') ?? false;
      _achieved30 = _prefs.getBool('achieved_30') ?? false;
    });

    // schedule or cancel reminders according to settings
    final reminders = _prefs.getBool('reminders') ?? true;
    final interval = _prefs.getString('reminderInterval') ?? 'hourly';
    if (!kIsWeb && Platform.isAndroid) {
      if (reminders && interval == 'hourly') {
        await NotificationService().scheduleHourlyReminder();
      } else {
        await NotificationService().cancelHourlyReminder();
      }
    }

    await _handleNewDayIfNeeded();
  }

  String _todayKey() {
    final now = DateTime.now();
    return _formatDateKey(now);
  }

  String _formatDateKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _handleNewDayIfNeeded() async {
    final last = _prefs.getString('lastDate');
    final today = _todayKey();
    if (last == null) {
      await _prefs.setString('lastDate', today);
      return;
    }

    if (last != today) {
      // Move last day's count to history
      final lastCount = _prefs.getInt('dailyCount') ?? 0;
      if (lastCount > 0) {
        _history[last] = lastCount;
      }

      // Update streak: if last day's count >= goal then increment, else reset
      final prevDayKey = last;
      final prevCount = _history[prevDayKey] ?? 0;
      if (prevCount >= _goal) {
        _streak = (_prefs.getInt('streak') ?? 0) + 1;
      } else {
        _streak = 0;
      }

      // Reset today's count
      _count = 0;
      await _prefs.setInt('dailyCount', _count);
      await _prefs.setInt('streak', _streak);
      await _prefs.setBool('goalReachedToday', false);
      await _prefs.setString('history', jsonEncode(_history));
      await _prefs.setString('lastDate', today);

      setState(() {});
    }
  }

  Future<void> _increment() async {
    // preserve undo state (single-step)
    _lastCountBefore = _count;
    _canUndo = true;
    await _prefs.setInt('lastCountBefore', _lastCountBefore!);
    await _prefs.setBool('canUndo', true);

    // play click sound
    if (_soundEnabled) SystemSound.play(SystemSoundType.click);

    // scale animation
    _controller.forward(from: 0).then((_) => _controller.reverse());

    setState(() {
      _count++;
      if (_count < 0) _count = 0;
    });

    await _prefs.setInt('dailyCount', _count);
    await _prefs.setString('lastDate', _todayKey());

    // instant notification (only on Android)
    if (!kIsWeb && Platform.isAndroid) {
      await NotificationService().showInstantNotification();
    }

    // If reached goal, mark for streak if not already
    if (_count >= _goal) {
      if ((_prefs.getBool('goalReachedToday') ?? false) == false) {
        await _prefs.setBool('goalReachedToday', true);
        _streak = (_prefs.getInt('streak') ?? 0) + 1;
        await _prefs.setInt('streak', _streak);
        setState(() {});
        // Check achievements when streak changes
        await _checkAchievements(_streak);
      }
    }
  }

  Future<void> _checkAchievements(int streak) async {
    try {
      final achieved7 = _prefs.getBool('achieved_7') ?? false;
      final achieved30 = _prefs.getBool('achieved_30') ?? false;
      if (streak >= 7 && !achieved7) {
        await _prefs.setBool('achieved_7', true);
        await _prefs.setString('achieved_7_date', DateTime.now().toIso8601String());
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Achievement!'),
              content: const Text('7-day streak reached — great job! You earned a Bronze Hydrator badge.'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Nice'))],
            ),
          );
          _confettiController.play();
        }
      }
      if (streak >= 30 && !achieved30) {
        await _prefs.setBool('achieved_30', true);
        await _prefs.setString('achieved_30_date', DateTime.now().toIso8601String());
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Achievement!'),
              content: const Text('30-day streak reached — amazing! You earned a Gold Hydrator badge.'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Awesome'))],
            ),
          );
          _confettiController.play();
        }
      }
    } catch (_) {}
  }

  void _openHistory() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoryPage(history: _history, todayCount: _count, goal: _goal)));
    await _loadState();
  }

  Future<void> _undo() async {
    if (!_canUndo || _lastCountBefore == null) return;
    setState(() {
      _count = _lastCountBefore!;
      _canUndo = false;
      _lastCountBefore = null;
    });
    await _prefs.setInt('dailyCount', _count);
    await _prefs.remove('lastCountBefore');
    await _prefs.setBool('canUndo', false);
  }

  Future<void> _resetToday() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset today?'),
        content: const Text('This will reset today\'s count to zero. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _count = 0;
      _canUndo = false;
      _lastCountBefore = null;
    });
    await _prefs.setInt('dailyCount', 0);
    await _prefs.setBool('goalReachedToday', false);
    await _prefs.remove('lastCountBefore');
    await _prefs.setBool('canUndo', false);
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_goal > 0) ? (_count / _goal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFB3E5FC)],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Water Reminder', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                                  IconButton(
                                    icon: const Icon(Icons.settings),
                                    onPressed: _openSettings,
                                    tooltip: 'Settings',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.emoji_events),
                                    onPressed: () async {
                                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesPage()));
                                      await _loadState();
                                    },
                                    tooltip: 'Badges',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.history_rounded),
                                    onPressed: _openHistory,
                                    tooltip: 'Weekly history',
                                  ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const TipsWidget(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              height: 220,
                              child: CircularProgressIndicator(
                                value: percent,
                                strokeWidth: 14,
                                backgroundColor: Color.fromRGBO(255, 255, 255, 0.6),
                                valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$_count / $_goal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('glasses', style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedScale(
                        scale: _scale,
                        duration: const Duration(milliseconds: 120),
                        child: GestureDetector(
                          onTap: _increment,
                          child: Container(
                            width: 260,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [BoxShadow(color: Color.fromRGBO(179, 229, 252, 0.4), blurRadius: 12, offset: const Offset(0, 6))],
                            ),
                            child: Center(
                              child: Text('I drank water', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Streak: $_streak days', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _canUndo ? _undo : null,
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Undo'),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _resetToday,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset Today'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Earned badges (quick glance)
                      Wrap(
                        spacing: 8,
                        children: [
                          if (_achieved7)
                            Chip(
                              avatar: const Icon(Icons.star, color: Colors.white, size: 18),
                              label: const Text('Bronze Hydrator'),
                              backgroundColor: const Color(0xFF8B5A2B),
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                          if (_achieved30)
                            Chip(
                              avatar: const Icon(Icons.emoji_events, color: Colors.white, size: 18),
                              label: const Text('Gold Hydrator'),
                              backgroundColor: const Color(0xFFFFD700),
                              labelStyle: const TextStyle(color: Colors.black87),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Confetti overlay (top of UI)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    emissionFrequency: 0.05,
                    numberOfParticles: 20,
                    gravity: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings() async {
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
    if (res == true) {
      widget.onSettingsChanged?.call();
    }
    await _loadState();
  }
}
