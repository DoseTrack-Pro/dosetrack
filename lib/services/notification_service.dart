import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/device.dart';
import '../utils/calculations.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'dose_reminders',
            'Dose Reminders',
            description: 'Reminds you when a peptide dose is due',
            importance: Importance.high,
          ));
    }

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    if (Platform.isAndroid) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_reminders',
          'Dose Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<String?> scheduleDoseReminder(Device device) async {
    if (!_initialized) return null;

    final hour = scheduleHour(device.schedule);
    final id = device.id.hashCode.abs() % 100000;

    try {
      switch (device.schedule) {
        case DoseSchedule.dailyAm:
        case DoseSchedule.dailyPm:
          await _plugin.zonedSchedule(
            id,
            'Time for your ${device.name} dose',
            '${device.desiredDoseMcg.toStringAsFixed(0)}mcg'
                ' (${device.doseVolumeIu.toStringAsFixed(0)} IU)'
                ' — open PeptideTrack to log',
            _nextInstance(hour, 0),
            _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          break;

        case DoseSchedule.onceWeekly:
        case DoseSchedule.twiceWeekly:
          await _plugin.zonedSchedule(
            id,
            'Time for your ${device.name} dose',
            '${device.desiredDoseMcg.toStringAsFixed(0)}mcg'
                ' — open PeptideTrack to log',
            _nextInstance(hour, 0),
            _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
      return null;
    }

    return id.toString();
  }

  Future<void> cancelReminder(String notificationId) async {
    await _plugin.cancel(int.parse(notificationId));
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  Future<void> showLowStockAlert(Device device) async {
    if (!_initialized) return;
    final id = (device.id.hashCode.abs() + 50000) % 100000;
    await _plugin.show(
      id,
      '${device.name} is running low',
      'Only ${device.remainingDoses} dose'
          '${device.remainingDoses != 1 ? "s" : ""} remaining',
      _details,
    );
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
