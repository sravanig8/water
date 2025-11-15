import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      if (!Platform.isAndroid) {
        // Only initialize on Android as requested (do NOT run on Linux)
        return;
      }

      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings settings = InitializationSettings(
        android: androidInit,
      );

      await _plugin.initialize(settings);

      // Create channels for reminders and confirmations
      final AndroidNotificationChannel reminderChannel = const AndroidNotificationChannel(
        'water_reminder_channel',
        'Water Reminders',
        description: 'Hourly water reminders',
        importance: Importance.defaultImportance,
      );

      final AndroidNotificationChannel confirmChannel = const AndroidNotificationChannel(
        'water_confirm_channel',
        'Confirmations',
        description: 'Instant confirmations when you log water',
        importance: Importance.high,
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(reminderChannel);
      await androidImpl?.createNotificationChannel(confirmChannel);
      // Request notification permission on Android 13+
      await _requestAndroidNotificationPermissionIfNeeded();
    } catch (e) {
      if (kDebugMode) print('Notification init error: $e');
    }
  }

  Future<bool> _requestAndroidNotificationPermissionIfNeeded() async {
    try {
      if (!Platform.isAndroid) return true;
      // Android 13+ requires POST_NOTIFICATIONS at runtime
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) print('Permission request error: $e');
      return false;
    }
  }

  /// Public request for notification permission. Returns true if granted.
  Future<bool> requestPermission() async {
    try {
      if (!Platform.isAndroid) return true;
      return await _requestAndroidNotificationPermissionIfNeeded();
    } catch (e) {
      if (kDebugMode) print('requestPermission error: $e');
      return false;
    }
  }

  /// Update the reminder channel importance. Valid values: 'low','default','high'
  Future<void> setReminderImportance(String importance) async {
    try {
      if (!Platform.isAndroid) return;
      final impl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      Importance imp = Importance.defaultImportance;
      if (importance == 'low') imp = Importance.low;
      if (importance == 'high') imp = Importance.high;

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'water_reminder_channel',
        'Water Reminders',
        description: 'Hourly water reminders',
        importance: imp,
      );
      await impl?.createNotificationChannel(channel);
    } catch (e) {
      if (kDebugMode) print('setReminderImportance error: $e');
    }
  }

  Future<void> scheduleHourlyReminder() async {
    try {
      if (!Platform.isAndroid) return;

      await _plugin.periodicallyShow(
        1001,
        'Time to drink water 💧',
        'Time to drink water 💧',
        RepeatInterval.hourly,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_reminder_channel',
            'Water Reminders',
            channelDescription: 'Hourly water reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidAllowWhileIdle: true,
      );
    } catch (e) {
      if (kDebugMode) print('Schedule error: $e');
    }
  }

  Future<void> cancelHourlyReminder() async {
    try {
      await _plugin.cancel(1001);
    } catch (e) {
      if (kDebugMode) print('Cancel reminder error: $e');
    }
  }

  Future<void> showInstantNotification() async {
    try {
      if (!Platform.isAndroid) return;

      await _plugin.show(
        1002,
        'Nice! 💙 You just logged a glass of water',
        null,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_confirm_channel',
            'Confirmations',
            channelDescription: 'Instant confirmations',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Instant notify error: $e');
    }
  }
}
