import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/dose_log.dart';

// ── Dose math ──────────────────────────────────────────────────

/// dose (IU) = (desiredMcg / (peptideMg × 1000)) × reconMl × 100
double calcDoseIu(
    double peptideMg, double reconVolumeMl, double desiredDoseMcg) {
  if (peptideMg <= 0) return 0;
  return ((desiredDoseMcg / (peptideMg * 1000)) * reconVolumeMl * 100)
      .roundToDouble();
}

/// Reverse of calcDoseIu — derives mcg from a known IU volume.
double calcDoseMcg(double peptideMg, double reconVolumeMl, double doseIu) {
  if (reconVolumeMl <= 0) return 0;
  return doseIu * peptideMg * 1000 / (reconVolumeMl * 100);
}

/// total doses = floor( (reconMl × 100) / doseIU )
int calcTotalDoses(double reconVolumeMl, double doseVolumeIu) {
  if (doseVolumeIu <= 0) return 0;
  return ((reconVolumeMl * 100) / doseVolumeIu).floor();
}

/// BAC water (mL) needed to achieve targetDoses doses at desiredDoseMcg
/// from a vial containing peptideMg of peptide.
double calcReconVolume(
    double peptideMg, double desiredDoseMcg, int targetDoses) {
  if (peptideMg <= 0 || desiredDoseMcg <= 0 || targetDoses <= 0) return 0;
  final doseIu =
      desiredDoseMcg / (peptideMg * 1000) * 100; // IU per dose at 1mL
  return (targetDoses * doseIu) / 100;
}

// ── Schedule helpers ───────────────────────────────────────────

int scheduleHour(DoseSchedule schedule) =>
    schedule == DoseSchedule.dailyPm ? 18 : 8;

/// Returns the effective scheduled weekdays for a device.
/// For twiceWeekly defaults to [1, 4] (Mon, Thu).
/// For onceWeekly defaults to [1] (Mon).
/// For custom, uses scheduleDays or empty list.
List<int> effectiveScheduleDays(Device device) {
  switch (device.schedule) {
    case DoseSchedule.twiceWeekly:
      return device.scheduleDays ?? [1, 4];
    case DoseSchedule.onceWeekly:
      return device.scheduleDays ?? [1];
    case DoseSchedule.custom:
      return device.scheduleDays ?? [];
    default:
      return [];
  }
}

DateTime scheduleAnchorDate(Device device) {
  final parsed = DateTime.tryParse(device.scheduleStartDate ?? '');
  if (parsed != null) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
  return DateTime(
    device.createdAt.year,
    device.createdAt.month,
    device.createdAt.day,
  );
}

/// Whether [date] is a scheduled dose day for [device].
bool isScheduledOnDate(Device device, DateTime date) {
  // Never count a device before its schedule start date.
  final scheduleDate = DateTime(date.year, date.month, date.day);
  final startDate = scheduleAnchorDate(device);
  if (scheduleDate.isBefore(startDate)) return false;

  switch (device.schedule) {
    case DoseSchedule.dailyAm:
    case DoseSchedule.dailyPm:
      return true;
    case DoseSchedule.everyOtherDay:
      return scheduleDate.difference(startDate).inDays % 2 == 0;
    case DoseSchedule.twiceWeekly:
    case DoseSchedule.onceWeekly:
    case DoseSchedule.custom:
      final days = effectiveScheduleDays(device);
      return days.contains(date.weekday);
  }
}

/// Whether today is a scheduled dose day for this device.
bool isScheduledToday(Device device) =>
    isScheduledOnDate(device, DateTime.now());

bool isDueToday(Device device, List<DoseLog> logs) {
  if (!isScheduledToday(device)) return false;
  final today = DateTime.now();
  return !logs.any(
    (l) =>
        l.deviceId == device.id &&
        l.loggedAt.year == today.year &&
        l.loggedAt.month == today.month &&
        l.loggedAt.day == today.day,
  );
}

// ── Expiry ─────────────────────────────────────────────────────

int daysUntilExpiry(Device device) {
  final reconDate = DateTime.tryParse(device.reconstitutionDate);
  if (reconDate == null) return 999;
  final expiry = reconDate.add(Duration(days: device.expiryDays));
  return expiry.difference(DateTime.now()).inDays;
}

bool isExpired(Device device) => daysUntilExpiry(device) < 0;

// ── Analytics ──────────────────────────────────────────────────

