import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
      settings:
          const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'dose_reminders',
        'Dose Reminders',
        description: 'Reminds you when a peptide dose is due',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'alerts',
        'Alerts',
        description: 'Low stock, depletion, and missed dose alerts',
        importance: Importance.defaultImportance,
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

  NotificationDetails get _reminderDetails => const NotificationDetails(
        android: AndroidNotificationDetails('dose_reminders', 'Dose Reminders',
            importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails get _alertDetails => const NotificationDetails(
        android: AndroidNotificationDetails('alerts', 'Alerts',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority),
        iOS: DarwinNotificationDetails(),
      );

  Future<String?> scheduleDoseReminder(Device device) async {
    if (!_initialized) return null;
    final hour = scheduleHour(device.schedule);
    final anchorDate = scheduleAnchorDate(device);
    final ids = <int>[];

    try {
      switch (device.schedule) {
        case DoseSchedule.dailyAm:
        case DoseSchedule.dailyPm:
          final id = _reminderIdFor(device.id, 0);
          await _zonedScheduleWithFallback(
            id: id,
            title: 'Time for your ${device.name} dose',
            body: '${device.desiredDoseMcg.toStringAsFixed(0)}mcg'
                ' (${device.doseVolumeIu.toStringAsFixed(1)} IU) — open Pep Tracker Pro to log',
            when: _nextInstanceOnOrAfter(hour, 0, anchorDate),
            matchDateTimeComponents: DateTimeComponents.time,
          );
          ids.add(id);
          break;
        case DoseSchedule.custom:
        case DoseSchedule.onceWeekly:
        case DoseSchedule.twiceWeekly:
          final days = effectiveScheduleDays(device);
          if (days.isEmpty) break;
          for (final weekday in days) {
            final id = _reminderIdFor(device.id, weekday);
            await _zonedScheduleWithFallback(
              id: id,
              title: 'Time for your ${device.name} dose',
              body:
                  '${device.desiredDoseMcg.toStringAsFixed(0)}mcg — open Pep Tracker Pro to log',
              when: _nextWeekdayInstanceOnOrAfter(hour, 0, weekday, anchorDate),
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
            ids.add(id);
          }
          break;
        case DoseSchedule.everyOtherDay:
          final id = _reminderIdFor(device.id, 99);
          await _zonedScheduleWithFallback(
            id: id,
            title: 'Time for your ${device.name} dose',
            body:
                '${device.desiredDoseMcg.toStringAsFixed(0)}mcg — open Pep Tracker Pro to log',
            when: _nextEveryOtherDayInstance(device, hour, 0, anchorDate),
          );
          ids.add(id);
          break;
      }
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
      return null;
    }
    if (ids.isEmpty) return null;
    return ids.join(',');
  }

  Future<void> cancelReminder(String notificationId) async {
    final ids = notificationId
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>();
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  Future<void> showLowStockAlert(Device device) async {
    if (!_initialized) return;
    final id = (device.id.hashCode.abs() + 50000) % 100000;
    await _plugin.show(
      id: id,
      title: '${device.name} is running low',
      body:
          'Only ${device.remainingDoses} dose${device.remainingDoses != 1 ? "s" : ""} remaining',
      notificationDetails: _alertDetails,
    );
  }

  Future<void> showDepletionAlert(Device device) async {
    if (!_initialized) return;
    final id = (device.id.hashCode.abs() + 60000) % 100000;
    await _plugin.show(
      id: id,
      title: '${device.name} is depleted',
      body: 'All doses used. Time to reorder and reconstitute.',
      notificationDetails: _alertDetails,
    );
  }

  Future<void> showMissedDoseAlert(Device device) async {
    if (!_initialized) return;
    final id = (device.id.hashCode.abs() + 70000) % 100000;
    await _plugin.show(
      id: id,
      title: 'Missed dose: ${device.name}',
      body: 'You didn\'t log a dose yesterday. Check your schedule.',
      notificationDetails: _alertDetails,
    );
  }

  tz.TZDateTime _nextInstanceOnOrAfter(int hour, int minute, DateTime minDate) {
    final now = tz.TZDateTime.now(tz.local);
    final minDay = DateTime(minDate.year, minDate.month, minDate.day);
    final nowDay = DateTime(now.year, now.month, now.day);
    final baseDay = nowDay.isAfter(minDay) ? nowDay : minDay;
    var scheduled = tz.TZDateTime(
        tz.local, baseDay.year, baseDay.month, baseDay.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextWeekdayInstanceOnOrAfter(
      int hour, int minute, int weekday, DateTime minDate) {
    var scheduled = _nextInstanceOnOrAfter(hour, minute, minDate);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextEveryOtherDayInstance(
      Device device, int hour, int minute, DateTime minDate) {
    final now = tz.TZDateTime.now(tz.local);
    final minDay = DateTime(minDate.year, minDate.month, minDate.day);
    final nowDay = DateTime(now.year, now.month, now.day);
    final baseDay = nowDay.isAfter(minDay) ? nowDay : minDay;
    var date = tz.TZDateTime(
        tz.local, baseDay.year, baseDay.month, baseDay.day, hour, minute);
    if (date.isBefore(now)) {
      date = date.add(const Duration(days: 1));
    }
    int guard = 0;
    while (
        !isScheduledOnDate(device, DateTime(date.year, date.month, date.day)) &&
            guard < 14) {
      date = date.add(const Duration(days: 1));
      guard++;
    }
    return date;
  }

  int _reminderIdFor(String deviceId, int offset) {
    final base = deviceId.hashCode.abs();
    final raw = base + (offset * 1000003);
    // Keep IDs in 32-bit signed range for platform notification APIs.
    return raw % 2147483647;
  }

  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      debugPrint(
          'Exact alarms not permitted; using inexact scheduling fallback.');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }
  }
}
