import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/nfc_service.dart';
import '../utils/calculations.dart';

// ── App State ──────────────────────────────────────────────────

class AppState {
  final List<Device> devices;
  final List<DoseLog> doseLogs;
  final String? toastMessage;

  const AppState({
    this.devices = const [],
    this.doseLogs = const [],
    this.toastMessage,
  });

  List<Device> get activeDevices => devices.where((d) => d.active).toList();

  AppState copyWith({
    List<Device>? devices,
    List<DoseLog>? doseLogs,
    String? toastMessage,
    bool clearToast = false,
  }) {
    return AppState(
      devices: devices ?? this.devices,
      doseLogs: doseLogs ?? this.doseLogs,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
    );
  }
}

// ── Notifier (Riverpod 2.x API) ────────────────────────────────

class AppNotifier extends Notifier<AppState> {
  static const _uuid = Uuid();

  @override
  AppState build() => const AppState();

  Future<void> initialize() async {
    final devices = await DatabaseService.instance.getAllDevices();
    final logs = await DatabaseService.instance.getAllDoseLogs();
    state = state.copyWith(devices: devices, doseLogs: logs);
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
    required DoseSchedule schedule,
    required int alertThresholdPct,
    String? nfcTagId,
  }) async {
    final doseVolumeIu = calcDoseIu(peptideMg, reconVolumeMl, desiredDoseMcg);
    final totalDoses = calcTotalDoses(reconVolumeMl, doseVolumeIu);
    final id = _uuid.v4();

    // nfcTagId is already written to the physical tag by StepNfcScan.
    // We just store it on the device record.
    final String? finalNfcTagId = nfcTagId;

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
      remainingDoses: totalDoses,
      schedule: schedule,
      nfcTagId: finalNfcTagId,
      alertThresholdPct: alertThresholdPct,
      active: true,
      createdAt: DateTime.now(),
    );

    try {
      final notifId = await NotificationService.instance.scheduleDoseReminder(device);
      if (notifId != null) device = device.copyWith(notificationId: notifId);
    } catch (_) {}

    await DatabaseService.instance.insertDevice(device);
    state = state.copyWith(devices: [device, ...state.devices]);
    showToast('${device.name} enrolled successfully');
  }

  // ── Log dose ───────────────────────────────────────────────

  Future<void> logDose(String deviceId, LogMethod method) async {
    final device = state.devices.firstWhere((d) => d.id == deviceId);
    if (device.remainingDoses <= 0) return;

    final newRemaining = device.remainingDoses - 1;
    final log = DoseLog(
      id: _uuid.v4(),
      deviceId: deviceId,
      loggedAt: DateTime.now(),
      method: method,
      doseMcg: device.desiredDoseMcg,
      doseIu: device.doseVolumeIu,
    );

    await DatabaseService.instance.insertDoseLog(log);
    await DatabaseService.instance.updateRemainingDoses(deviceId, newRemaining);

    final updatedDevice = device.copyWith(remainingDoses: newRemaining);
    state = state.copyWith(
      doseLogs: [log, ...state.doseLogs],
      devices: state.devices
          .map((d) => d.id == deviceId ? updatedDevice : d)
          .toList(),
    );

    final pct = (newRemaining / device.totalDoses) * 100;
    if (pct <= device.alertThresholdPct && pct > 0) {
      try { await NotificationService.instance.showLowStockAlert(updatedDevice); } catch (_) {}
    }

    showToast('${device.name} dose logged');
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
          .map((d) => d.id == deviceId ? d.copyWith(active: false) : d)
          .toList(),
    );
  }

  // ── Clear all ──────────────────────────────────────────────

  Future<void> clearAllData() async {
    await NotificationService.instance.cancelAllReminders();
    await DatabaseService.instance.clearAllData();
    state = const AppState();
  }

  // ── Toast ──────────────────────────────────────────────────

  void showToast(String message) {
    state = state.copyWith(toastMessage: message);
    Future.delayed(const Duration(milliseconds: 2800), clearToast);
  }

  void clearToast() {
    state = state.copyWith(clearToast: true);
  }
}

// ── Providers ──────────────────────────────────────────────────

// Riverpod 2.x: NotifierProvider replaces StateNotifierProvider
final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);

final devicesProvider =
    Provider<List<Device>>((ref) => ref.watch(appProvider).devices);

final activeDevicesProvider =
    Provider<List<Device>>((ref) => ref.watch(appProvider).activeDevices);

final doseLogsProvider =
    Provider<List<DoseLog>>((ref) => ref.watch(appProvider).doseLogs);

final toastProvider =
    Provider<String?>((ref) => ref.watch(appProvider).toastMessage);
