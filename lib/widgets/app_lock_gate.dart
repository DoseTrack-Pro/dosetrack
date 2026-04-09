import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _locked = false;
  bool _unlocking = false;
  bool _ignoreNextResumeLock = false;

  final _pinCtrl = TextEditingController();
  String? _pinError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLockService.instance.lockNowSignal.addListener(_onLockNowSignal);
    _locked = SettingsService.instance.appLockEnabled;
    if (_locked) {
      Future.microtask(_ensureLockCanUnlock);
    }
  }

  @override
  void dispose() {
    AppLockService.instance.lockNowSignal.removeListener(_onLockNowSignal);
    WidgetsBinding.instance.removeObserver(this);
    _pinCtrl.dispose();
    super.dispose();
  }

  void _onLockNowSignal() {
    if (!SettingsService.instance.appLockEnabled || !mounted) return;
    setState(() {
      _locked = true;
      _pinError = null;
      _pinCtrl.clear();
    });
    _tryBiometric();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!SettingsService.instance.appLockEnabled) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // On Android, local_auth can temporarily move the app through lifecycle
      // states while the biometric prompt is visible. Don't treat that as a
      // true background event that should relock the app.
      if (_unlocking) return;
      _backgroundedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_ignoreNextResumeLock) {
        _ignoreNextResumeLock = false;
        _backgroundedAt = null;
        return;
      }
      final bgAt = _backgroundedAt;
      if (bgAt == null) return;
      _backgroundedAt = null;

      final timeoutMins = SettingsService.instance.appLockTimeoutMinutes;
      final elapsed = DateTime.now().difference(bgAt);
      final shouldLock =
          timeoutMins == 0 || elapsed >= Duration(minutes: timeoutMins);
      if (!shouldLock) return;

      setState(() {
        _locked = true;
        _pinError = null;
        _pinCtrl.clear();
      });
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (!_locked || _unlocking) return;
    if (!SettingsService.instance.appLockBiometrics) return;

    final canUse = await AppLockService.instance.supportsBiometrics();
    if (!canUse || !_locked || !mounted) return;

    _ignoreNextResumeLock = true;
    _unlocking = true;
    final ok = await AppLockService.instance.authenticateBiometric();
    _unlocking = false;
    if (!mounted) return;
    if (ok) {
      setState(() {
        _locked = false;
        _pinError = null;
        _pinCtrl.clear();
      });
    }
  }

  Future<void> _ensureLockCanUnlock() async {
    if (!_locked) return;
    final hasPin = await AppLockService.instance.hasPin();
    final biometricsEnabled = SettingsService.instance.appLockBiometrics;
    final bioSupported = await AppLockService.instance.supportsBiometrics();

    if (!hasPin && !(biometricsEnabled && bioSupported)) {
      await SettingsService.instance.setAppLockEnabled(false);
      if (!mounted) return;
      setState(() => _locked = false);
      return;
    }

    if (!mounted) return;
    _tryBiometric();
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 4) {
      setState(() => _pinError = 'Enter your 4-digit PIN');
      return;
    }
    final ok = await AppLockService.instance.validatePin(pin);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _locked = false;
        _pinError = null;
        _pinCtrl.clear();
      });
    } else {
      setState(() => _pinError = 'Incorrect PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.clrSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.clrBorder, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.clrTealBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.tealDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unlock Pep Tracker Pro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.clrText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your app is locked for privacy.',
                      style: TextStyle(fontSize: 13, color: context.clrTextSub),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      onChanged: (_) {
                        if (_pinError != null) setState(() => _pinError = null);
                      },
                      onSubmitted: (_) => _unlockWithPin(),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'PIN',
                        hintText: '4 digits',
                        errorText: _pinError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _unlockWithPin,
                        child: const Text('Unlock'),
                      ),
                    ),
                    if (SettingsService.instance.appLockBiometrics) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _unlocking ? null : _tryBiometric,
                          icon: const Icon(Icons.fingerprint_rounded, size: 18),
                          label: Text(
                            _unlocking
                                ? 'Checking biometrics...'
                                : 'Use biometrics',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
