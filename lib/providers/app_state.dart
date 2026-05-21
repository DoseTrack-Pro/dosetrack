import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../models/protocol.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/nfc_service.dart';
import '../services/settings_service.dart';
import '../utils/calculations.dart';

// ── App State ──────────────────────────────────────────────────

class AppState {
  final List<Device> devices;
  final List<DoseLog> doseLogs;
  final List<Protocol> protocols;
  final Map<String, String> deviceProtocols; // deviceId → protocolId
  final String? toastMessage;
  final String? undoLogId;

  const AppState({
    this.devices = const [],
    this.doseLogs = const [],
    this.protocols = const [],
    this.deviceProtocols = const {},
    this.toastMessage,
    this.undoLogId,
  });

  List<Device> get activeDevices => devices.where((d) => d.active).toList();

  AppState copyWith({
    List<Device>? devices,
    List<DoseLog>? doseLogs,
    List<Protocol>? protocols,
    Map<String, String>? deviceProtocols,
    String? toastMessage,
    bool clearToast = false,
    String? undoLogId,
    bool clearUndo = false,
  }) {
    return AppState(
      devices: devices ?? this.devices,
      doseLogs: doseLogs ?? this.doseLogs,
      protocols: protocols ?? this.protocols,
      deviceProtocols: deviceProtocols ?? this.deviceProtocols,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      undoLogId: clearUndo ? null : (undoLogId ?? this.undoLogId),
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────

class AppNotifier extends Notifier<AppState> {
  static const _uuid = Uuid();
  static const _novoPenDoseAdjustmentFactor = 1.08;

  @override
  AppState build() => const AppState();

  Future<void> initialize() async {
    final devices = await DatabaseService.instance.getAllDevices();
    final logs = await DatabaseService.instance.getAllDoseLogs();
    final protocols = await DatabaseService.instance.getAllProtocols();
    final deviceProtocols =
        await DatabaseService.instance.getDeviceProtocolMap();
    state = state.copyWith(
      devices: devices,
      doseLogs: logs,
      protocols: protocols,
      deviceProtocols: deviceProtocols,
    );

    // Reconcile reminder schedule on launch/refresh to keep schedules trustworthy.
    await refreshDoseReminders();

    if (SettingsService.instance.missedDoseAlerts) {
      await _checkMissedDoses(devices, logs);
    }
  }

  Future<void> _checkMissedDoses(
      List<Device> devices, List<DoseLog> logs) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dayKey = formatDate(yesterday);
    for (final device in devices) {
      if (!device.active || device.remainingDoses <= 0) continue;
      if (!isScheduledOnDate(device, yesterday)) continue;
      final hadLog = logs.any(
        (l) =>
            l.deviceId == device.id &&
            l.loggedAt.year == yesterday.year &&
            l.loggedAt.month == yesterday.month &&
            l.loggedAt.day == yesterday.day,
      );
      if (!hadLog) {
        final lastAlerted =
            SettingsService.instance.lastMissedAlertDate(device.id);
        if (lastAlerted == dayKey) continue;
        NotificationService.instance
            .showMissedDoseAlert(device)
            .catchError((_) {});
        await SettingsService.instance
            .setLastMissedAlertDate(device.id, dayKey);
      }
    }
  }

  // ── Enroll ─────────────────────────────────────────────────

  Future<void> enrollDevice({
    required String name,
    required ContainerType type,
    required String vendor,
    required String batchNumber,
    String? coaUrl,
    required String reconstitutionDate,
    required double peptideMg,
    required double reconVolumeMl,
    required double desiredDoseMcg,
    bool isBlend = false,
    List<BlendComponent>? blendComponents,
    required DoseSchedule schedule,
    String? scheduleStartDate,
    List<int>? scheduleDays,
    required int alertThresholdPct,
    int? startingRemainingDoses,
    int expiryDays = 30,
    String? nfcTagId,
    NfcMode nfcMode = NfcMode.tag,
    int novoPenBaselineCount = 0,
    bool novoPenImportExistingHistory = false,
  }) async {
    final doseVolumeIu = nfcMode == NfcMode.novoPen
        ? calcNovoPenAdjustedDoseIu(peptideMg, reconVolumeMl, desiredDoseMcg)
        : calcDoseIu(peptideMg, reconVolumeMl, desiredDoseMcg);
    final totalDoses = calcTotalDoses(reconVolumeMl, doseVolumeIu);
    final seededRemaining = startingRemainingDoses ?? totalDoses;
    final remainingDoses =
        totalDoses > 0 ? seededRemaining.clamp(1, totalDoses).toInt() : 0;
    final id = _uuid.v4();
    final normalizedStartDate = scheduleStartDate?.trim().isNotEmpty == true
        ? scheduleStartDate!.trim()
        : formatDate(DateTime.now());

    var device = Device(
      id: id,
      name: name,
      type: type,
      vendor: vendor,
      batchNumber: batchNumber,
      coaUrl: coaUrl?.isEmpty == true ? null : coaUrl,
      reconstitutionDate: reconstitutionDate,
      peptideMg: peptideMg,
      reconVolumeMl: reconVolumeMl,
      desiredDoseMcg: desiredDoseMcg,
      doseVolumeIu: doseVolumeIu,
      totalDoses: totalDoses,
      remainingDoses: remainingDoses,
      isBlend: isBlend,
      blendComponents: blendComponents,
      schedule: schedule,
      scheduleStartDate: normalizedStartDate,
      scheduleDays: scheduleDays,
      expiryDays: expiryDays,
      nfcTagId: nfcTagId,
      nfcMode: nfcMode,
      alertThresholdPct: alertThresholdPct,
      active: true,
      createdAt: DateTime.now(),
    );

    if (SettingsService.instance.doseReminders) {
      try {
        final notifId =
            await NotificationService.instance.scheduleDoseReminder(device);
        if (notifId != null) device = device.copyWith(notificationId: notifId);
      } catch (_) {}
    } else {
      device = device.copyWith(clearNotificationId: true);
    }

    await DatabaseService.instance.insertDevice(device);
    if (nfcMode == NfcMode.novoPen && nfcTagId != null && nfcTagId.isNotEmpty) {
      await SettingsService.instance
          .setNovoPenImportExistingHistory(id, novoPenImportExistingHistory);

      final baseline = novoPenImportExistingHistory
          ? 0
          : novoPenBaselineCount.clamp(0, 1000000).toInt();
      await SettingsService.instance.setNovoPenImportedCount(id, baseline);

      if (!novoPenImportExistingHistory) {
        final serialCursor =
            SettingsService.instance.novoPenSerialImportedCount(nfcTagId);
        final nextSerialCursor =
            baseline > serialCursor ? baseline : serialCursor;
        await SettingsService.instance
            .setNovoPenSerialImportedCount(nfcTagId, nextSerialCursor);
      }
    }
    state = state.copyWith(devices: [device, ...state.devices]);
    showToast('${device.name} enrolled successfully');
  }

  Future<List<DoseLog>> importNovoPenDoses({
    required String deviceId,
    required NovoPenReading reading,
  }) async {
    final device = state.devices.firstWhere((d) => d.id == deviceId);
    if (device.remainingDoses <= 0) return const [];

    int remaining = device.remainingDoses;
    final imported = <DoseLog>[];

    final allDoses = List<NovoPenDose>.from(reading.doses);
    final totalDoseCount = allDoses.length;
    final importExistingHistory =
        SettingsService.instance.novoPenImportExistingHistory(deviceId);
    var previousImportedCount =
        SettingsService.instance.novoPenImportedCount(deviceId);
    final serialImportedCount =
        SettingsService.instance.novoPenSerialImportedCount(reading.serial);

    if (previousImportedCount == 0 && !importExistingHistory) {
      final historicalImports = state.doseLogs
          .where((l) => l.deviceId == deviceId && _isNovoPenImportNote(l.notes))
          .length;
      if (historicalImports > 0) {
        previousImportedCount =
            historicalImports.clamp(0, totalDoseCount).toInt();
      }
    }

    final baselineSource = importExistingHistory
        ? previousImportedCount
        : (previousImportedCount > serialImportedCount
            ? previousImportedCount
            : serialImportedCount);
    final clampedPrevious = baselineSource > totalDoseCount
        ? 0
        : baselineSource.clamp(0, totalDoseCount).toInt();
    // NovoPen dose list is newest-first. Import only the newly-added head items.
    final newDoseCount =
        (totalDoseCount - clampedPrevious).clamp(0, totalDoseCount);
    final candidateDoses = allDoses.take(newDoseCount.toInt()).toList();

    int consumed = 0;
    final importTimestamp = DateTime.now();
    for (final dose in candidateDoses) {
      if (remaining <= 0) break;
      consumed += 1;

      final doseIu = dose.units / 10.0;
      final doseMcg =
          calcDoseMcg(device.peptideMg, device.reconVolumeMl, doseIu) *
              _novoPenDoseAdjustmentFactor;
      final log = DoseLog(
        id: _uuid.v4(),
        deviceId: deviceId,
        loggedAt: importTimestamp,
        method: LogMethod.nfc,
        doseMcg: doseMcg,
        doseIu: doseIu,
        notes: 'Imported from NovoPen (${reading.serial}); auto-adjusted +8%',
      );

      await DatabaseService.instance.insertDoseLog(log);
      imported.add(log);
      remaining -= 1;
    }

    final nextImportedCount =
        (clampedPrevious + consumed).clamp(0, totalDoseCount);
    await SettingsService.instance
        .setNovoPenImportedCount(deviceId, nextImportedCount.toInt());
    final nextSerialImportedCount =
        serialImportedCount > nextImportedCount.toInt()
            ? serialImportedCount
            : nextImportedCount.toInt();
    await SettingsService.instance
        .setNovoPenSerialImportedCount(reading.serial, nextSerialImportedCount);

    if (imported.isEmpty) return const [];

    await DatabaseService.instance.updateRemainingDoses(deviceId, remaining);
    final updatedDevice = device.copyWith(remainingDoses: remaining);

    state = state.copyWith(
      doseLogs: [...imported, ...state.doseLogs],
      devices: state.devices
          .map((d) => d.id == deviceId ? updatedDevice : d)
          .toList(),
      undoLogId: imported.last.id,
    );

    final pct = (remaining / device.totalDoses) * 100;
    if (pct <= device.alertThresholdPct &&
        pct > 0 &&
        SettingsService.instance.lowInventoryAlerts) {
      try {
        await NotificationService.instance.showLowStockAlert(updatedDevice);
      } catch (_) {}
    }
    if (remaining == 0) {
      try {
        await NotificationService.instance.showDepletionAlert(updatedDevice);
      } catch (_) {}
    }

    showToast(
      'Imported ${imported.length} dose(s) from ${reading.model} (+8% adjusted)',
    );
    return imported;
  }

  // ── Log dose ───────────────────────────────────────────────

  Future<void> logDose(
    String deviceId,
    LogMethod method, {
    String? notes,
    String? injectionSite,
    double? overrideDoseMcg,
    double? overrideDoseIu,
  }) async {
    final device = state.devices.firstWhere((d) => d.id == deviceId);
    if (device.remainingDoses <= 0) return;

    final newRemaining = device.remainingDoses - 1;
    final baseDoseMcg = overrideDoseMcg ?? device.desiredDoseMcg;
    final log = DoseLog(
      id: _uuid.v4(),
      deviceId: deviceId,
      loggedAt: DateTime.now(),
      method: method,
      doseMcg: baseDoseMcg,
      doseIu: overrideDoseIu ?? device.doseVolumeIu,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      injectionSite: injectionSite,
    );

    await DatabaseService.instance.insertDoseLog(log);
    await DatabaseService.instance.updateRemainingDoses(deviceId, newRemaining);

    final updatedDevice = device.copyWith(remainingDoses: newRemaining);
    state = state.copyWith(
      doseLogs: [log, ...state.doseLogs],
      devices: state.devices
          .map((d) => d.id == deviceId ? updatedDevice : d)
          .toList(),
      undoLogId: log.id,
    );

    final pct = (newRemaining / device.totalDoses) * 100;
    if (pct <= device.alertThresholdPct &&
        pct > 0 &&
        SettingsService.instance.lowInventoryAlerts) {
      try {
        await NotificationService.instance.showLowStockAlert(updatedDevice);
      } catch (_) {}
    }
    if (newRemaining == 0) {
      try {
        await NotificationService.instance.showDepletionAlert(updatedDevice);
      } catch (_) {}
    }

    if (SettingsService.instance.doseReminders &&
        device.schedule == DoseSchedule.everyOtherDay) {
      if (device.notificationId != null) {
        try {
          await NotificationService.instance
              .cancelReminder(device.notificationId!);
        } catch (_) {}
      }
      try {
        final notifId = await NotificationService.instance
            .scheduleDoseReminder(updatedDevice);
        if (notifId != null) {
          final withNotif = updatedDevice.copyWith(notificationId: notifId);
          await DatabaseService.instance.updateDevice(withNotif);
          state = state.copyWith(
            devices: state.devices
                .map((d) => d.id == deviceId ? withNotif : d)
                .toList(),
          );
        }
      } catch (_) {}
    }

    showToast('${device.name} dose logged');
  }

  // ── Edit / delete dose log ─────────────────────────────────

  Future<void> updateDoseLog(DoseLog updatedLog) async {
    await DatabaseService.instance.updateDoseLog(updatedLog);
    state = state.copyWith(
      doseLogs: state.doseLogs
          .map((l) => l.id == updatedLog.id ? updatedLog : l)
          .toList(),
    );
  }

  Future<void> deleteDoseLog(String logId) async {
    final log = state.doseLogs.firstWhere((l) => l.id == logId);
    final device = state.devices.where((d) => d.id == log.deviceId).firstOrNull;

    await DatabaseService.instance.deleteDoseLog(logId);

    List<Device> updatedDevices = state.devices;
    if (device != null) {
      final newRemaining = device.remainingDoses + 1;
      await DatabaseService.instance
          .updateRemainingDoses(device.id, newRemaining);
      updatedDevices = state.devices
          .map((d) =>
              d.id == device.id ? d.copyWith(remainingDoses: newRemaining) : d)
          .toList();
    }

    state = state.copyWith(
      doseLogs: state.doseLogs.where((l) => l.id != logId).toList(),
      devices: updatedDevices,
    );
  }

  // ── Update device ──────────────────────────────────────────

  Future<void> updateDevice(Device updated) async {
    await DatabaseService.instance.updateDevice(updated);

    final old = state.devices.where((d) => d.id == updated.id).firstOrNull;
    if (old != null && old.notificationId != null) {
      try {
        await NotificationService.instance.cancelReminder(old.notificationId!);
      } catch (_) {}
    }
    String? notifId;
    if (SettingsService.instance.doseReminders &&
        updated.active &&
        updated.remainingDoses > 0) {
      try {
        notifId =
            await NotificationService.instance.scheduleDoseReminder(updated);
      } catch (_) {}
    }

    final withNotif = notifId != null
        ? updated.copyWith(notificationId: notifId)
        : updated.copyWith(clearNotificationId: true);
    if (notifId != null) await DatabaseService.instance.updateDevice(withNotif);
    if (notifId == null) await DatabaseService.instance.updateDevice(withNotif);

    state = state.copyWith(
      devices:
          state.devices.map((d) => d.id == updated.id ? withNotif : d).toList(),
    );
    showToast('${updated.name} updated');
  }

  // ── Archive ────────────────────────────────────────────────

  Future<void> archiveDevice(String deviceId) async {
    final device = state.devices.firstWhere((d) => d.id == deviceId);
    if (device.notificationId != null) {
      await NotificationService.instance.cancelReminder(device.notificationId!);
    }
    await DatabaseService.instance.deactivateDevice(deviceId);
    state = state.copyWith(
      devices: state.devices
          .map((d) => d.id == deviceId
              ? d.copyWith(active: false, remainingDoses: 0)
              : d)
          .toList(),
    );
  }

  // ── Protocols ──────────────────────────────────────────────

  Future<void> createProtocol({
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    String? notes,
    required List<String> deviceIds,
  }) async {
    final protocol = Protocol(
      id: _uuid.v4(),
      name: name,
      startDate: startDate,
      endDate: endDate,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    );

    await DatabaseService.instance.insertProtocol(protocol);
    await DatabaseService.instance
        .setDevicesForProtocol(protocol.id, deviceIds);

    final newMap = Map<String, String>.from(state.deviceProtocols);
    for (final id in deviceIds) {
      newMap[id] = protocol.id;
    }

    state = state.copyWith(
      protocols: [protocol, ...state.protocols],
      deviceProtocols: newMap,
    );
    showToast('${protocol.name} created');
  }

  Future<void> updateProtocol(Protocol updated, List<String> deviceIds) async {
    await DatabaseService.instance.updateProtocol(updated);
    await DatabaseService.instance.setDevicesForProtocol(updated.id, deviceIds);

    // Rebuild deviceProtocols map
    final newMap = Map<String, String>.from(state.deviceProtocols)
      ..removeWhere((_, v) => v == updated.id);
    for (final id in deviceIds) {
      newMap[id] = updated.id;
    }

    state = state.copyWith(
      protocols:
          state.protocols.map((p) => p.id == updated.id ? updated : p).toList(),
      deviceProtocols: newMap,
    );
    showToast('${updated.name} updated');
  }

  Future<void> deleteProtocol(String protocolId) async {
    final protocol = state.protocols.firstWhere((p) => p.id == protocolId);
    await DatabaseService.instance.deleteProtocol(protocolId);

    final newMap = Map<String, String>.from(state.deviceProtocols)
      ..removeWhere((_, v) => v == protocolId);

    state = state.copyWith(
      protocols: state.protocols.where((p) => p.id != protocolId).toList(),
      deviceProtocols: newMap,
    );
    showToast('${protocol.name} deleted');
  }

  // ── Clear all ──────────────────────────────────────────────

  Future<void> clearAllData() async {
    await NotificationService.instance.cancelAllReminders();
    await DatabaseService.instance.clearAllData();
    state = const AppState();
  }

  Future<void> refreshDoseReminders() async {
    await NotificationService.instance.cancelAllReminders();
    final devices = List<Device>.from(state.devices);
    final updated = <Device>[];
    for (final device in devices) {
      if (!SettingsService.instance.doseReminders ||
          !device.active ||
          device.remainingDoses <= 0) {
        final cleared = device.copyWith(clearNotificationId: true);
        await DatabaseService.instance.updateDevice(cleared);
        updated.add(cleared);
        continue;
      }
      try {
        final notifId =
            await NotificationService.instance.scheduleDoseReminder(device);
        final withNotif = notifId != null
            ? device.copyWith(notificationId: notifId)
            : device.copyWith(clearNotificationId: true);
        await DatabaseService.instance.updateDevice(withNotif);
        updated.add(withNotif);
      } catch (_) {
        final cleared = device.copyWith(clearNotificationId: true);
        await DatabaseService.instance.updateDevice(cleared);
        updated.add(cleared);
      }
    }
    state = state.copyWith(devices: updated);
  }

  // ── Undo last dose ─────────────────────────────────────────

  Future<void> undoLastDose() async {
    final logId = state.undoLogId;
    if (logId == null) return;
    state = state.copyWith(clearToast: true, clearUndo: true);
    await deleteDoseLog(logId);
  }

  // ── Toast ──────────────────────────────────────────────────

  void showToast(String message) {
    state = state.copyWith(toastMessage: message);
    Future.delayed(const Duration(milliseconds: 4000), clearToast);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true, clearUndo: true);
  }

  bool _isNovoPenImportNote(String? note) {
    if (note == null) return false;
    final v = note.toLowerCase();
    return v.contains('imported from') &&
        v.contains('novopen') &&
        v.contains('auto-adjusted +8%');
  }
}

// ── Providers ──────────────────────────────────────────────────

final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);

final devicesProvider =
    Provider<List<Device>>((ref) => ref.watch(appProvider).devices);

final activeDevicesProvider =
    Provider<List<Device>>((ref) => ref.watch(appProvider).activeDevices);

final doseLogsProvider =
    Provider<List<DoseLog>>((ref) => ref.watch(appProvider).doseLogs);

final toastProvider =
    Provider<String?>((ref) => ref.watch(appProvider).toastMessage);

final undoLogIdProvider =
    Provider<String?>((ref) => ref.watch(appProvider).undoLogId);

final protocolsProvider =
    Provider<List<Protocol>>((ref) => ref.watch(appProvider).protocols);

final deviceProtocolsProvider = Provider<Map<String, String>>(
    (ref) => ref.watch(appProvider).deviceProtocols);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return SettingsService.instance.themeMode;
  }

  void refreshFromSettings() {
    state = SettingsService.instance.themeMode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
