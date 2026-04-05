import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NfcService {
  NfcService._();
  static final instance = NfcService._();

  bool _supported = false;
  bool get isSupported => _supported;

  Future<void> init() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      _supported = availability == NFCAvailability.available;
      debugPrint('NFC availability: $availability');
    } catch (e) {
      debugPrint('NFC init failed: $e');
      _supported = false;
    }
  }

  // ── Read tag UID ───────────────────────────────────────────
  // Works with ANY NFC tag — stickers, cards, key fobs, etc.
  // Returns the tag's unique hardware ID which never changes.

  Future<String?> readTagId({
    Duration timeout = const Duration(seconds: 10),
    String iosMessage = 'Hold your NFC tag near your phone',
  }) async {
    if (!_supported) throw Exception('NFC is not supported on this device');

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

      if (uid == null || uid.isEmpty) return null;
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
