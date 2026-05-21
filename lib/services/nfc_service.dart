import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/device.dart';

/// Mirrors the small set of states the rest of the app cares about.
/// Replaces the previous `NFCAvailability` enum from `flutter_nfc_kit`.
enum NfcAvailability { available, disabled, notSupported }

/// Talks to our own native NFC reader on iOS (Swift, see `ios/Runner/NfcReader.swift`)
/// and Android (Kotlin, see `android/.../NfcReader.kt`).
///
/// We replaced `flutter_nfc_kit` because its iOS Swift `register(with:)` was being
/// called with a nil `FlutterPluginRegistrar` on iOS 26 + ProMotion, which crashed
/// the app at launch (Flutter framework issue #168228 / VSync issue #183900).
/// Owning the channel ourselves means there's no third-party Flutter plugin doing
/// anything during app start; registration happens after the engine is fully ready.
class NfcService {
  NfcService._();
  static final instance = NfcService._();

  static const _channel = MethodChannel('com.adam.dosevault/nfc');

  NfcAvailability _availability = NfcAvailability.notSupported;

  /// True when the device hardware supports NFC, even if NFC is currently off.
  bool get isSupported => _availability != NfcAvailability.notSupported;

  /// True only when NFC is currently enabled/available for scanning.
  bool get isEnabled => _availability == NfcAvailability.available;

  Future<void> init() async {
    await refreshAvailability();
  }

  Future<NfcAvailability> refreshAvailability() async {
    if (!_isNativePlatform) {
      _availability = NfcAvailability.notSupported;
      return _availability;
    }
    try {
      final raw = await _channel.invokeMethod<String>('getNFCAvailability');
      _availability = _parseAvailability(raw);
      debugPrint('NFC availability: $_availability');
    } catch (e) {
      debugPrint('NFC init failed: $e');
      _availability = NfcAvailability.notSupported;
    }
    return _availability;
  }

  /// Reads a tag's hardware UID. Works with any NFC tag (sticker, card, key fob).
  /// Returns null if no UID could be read; throws on unsupported / disabled / cancel.
  Future<String?> readTagId({
    Duration timeout = const Duration(seconds: 10),
    String iosMessage = 'Hold your NFC tag near your phone',
  }) async {
    if (!_isNativePlatform) {
      throw Exception('NFC is not supported on this platform.');
    }

    final availability = await refreshAvailability();
    if (availability == NfcAvailability.notSupported) {
      throw Exception('NFC is not supported on this device');
    }
    if (availability == NfcAvailability.disabled) {
      throw Exception('NFC is turned off. Enable NFC in phone settings.');
    }

    debugPrint('NFC: polling for tag...');

    // The native side keeps the session open until either a tag is detected or
    // the user cancels via the system NFC sheet (iOS) / activity backgrounds
    // (Android). We add a Dart-side timeout as a defensive belt-and-braces.
    final pollFuture = _channel.invokeMethod<Map<dynamic, dynamic>>('poll', {
      'iosAlertMessage': iosMessage,
    });

    Map<dynamic, dynamic>? raw;
    try {
      raw = await pollFuture.timeout(timeout, onTimeout: () async {
        await _safeFinish(iosErrorMessage: 'No tag detected.');
        throw TimeoutException('NFC scan timed out.');
      });
    } on PlatformException catch (e) {
      debugPrint('NFC platform error: ${e.code} ${e.message}');
      await _safeFinish();
      // Re-raise as a regular exception so callers can showSnackBar without
      // needing to know about MethodChannel error codes.
      throw Exception(e.message ?? 'NFC error');
    } catch (e) {
      debugPrint('NFC read error: $e');
      await _safeFinish();
      rethrow;
    }

    debugPrint('NFC: tag found — $raw');

    final uid = (raw?['id'] as String?) ?? '';
    await _safeFinish(iosAlertMessage: 'Tag detected!');

    if (uid.isEmpty) return null;
    return uid;
  }

  /// Reads structured NovoPen memory over native NFC protocol (Android-only for now).
  Future<NovoPenReading?> readNovoPenData({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!_isNativePlatform) {
      throw Exception('NovoPen NFC is not supported on this platform.');
    }

    final availability = await refreshAvailability();
    if (availability == NfcAvailability.notSupported) {
      throw Exception('NFC is not supported on this device');
    }
    if (availability == NfcAvailability.disabled) {
      throw Exception('NFC is turned off. Enable NFC in phone settings.');
    }

    final pollFuture =
        _channel.invokeMethod<Map<dynamic, dynamic>>('readNovoPenData');

    Map<dynamic, dynamic>? raw;
    try {
      raw = await pollFuture.timeout(timeout, onTimeout: () async {
        await _safeFinish(iosErrorMessage: 'No pen detected.');
        throw TimeoutException('NovoPen scan timed out.');
      });
    } on PlatformException catch (e) {
      await _safeFinish();
      throw Exception(e.message ?? 'NovoPen NFC error');
    } catch (e) {
      await _safeFinish();
      rethrow;
    }

    if (raw == null) return null;

    final serial = (raw['serial'] as String?)?.trim() ?? '';
    if (serial.isEmpty) return null;
    final model = (raw['model'] as String?)?.trim() ?? 'NovoPen';
    final dosesRaw = (raw['doses'] as List<dynamic>? ?? const []);

    final doses = <NovoPenDose>[];
    for (final item in dosesRaw) {
      if (item is! Map) continue;
      final index = (item['index'] as num?)?.toInt();
      final timeMs = (item['timeMs'] as num?)?.toInt();
      final units = (item['units'] as num?)?.toInt();
      final flags = (item['flags'] as num?)?.toInt() ?? 0;
      if (timeMs == null || units == null || index == null) continue;
      doses.add(
        NovoPenDose(
          index: index,
          loggedAt: DateTime.fromMillisecondsSinceEpoch(timeMs),
          units: units,
          flags: flags,
        ),
      );
    }

    return NovoPenReading(model: model, serial: serial, doses: doses);
  }

