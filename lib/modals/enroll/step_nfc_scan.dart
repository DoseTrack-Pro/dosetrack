import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/nfc_service.dart';
import '../../theme/app_theme.dart';

enum _Phase { scanning, success, timeout, error }

class StepNfcScan extends StatefulWidget {
  final void Function(String tagId) onTagWritten;
  final VoidCallback onSkip;

  const StepNfcScan({
    super.key,
    required this.onTagWritten,
    required this.onSkip,
  });

  @override
  State<StepNfcScan> createState() => _StepNfcScanState();
}

class _StepNfcScanState extends State<StepNfcScan>
    with SingleTickerProviderStateMixin {
  static const _totalSeconds = 10;

  _Phase _phase = _Phase.scanning;
  String _error = '';
  String? _scannedUid;
  int _countdown = _totalSeconds;
  Timer? _countdownTimer;

  // Pulse animation for the rings
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut);

    // Auto-start scanning immediately when the step appears
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    NfcService.instance.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = _totalSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        // NFC poll will timeout naturally — we just mirror the count visually
      }
    });
  }

  Future<void> _startScan() async {
    _countdownTimer?.cancel();
    setState(() {
      _phase = _Phase.scanning;
      _error = '';
      _scannedUid = null;
      _countdown = _totalSeconds;
    });
    _startCountdown();

    try {
      final uid = await NfcService.instance.readTagId(
        timeout: const Duration(seconds: _totalSeconds),
        iosMessage: 'Hold your NFC tag near the top of your phone',
      );

      _countdownTimer?.cancel();
      if (!mounted) return;

      if (uid == null || uid.isEmpty) {
        setState(() { _phase = _Phase.timeout; });
        return;
      }

      setState(() { _phase = _Phase.success; _scannedUid = uid; });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) widget.onTagWritten(uid);
    } catch (e) {
      _countdownTimer?.cancel();
      if (!mounted) return;

      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('user')) {
        // User tapped cancel — show timeout screen so they can retry or skip
        setState(() => _phase = _Phase.timeout);
      } else if (msg.contains('timeout')) {
        setState(() => _phase = _Phase.timeout);
      } else {
        setState(() {
          _phase = _Phase.error;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Color get _timerColor {
    if (_countdown > 6) return AppColors.teal;
    if (_countdown > 3) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title
        Text(
          _phase == _Phase.success ? 'Tag Detected!'
              : _phase == _Phase.timeout ? 'No Tag Detected'
              : _phase == _Phase.error ? 'Scan Failed'
              : 'Scan NFC Tag',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _phase == _Phase.scanning
              ? 'Hold any NFC tag flat against the\ntop-back of your phone'
              : _phase == _Phase.success
              ? 'Tag registered successfully'
              : _phase == _Phase.timeout
              ? 'No tag was found in time.\nMake sure NFC is enabled and try again.'
              : _error,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary,
              height: 1.5),
        ),
        const SizedBox(height: 32),

        // ── Main visual ──────────────────────────────────────
        SizedBox(
          width: 200, height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [

              // Countdown arc (scanning phase only)
              if (_phase == _Phase.scanning)
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _CountdownArcPainter(
                    progress: _countdown / _totalSeconds,
                    color: _timerColor,
                  ),
                ),

              // Pulsing rings (scanning phase only)
              if (_phase == _Phase.scanning) ...[
                AnimatedBuilder(animation: _pulse, builder: (_, __) =>
                    _PulseRing(progress: _pulse.value, size: 148)),
                AnimatedBuilder(animation: _pulse, builder: (_, __) =>
                    _PulseRing(progress: (_pulse.value + 0.45) % 1.0, size: 112)),
              ],

              // Centre circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 78, height: 78,
                decoration: BoxDecoration(
                  color: _phase == _Phase.success ? AppColors.tealLight
                      : _phase == _Phase.timeout ? AppColors.amberLight
                      : _phase == _Phase.error ? AppColors.redLight
                      : AppColors.teal,
                  shape: BoxShape.circle,
                ),
                child: Center(child: _centerContent()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // UID display on success
        if (_phase == _Phase.success && _scannedUid != null)
          Text('UID: $_scannedUid',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary,
                fontFamily: 'Courier New')),

        const SizedBox(height: 28),

        // ── Action buttons ───────────────────────────────────
        if (_phase == _Phase.scanning)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                NfcService.instance.cancel();
                _countdownTimer?.cancel();
                setState(() => _phase = _Phase.timeout);
              },
              child: const Text('Cancel'),
            ),
          ),

        if (_phase == _Phase.timeout || _phase == _Phase.error) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startScan,
              child: const Text('Try Again'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onSkip,
              child: const Text('Use manual tracking instead'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _centerContent() {
    switch (_phase) {
      case _Phase.scanning:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_countdown',
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700,
                color: Colors.white, fontFamily: 'Courier New',
              ),
            ),
            const Text('sec', style: TextStyle(fontSize: 11,
                color: Colors.white70)),
          ],
        );
      case _Phase.success:
        return const Icon(Icons.check_rounded, color: AppColors.teal, size: 40);
      case _Phase.timeout:
        return const Icon(Icons.timer_off_rounded,
            color: AppColors.amber, size: 36);
      case _Phase.error:
        return const Icon(Icons.error_outline_rounded,
            color: AppColors.red, size: 36);
    }
  }
}

// ── Pulsing ring ───────────────────────────────────────────────
class _PulseRing extends StatelessWidget {
  final double progress;
  final double size;
  const _PulseRing({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: (1 - progress).clamp(0.0, 1.0),
    child: Transform.scale(
      scale: 0.3 + progress * 0.7,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.teal, width: 2),
        ),
      ),
    ),
  );
}

// ── Countdown arc painter ──────────────────────────────────────
class _CountdownArcPainter extends CustomPainter {
  final double progress; // 1.0 = full, 0.0 = empty
  final Color color;
  const _CountdownArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 5;

    // Track
    canvas.drawCircle(center, radius, Paint()
      ..color = AppColors.border
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke);

    // Arc — drains clockwise from top
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownArcPainter old) =>
      progress != old.progress || color != old.color;
}
