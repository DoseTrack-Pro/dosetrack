import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  Future<void> cancel() => _safeFinish();

  Future<void> _safeFinish({String? iosAlertMessage, String? iosErrorMessage}) async {
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
