import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/dose_log.dart';

// ── Dose math ──────────────────────────────────────────────────

/// dose (IU) = (desiredMcg / (peptideMg × 1000)) × reconMl × 100
double calcDoseIu(double peptideMg, double reconVolumeMl, double desiredDoseMcg) {
  if (peptideMg <= 0) return 0;
  return ((desiredDoseMcg / (peptideMg * 1000)) * reconVolumeMl * 100).roundToDouble();
}

/// total doses = floor( (reconMl × 100) / doseIU )
int calcTotalDoses(double reconVolumeMl, double doseVolumeIu) {
  if (doseVolumeIu <= 0) return 0;
  return ((reconVolumeMl * 100) / doseVolumeIu).floor();
}

// ── Schedule helpers ───────────────────────────────────────────

int scheduleHour(DoseSchedule schedule) =>
    schedule == DoseSchedule.dailyPm ? 18 : 8;

bool isDueToday(Device device, List<DoseLog> logs) {
  final today = DateTime.now();
  final todayLogs = logs.where((l) =>
    l.deviceId == device.id &&
    l.loggedAt.year == today.year &&
    l.loggedAt.month == today.month &&
    l.loggedAt.day == today.day,
  ).toList();

  switch (device.schedule) {
    case DoseSchedule.dailyAm:
    case DoseSchedule.dailyPm:
      return todayLogs.isEmpty;
    case DoseSchedule.everyOtherDay:
      final diff = today.difference(device.createdAt).inDays;
      return diff % 2 == 0 && todayLogs.isEmpty;
    case DoseSchedule.twiceWeekly:
      return (today.weekday == 1 || today.weekday == 4) && todayLogs.isEmpty;
    case DoseSchedule.onceWeekly:
      return today.weekday == 1 && todayLogs.isEmpty;
    case DoseSchedule.custom:
      return false;
  }
}

// ── Analytics ──────────────────────────────────────────────────

List<DateTime> getLast14Days() {
  return List.generate(
    14,
    (i) => DateTime.now().subtract(Duration(days: 13 - i)),
  );
}

int calcAdherence(List<Device> activeDevices, List<DoseLog> logs) {
  if (activeDevices.isEmpty) return 0;
  final dailyDevices = activeDevices.where((d) =>
    d.schedule == DoseSchedule.dailyAm || d.schedule == DoseSchedule.dailyPm,
  ).toList();
  if (dailyDevices.isEmpty) return 100;

  int expected = 0, actual = 0;
  for (int i = 0; i < 14; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    for (final device in dailyDevices) {
      expected++;
      final hasLog = logs.any((l) =>
        l.deviceId == device.id &&
        l.loggedAt.year == date.year &&
        l.loggedAt.month == date.month &&
        l.loggedAt.day == date.day,
      );
      if (hasLog) actual++;
    }
  }
  if (expected == 0) return 0;
  return ((actual / expected) * 100).round();
}

int calcStreak(List<DoseLog> logs) {
  int streak = 0;
  DateTime date = DateTime.now();
  while (true) {
    final hasLog = logs.any((l) =>
      l.loggedAt.year == date.year &&
      l.loggedAt.month == date.month &&
      l.loggedAt.day == date.day,
    );
    if (!hasLog) break;
    streak++;
    date = date.subtract(const Duration(days: 1));
  }
  return streak;
}

// ── Date formatting ────────────────────────────────────────────

String formatLogDate(DateTime dt) {
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
    return 'Yesterday';
  }
  return DateFormat('MMM d').format(dt);
}

String formatLogTime(DateTime dt) => DateFormat('h:mm a').format(dt);

String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
