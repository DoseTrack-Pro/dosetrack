import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();
  static final instance = SettingsService._();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Notifications ──────────────────────────────────────────────
  bool get doseReminders => _prefs.getBool('doseReminders') ?? true;
  bool get lowInventoryAlerts => _prefs.getBool('lowInventoryAlerts') ?? true;
  bool get missedDoseAlerts => _prefs.getBool('missedDoseAlerts') ?? true;

  Future<void> setDoseReminders(bool v) => _prefs.setBool('doseReminders', v);
  Future<void> setLowInventoryAlerts(bool v) =>
      _prefs.setBool('lowInventoryAlerts', v);
  Future<void> setMissedDoseAlerts(bool v) =>
      _prefs.setBool('missedDoseAlerts', v);

  // ── NFC ────────────────────────────────────────────────────────
  /// Auto-log: if true AND confirmLog is false, skips the confirmation step.
  bool get nfcAutoLog => _prefs.getBool('nfcAutoLog') ?? false;

  /// Confirm: always show confirmation before saving, even when auto-log is on.
  bool get nfcConfirmLog => _prefs.getBool('nfcConfirmLog') ?? true;

  /// Scan timeout in seconds (default 20).
  int get nfcScanTimeout => _prefs.getInt('nfcScanTimeout') ?? 20;

  Future<void> setNfcAutoLog(bool v) => _prefs.setBool('nfcAutoLog', v);
  Future<void> setNfcConfirmLog(bool v) => _prefs.setBool('nfcConfirmLog', v);
  Future<void> setNfcScanTimeout(int v) => _prefs.setInt('nfcScanTimeout', v);

  // ── Appearance ─────────────────────────────────────────────────
  /// 0 = system, 1 = light, 2 = dark
  int get themeModePref => _prefs.getInt('themeMode') ?? 0;
  Future<void> setThemeModePref(int v) => _prefs.setInt('themeMode', v);

  ThemeMode get themeMode {
    switch (themeModePref) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  // ── Onboarding ─────────────────────────────────────────────────
  bool get onboardingComplete => _prefs.getBool('onboardingComplete') ?? false;
  Future<void> setOnboardingComplete() =>
      _prefs.setBool('onboardingComplete', true);

  // ── App lock / privacy ────────────────────────────────────────
  bool get appLockEnabled => _prefs.getBool('appLockEnabled') ?? false;
  bool get appLockBiometrics => _prefs.getBool('appLockBiometrics') ?? true;

  /// In minutes. 0 means lock immediately when app backgrounds.
  int get appLockTimeoutMinutes => _prefs.getInt('appLockTimeoutMinutes') ?? 5;

  Future<void> setAppLockEnabled(bool v) => _prefs.setBool('appLockEnabled', v);
  Future<void> setAppLockBiometrics(bool v) =>
      _prefs.setBool('appLockBiometrics', v);
  Future<void> setAppLockTimeoutMinutes(int v) =>
      _prefs.setInt('appLockTimeoutMinutes', v);

  // ── Missed-dose alert dedupe ───────────────────────────────────
  String? lastMissedAlertDate(String deviceId) =>
      _prefs.getString('missedAlert_$deviceId');
  Future<void> setLastMissedAlertDate(String deviceId, String dateIso) =>
      _prefs.setString('missedAlert_$deviceId', dateIso);
}