List<DateTime> getLast14Days() {
  return List.generate(
    14,
    (i) => DateTime.now().subtract(Duration(days: 13 - i)),
  );
}

int calcAdherence(List<Device> activeDevices, List<DoseLog> logs) {
  return calcAdherenceForDays(activeDevices, logs, 14);
}

int calcAdherenceForDays(
    List<Device> activeDevices, List<DoseLog> logs, int days) {
  if (activeDevices.isEmpty) return 0;
  if (days <= 0) return 0;
  final scheduledDevices = activeDevices
      .where(
        (d) =>
            d.schedule != DoseSchedule.custom ||
            effectiveScheduleDays(d).isNotEmpty,
      )
      .toList();
  if (scheduledDevices.isEmpty) return 100;

  int expected = 0, actual = 0;
  for (int i = 0; i < days; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    for (final device in scheduledDevices) {
      if (!isScheduledOnDate(device, date)) continue;
      expected++;
      final hasLog = logs.any(
        (l) =>
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
    final hasLog = logs.any(
      (l) =>
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

int calcDeviceAdherence(Device device, List<DoseLog> logs) {
  return calcDeviceAdherenceForDays(device, logs, 14);
}

int calcDeviceAdherenceForDays(Device device, List<DoseLog> logs, int days) {
  if (days <= 0) return -1;
  final deviceLogs = logs.where((l) => l.deviceId == device.id).toList();
  int expected = 0, actual = 0;

  for (int i = 0; i < days; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    if (!isScheduledOnDate(device, date)) continue;

    expected++;
    final hasLog = deviceLogs.any(
      (l) =>
          l.loggedAt.year == date.year &&
          l.loggedAt.month == date.month &&
          l.loggedAt.day == date.day,
    );
    if (hasLog) actual++;
  }

  if (expected == 0) return -1;
  return ((actual / expected) * 100).clamp(0, 100).round();
}

int calcMissedDosesForDays(
    List<Device> activeDevices, List<DoseLog> logs, int days) {
  if (days <= 0 || activeDevices.isEmpty) return 0;
  int expected = 0;
  int actual = 0;

  final scheduledDevices = activeDevices
      .where((d) =>
          d.schedule != DoseSchedule.custom ||
          effectiveScheduleDays(d).isNotEmpty)
      .toList();

  for (int i = 0; i < days; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    for (final device in scheduledDevices) {
      if (!isScheduledOnDate(device, date)) continue;
      expected++;
      final hasLog = logs.any((l) =>
          l.deviceId == device.id &&
          l.loggedAt.year == date.year &&
          l.loggedAt.month == date.month &&
          l.loggedAt.day == date.day);
      if (hasLog) actual++;
    }
  }
  return (expected - actual).clamp(0, 999999);
}

DateTime? calcProjectedDepletion(Device device, List<DoseLog> logs) {
  if (device.remainingDoses <= 0) return null;

  final deviceLogs = logs.where((l) => l.deviceId == device.id).toList();

  double dosesPerDay;

  if (deviceLogs.isNotEmpty) {
    final earliest = deviceLogs
        .map((l) => l.loggedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final daysSinceFirst = DateTime.now().difference(earliest).inDays + 1;
    dosesPerDay = deviceLogs.length / daysSinceFirst;
  } else {
    switch (device.schedule) {
      case DoseSchedule.dailyAm:
      case DoseSchedule.dailyPm:
        dosesPerDay = 1.0;
      case DoseSchedule.everyOtherDay:
        dosesPerDay = 0.5;
      case DoseSchedule.twiceWeekly:
        dosesPerDay = effectiveScheduleDays(device).length / 7;
      case DoseSchedule.onceWeekly:
        dosesPerDay = 1 / 7;
      case DoseSchedule.custom:
        final days = effectiveScheduleDays(device);
        if (days.isEmpty) return null;
        dosesPerDay = days.length / 7;
    }
  }

  if (dosesPerDay <= 0) return null;
  final daysLeft = (device.remainingDoses / dosesPerDay).round();
  return DateTime.now().add(Duration(days: daysLeft));
}

// ── Date formatting ────────────────────────────────────────────

String formatLogDate(DateTime dt) {
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day) {
    return 'Yesterday';
  }
  return DateFormat('MMM d').format(dt);
}

String formatLogTime(DateTime dt) => DateFormat('h:mm a').format(dt);

String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
