import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  AppLockService._();
  static final instance = AppLockService._();

  static const _pinKey = 'app_lock_pin';
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final ValueNotifier<int> lockNowSignal = ValueNotifier<int>(0);

  Future<bool> supportsBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String reason = 'Unlock Pep Tracker Pro',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> savePin(String pin) => _secure.write(key: _pinKey, value: pin);

  Future<bool> hasPin() async {
    final pin = await _secure.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> validatePin(String enteredPin) async {
    final stored = await _secure.read(key: _pinKey);
    if (stored == null || stored.isEmpty) return false;
    return enteredPin == stored;
  }

  Future<void> clearPin() => _secure.delete(key: _pinKey);

  void requestLockNow() {
    lockNowSignal.value = lockNowSignal.value + 1;
  }
}
