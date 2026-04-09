import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NfcService {
  NfcService._();
  static final instance = NfcService._();

  NFCAvailability _availability = NFCAvailability.not_supported;

  /// True when the device hardware supports NFC, even if NFC is currently off.
  bool get isSupported => _availability != NFCAvailability.not_supported;

  /// True only when NFC is currently enabled/available for scanning.
  bool get isEnabled => _availability == NFCAvailability.available;

  Future<void> init() async {
    await refreshAvailability();
  }

  Future<NFCAvailability> refreshAvailability() async {
    try {
      _availability = await FlutterNfcKit.nfcAvailability;
      debugPrint('NFC availability: $_availability');
    } catch (e) {
      debugPrint('NFC init failed: $e');
      _availability = NFCAvailability.not_supported;
    }
    return _availability;
  }

  // ── Read tag UID ───────────────────────────────────────────
  // Works with ANY NFC tag — stickers, cards, key fobs, etc.
  // Returns the tag's unique hardware ID which never changes.

  Future<String?> readTagId({
    Duration timeout = const Duration(seconds: 10),
    String iosMessage = 'Hold your NFC tag near your phone',
  }) async {
    final availability = await refreshAvailability();
    if (availability == NFCAvailability.not_supported) {
      throw Exception('NFC is not supported on this device');
    }
    if (availability == NFCAvailability.disabled) {
      throw Exception('NFC is turned off. Enable NFC in phone settings.');
    }

    try {
      debugPrint('NFC: polling for tag...');

      final tag = await FlutterNfcKit.poll(
        timeout: timeout,
        iosAlertMessage: iosMessage,
        androidCheckNDEF: false, // don't require NDEF — just need the UID
      );

      debugPrint('NFC: tag found — id=${tag.id}, type=${tag.type}');

      final uid = tag.id;

      await FlutterNfcKit.finish(iosAlertMessage: 'Tag detected!');

      if (uid.isEmpty) return null;
      return uid;
    } catch (e) {
      debugPrint('NFC read error: $e');
      await _safeFinish();
      rethrow;
    }
  }

  Future<void> cancel() => _safeFinish();

  Future<void> _safeFinish({String? iosErrorMessage}) async {
    try {
      await FlutterNfcKit.finish(iosErrorMessage: iosErrorMessage ?? '');
    } catch (_) {}
  }
}
