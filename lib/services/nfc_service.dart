import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mirrors the small set of states the rest of the app cares about.
enum NfcAvailability { available, disabled, notSupported }

/// Categorises any failure surfaced by [NfcService.readTagId] so the UI can
/// branch on a single value instead of grepping error message strings.
///
/// Mapping (Dart-side) is in [NfcService._exceptionFor]; the codes come from
/// `NfcReader.swift` (iOS) and `NfcReader.kt` (Android).
enum NfcErrorKind {
  /// User dismissed the NFC sheet on iOS, or `cancel()` was called. UX-wise,
  /// callers should treat this as a benign close (no error toast).
  cancelled,

  /// The session ran past its allotted time without detecting a tag.
  timeout,

  /// The device hardware does not support NFC reading.
  notSupported,

  /// NFC is supported but currently turned off in system settings.
  disabled,

  /// Transient platform issue — iOS reports `systemIsBusy` (203) when the
  /// radio hasn't released from a previous session, or
  /// `sessionTerminatedUnexpectedly` (202) for various non-user-facing
  /// reasons. Generally retriable after a brief delay.
  unavailable,

  /// Something else went wrong (couldn't connect to tag, security violation,
  /// invalid parameter, etc.). [NfcException.details] usually carries the
  /// underlying iOS / Android error description.
  scanFailed,
}

/// Single exception type for everything the NFC service can throw. UI code
/// can `switch` on [kind] to render the right state — no more substring
/// matching on the message.
class NfcException implements Exception {
  final NfcErrorKind kind;
  final String message;

  /// The original platform error code (e.g. `session_cancelled`, `system_busy`)
  /// when this exception came from a [PlatformException]. `null` for Dart-side
  /// failures.
  final String? code;

  /// Human-readable iOS / Android error description, when available.
  final String? details;

  const NfcException(this.kind, this.message, {this.code, this.details});

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return '$message ($details)';
    }
    return message;
  }
}

/// Talks to our own native NFC reader on iOS (Swift, see `ios/Runner/NfcReader.swift`)
/// and Android (Kotlin, see `android/.../NfcReader.kt`). Owning the channel
/// ourselves means there's no third-party Flutter plugin doing anything during
/// app start.
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
  ///
  /// Returns `null` if no UID could be read; throws [NfcException] for every
  /// other failure mode (cancelled, timeout, unsupported, etc.).
  Future<String?> readTagId({
    Duration timeout = const Duration(seconds: 20),
    String iosMessage = 'Hold your NFC tag near your phone',
  }) async {
    if (!_isNativePlatform) {
      throw const NfcException(
        NfcErrorKind.notSupported,
        'NFC is not supported on this platform.',
      );
    }

    final availability = await refreshAvailability();
    if (availability == NfcAvailability.notSupported) {
      throw const NfcException(
        NfcErrorKind.notSupported,
        'NFC is not supported on this device.',
      );
    }
    if (availability == NfcAvailability.disabled) {
      throw const NfcException(
        NfcErrorKind.disabled,
        'NFC is turned off. Enable NFC in phone settings.',
      );
    }

    debugPrint('NFC: polling (timeout=${timeout.inSeconds}s)…');

    Map<dynamic, dynamic>? raw;
    try {
      raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('poll', {
            'iosAlertMessage': iosMessage,
          })
          .timeout(timeout, onTimeout: () async {
            await _safeFinish(iosErrorMessage: 'No tag detected.');
            throw const NfcException(
              NfcErrorKind.timeout,
              'NFC scan timed out.',
            );
          });
    } on NfcException {
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('NFC platform error: code=${e.code} '
          'message=${e.message} details=${e.details}');
      await _safeFinish();
      throw _exceptionFor(e);
    } catch (e, st) {
      debugPrint('NFC unexpected error: $e\n$st');
      await _safeFinish();
      throw NfcException(
        NfcErrorKind.scanFailed,
        'NFC error.',
        details: e.toString(),
      );
    }

    if (raw == null) {
      await _safeFinish();
      return null;
    }

    debugPrint('NFC: tag detected — $raw');
    await _safeFinish(iosAlertMessage: 'Tag detected!');

    final uid = (raw['id'] as String?) ?? '';
    return uid.isEmpty ? null : uid;
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

  /// Convert a [PlatformException] coming from `NfcReader.swift` / `NfcReader.kt`
  /// into a typed [NfcException]. Codes must match the strings used in both
  /// native files; keep these three in sync.
  NfcException _exceptionFor(PlatformException e) {
    final details = _readDetails(e.details);
    switch (e.code) {
      case 'session_cancelled':
      case 'cancelled':
        return NfcException(
          NfcErrorKind.cancelled,
          'NFC scan cancelled.',
          code: e.code,
          details: details,
        );
      case 'session_timeout':
      case 'timeout':
        return NfcException(
          NfcErrorKind.timeout,
          'NFC scan timed out.',
          code: e.code,
          details: details,
        );
      case 'not_supported':
      case 'unsupported_feature':
        return NfcException(
          NfcErrorKind.notSupported,
          'NFC is not supported on this device.',
          code: e.code,
          details: details,
        );
      case 'disabled':
      case 'radio_disabled':
        return NfcException(
          NfcErrorKind.disabled,
          'NFC is turned off. Enable NFC in phone settings.',
          code: e.code,
          details: details,
        );
      case 'session_active':
      case 'system_busy':
      case 'session_terminated':
        return NfcException(
          NfcErrorKind.unavailable,
          'NFC is busy. Wait a moment and try again.',
          code: e.code,
          details: details,
        );
      default:
        return NfcException(
          NfcErrorKind.scanFailed,
          e.message ?? 'NFC error.',
          code: e.code,
          details: details,
        );
    }
  }

  /// Native side sends `details` as either a `String` or a `Map`. Render
  /// whatever it is into a single human-readable line.
  String? _readDetails(Object? details) {
    if (details == null) return null;
    if (details is String) return details.isEmpty ? null : details;
    if (details is Map) {
      final code = details['errorCode'];
      final domain = details['errorDomain'];
      final desc = details['localizedDescription'];
      final parts = <String>[
        if (desc is String && desc.isNotEmpty) desc,
        if (code != null) 'code=$code',
        if (domain is String && domain.isNotEmpty) 'domain=$domain',
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }
    return details.toString();
  }
}