  /// Single native-pass enrollment scan (Android).
  /// Returns either a standard tag UID or NovoPen serial + model.
  Future<EnrollmentScanResult?> scanForEnrollment({
    Duration timeout = const Duration(seconds: 20),
    String iosMessage = 'Hold your NFC tag near your phone',
  }) async {
    if (!_isNativePlatform) {
      throw Exception('NFC is not supported on this platform.');
    }

    final availability = await refreshAvailability();
    if (availability == NfcAvailability.notSupported) {
      throw Exception('NFC is not supported on this device');
    }
    if (availability == NfcAvailability.disabled) {
      throw Exception('NFC is turned off. Enable NFC in phone settings.');
    }

    Map<dynamic, dynamic>? raw;
    try {
      final pollFuture =
          _channel.invokeMethod<Map<dynamic, dynamic>>('scanForEnrollment');
      raw = await pollFuture.timeout(timeout, onTimeout: () async {
        await _safeFinish(iosErrorMessage: 'No tag detected.');
        throw TimeoutException('NFC scan timed out.');
      });
    } on MissingPluginException {
      // Fallback for platforms/builds without the unified native method.
      final id = await readTagId(timeout: timeout, iosMessage: iosMessage);
      if (id == null || id.isEmpty) return null;
      return EnrollmentScanResult(id: id, mode: NfcMode.tag);
    } on PlatformException catch (e) {
      if (e.code == 'incomplete_scan') {
        throw Exception(
            'Scan was too short. Hold the pen steady for 1-2 seconds and rescan.');
      }
      if (e.code == 'unimplemented') {
        final id = await readTagId(timeout: timeout, iosMessage: iosMessage);
        if (id == null || id.isEmpty) return null;
        return EnrollmentScanResult(id: id, mode: NfcMode.tag);
      }
      await _safeFinish();
      throw Exception(e.message ?? 'Enrollment NFC error');
    } catch (e) {
      await _safeFinish();
      rethrow;
    }

    if (raw == null) return null;
    final modeRaw = (raw['mode'] as String?)?.trim().toLowerCase() ?? 'tag';
    final id = (raw['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;

    final mode = modeRaw == 'novo_pen' ? NfcMode.novoPen : NfcMode.tag;
    final novoPenModel = (raw['model'] as String?)?.trim();
    final novoPenDoseCount = (raw['doseCount'] as num?)?.toInt();

    return EnrollmentScanResult(
      id: id,
      mode: mode,
      novoPenModel: (novoPenModel?.isEmpty ?? true) ? null : novoPenModel,
      novoPenDoseCount: mode == NfcMode.novoPen ? novoPenDoseCount : null,
    );
  }

  Future<void> cancel() => _safeFinish();

  Future<void> _safeFinish(
      {String? iosAlertMessage, String? iosErrorMessage}) async {
    if (!_isNativePlatform) return;
    try {
      await _channel.invokeMethod<void>('finish', {
        'iosAlertMessage': iosAlertMessage ?? '',
        'iosErrorMessage': iosErrorMessage ?? '',
      });
    } catch (_) {
      // Cleanup must never throw.
    }
  }

  bool get _isNativePlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  NfcAvailability _parseAvailability(String? raw) {
    switch (raw) {
      case 'available':
        return NfcAvailability.available;
      case 'disabled':
        return NfcAvailability.disabled;
      default:
        return NfcAvailability.notSupported;
    }
  }
}

class NovoPenDose {
  final int index;
  final DateTime loggedAt;
  final int units;
  final int flags;

  const NovoPenDose({
    required this.index,
    required this.loggedAt,
    required this.units,
    required this.flags,
  });
}

class NovoPenReading {
  final String model;
  final String serial;
  final List<NovoPenDose> doses;

  const NovoPenReading({
    required this.model,
    required this.serial,
    required this.doses,
  });
}

class EnrollmentScanResult {
  final String id;
  final NfcMode mode;
  final String? novoPenModel;
  final int? novoPenDoseCount;

  const EnrollmentScanResult({
    required this.id,
    required this.mode,
    this.novoPenModel,
    this.novoPenDoseCount,
  });
}
