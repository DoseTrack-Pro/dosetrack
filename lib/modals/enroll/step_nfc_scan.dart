import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../services/nfc_service.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dose_ring.dart';
import '../../widgets/badge_chip.dart';

// Added 'duplicate' phase for NFC tag already in use by an active container
enum _Phase { scanning, success, timeout, error, duplicate }

class StepNfcScan extends StatefulWidget {
  final void Function(
    String tagId,
    NfcMode nfcMode,
    int novoPenBaselineCount,
    bool importExistingHistory,
  ) onTagWritten;
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
  static const _totalSeconds = 20;

  _Phase _phase = _Phase.scanning;
  String _error = '';
  String? _scannedUid;
  NfcMode _detectedMode = NfcMode.tag;
  int _detectedNovoPenDoseCount = 0;
  bool _importExistingHistory = false;
  bool _requiresRescan = false;
  int _countdown = _totalSeconds;
  Timer? _countdownTimer;

  // Set when the scanned tag conflicts with an existing active container
  Device? _conflictDevice;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    NfcService.instance.cancel();
    super.dispose();
  }

  // ── Countdown ─────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = _totalSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  // ── Scan & validate ───────────────────────────────────────────

  Future<void> _startScan() async {
    _countdownTimer?.cancel();
    setState(() {
      _phase = _Phase.scanning;
      _error = '';
      _scannedUid = null;
      _detectedMode = NfcMode.tag;
      _detectedNovoPenDoseCount = 0;
      _importExistingHistory = false;
      _requiresRescan = false;
      _conflictDevice = null;
      _countdown = _totalSeconds;
    });
    _startCountdown();

    try {
      final result = await NfcService.instance.scanForEnrollment(
        timeout: const Duration(seconds: _totalSeconds),
        iosMessage: 'Hold your NFC tag near the top of your phone',
      );
      final identifier = result?.id;
      final detectedMode = result?.mode ?? NfcMode.tag;
      final detectedDoseCount = result?.novoPenDoseCount ?? 0;

      _countdownTimer?.cancel();
      if (!mounted) return;

      if (identifier == null || identifier.isEmpty) {
        setState(() => _phase = _Phase.timeout);
        return;
      }

      // ── Uniqueness check ─────────────────────────────────────
      // Look for any active, non-depleted container already using this tag.
      final conflict = await DatabaseService.instance
          .getConflictingDeviceByNfcTagId(identifier);

      if (!mounted) return;

      if (conflict != null) {
        // Tag is in use — show the duplicate state
        setState(() {
          _phase = _Phase.duplicate;
          _scannedUid = identifier;
          _detectedMode = detectedMode;
          _conflictDevice = conflict;
        });
        return;
      }

      // Tag is free — proceed
      setState(() {
        _phase = _Phase.success;
        _scannedUid = identifier;
        _detectedMode = detectedMode;
        _detectedNovoPenDoseCount =
            detectedMode == NfcMode.novoPen ? detectedDoseCount : 0;
      });
      if (detectedMode == NfcMode.tag) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          widget.onTagWritten(identifier, detectedMode, 0, false);
        }
      }
    } catch (e) {
      _countdownTimer?.cancel();
      if (!mounted) return;

      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('user')) {
        setState(() => _phase = _Phase.timeout);
      } else if (msg.contains('timeout')) {
        setState(() => _phase = _Phase.timeout);
      } else if (msg.contains('scan was too short') ||
          msg.contains('transceive failed') ||
          msg.contains('tag was lost')) {
        setState(() {
          _phase = _Phase.error;
          _requiresRescan = true;
          _error =
              'Scan was too short. Hold the pen steady near the top of your phone for 1-2 seconds, then rescan.';
        });
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

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title
        Text(
          _phaseTitle,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.clrText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Subtitle — hide for duplicate (card below carries the message)
        if (_phase != _Phase.duplicate)
          Text(
            _phaseSubtitle,
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: context.clrTextSub, height: 1.5),
          ),

        const SizedBox(height: 28),

        // ── Visual ─────────────────────────────────────────────
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_phase == _Phase.scanning)
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _CountdownArcPainter(
                    progress: _countdown / _totalSeconds,
                    color: _timerColor,
                    borderColor: context.clrBorder,
                  ),
                ),
              if (_phase == _Phase.scanning) ...[
                AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) =>
                        _PulseRing(progress: _pulse.value, size: 148)),
                AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => _PulseRing(
                        progress: (_pulse.value + 0.45) % 1.0, size: 112)),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _centerColor(context),
                  shape: BoxShape.circle,
                ),
                child: Center(child: _centerContent()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Duplicate conflict card ─────────────────────────────
        if (_phase == _Phase.duplicate && _conflictDevice != null)
          _DuplicateCard(device: _conflictDevice!),

        // UID on success
        if (_phase == _Phase.success && _scannedUid != null)
          Text(
              '${_detectedMode == NfcMode.novoPen ? 'Serial' : 'UID'}: $_scannedUid',
              style: TextStyle(
                  fontSize: 11,
                  color: context.clrTextHint,
                  fontFamily: 'Inter',
                  fontFeatures: const [FontFeature.tabularFigures()])),

        if (_phase == _Phase.success && _detectedMode == NfcMode.novoPen) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.clrBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.clrBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${_detectedNovoPenDoseCount.toString()} dose record(s) in this pen.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.clrText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _importExistingHistory
                      ? 'Existing pen history will be imported after enrollment.'
                      : 'Start from now is enabled (recommended): existing pen history will be ignored.',
                  style: TextStyle(fontSize: 12, color: context.clrTextSub),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _importExistingHistory,
                  title: Text(
                    'Import existing pen history',
                    style: TextStyle(fontSize: 13, color: context.clrText),
                  ),
                  subtitle: Text(
                    'Turn on only if you want to backfill older doses.',
                    style: TextStyle(fontSize: 12, color: context.clrTextSub),
                  ),
                  onChanged: (value) =>
                      setState(() => _importExistingHistory = value),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── Action buttons ──────────────────────────────────────
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

        if (_phase == _Phase.success && _detectedMode == NfcMode.novoPen) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _scannedUid == null
                  ? null
                  : () {
                      final baselineCount = _importExistingHistory
                          ? 0
                          : _detectedNovoPenDoseCount;
                      widget.onTagWritten(
                        _scannedUid!,
                        _detectedMode,
                        baselineCount,
                        _importExistingHistory,
                      );
                    },
              child: const Text('Continue with NovoPen'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _startScan,
              child: const Text('Scan again'),
            ),
          ),
        ],

        if (_phase == _Phase.timeout || _phase == _Phase.error) ...[
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _startScan, child: const Text('Try again'))),
          if (!_requiresRescan) ...[
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                    onPressed: widget.onSkip,
                    child: const Text('Continue without NFC'))),
          ],
        ],

        if (_phase == _Phase.duplicate) ...[
          // Offer to scan a different tag
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startScan,
              child: const Text('Scan a different tag'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onSkip,
              child: const Text('Continue without NFC'),
            ),
          ),
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  String get _phaseTitle {
    switch (_phase) {
      case _Phase.scanning:
        return 'Scan NFC Device';
      case _Phase.success:
        return _detectedMode == NfcMode.novoPen
            ? 'NovoPen Detected!'
            : 'Tag Detected!';
      case _Phase.timeout:
        return 'No Tag Detected';
      case _Phase.error:
        return 'Scan Failed';
      case _Phase.duplicate:
        return 'Tag Already In Use';
    }
  }

  String get _phaseSubtitle {
    switch (_phase) {
      case _Phase.scanning:
        return 'Hold your NFC tag or NovoPen near the top-back of your phone.\nWe will detect the type automatically.';
      case _Phase.success:
        if (_detectedMode == NfcMode.novoPen) {
          return 'Dose history will be read directly from your pen.\nFor standard 3mL cartridges, NovoPen often delivers slightly more than the dialed amount, so doses are automatically corrected by +8% for more accurate tracking.';
        }
        return 'Tag registered successfully';
      case _Phase.timeout:
        return 'No tag was found in time.\nMake sure NFC is enabled and try again.';
      case _Phase.error:
        return _error;
      case _Phase.duplicate:
        return ''; // handled by _DuplicateCard
    }
  }

  Color _centerColor(BuildContext context) {
    switch (_phase) {
      case _Phase.scanning:
        return AppColors.teal;
      case _Phase.success:
        return context.clrTealBg;
      case _Phase.timeout:
        return context.clrAmberBg;
      case _Phase.error:
        return context.clrRedBg;
      case _Phase.duplicate:
        return context.clrAmberBg;
    }
  }

  Widget _centerContent() {
    switch (_phase) {
      case _Phase.scanning:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_countdown',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontFeatures: [FontFeature.tabularFigures()])),
          const Text('sec',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]);
      case _Phase.success:
        return const Icon(Icons.check_rounded, color: AppColors.teal, size: 40);
      case _Phase.timeout:
        return const Icon(Icons.timer_off_rounded,
            color: AppColors.amber, size: 36);
      case _Phase.error:
        return const Icon(Icons.error_outline_rounded,
            color: AppColors.red, size: 36);
      case _Phase.duplicate:
        return const Icon(Icons.link_rounded, color: AppColors.amber, size: 36);
    }
  }
}

// ── Duplicate conflict card ────────────────────────────────────

class _DuplicateCard extends StatelessWidget {
  final Device device;
  const _DuplicateCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final pct = device.remainingPct;
    final color = doseColor(device.remainingDoses, device.totalDoses);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: context.clrAmberBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning header
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.amber, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This tag is linked to an active compound',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amberDark),
                ),
              ),
            ]),
          ),

          // Device summary row
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.clrSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.clrBorder, width: 0.5),
            ),
            child: Row(children: [
              DoseRing(
                  remaining: device.remainingDoses,
                  total: device.totalDoses,
                  size: 54,
                  strokeWidth: 4),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                        child: Text(device.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.clrText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    BadgeChip(
                      label: device.type.name.toUpperCase(),
                      bg: device.type == ContainerType.pen
                          ? context.clrPurpleBg
                          : context.clrTealBg,
                      fg: device.type == ContainerType.pen
                          ? AppColors.purpleDark
                          : AppColors.tealDark,
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(device.vendor,
                      style: TextStyle(fontSize: 12, color: context.clrTextSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${device.remainingDoses} of ${device.totalDoses} doses remaining  (${(pct * 100).round()}%)',
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              )),
            ]),
          ),

          // Explanation
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              'You can reuse this tag once "${device.name}" is fully depleted. '
              'Scan a different tag, or choose manual tracking.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.amberDark, height: 1.45),
            ),
          ),
        ],
      ),
    );
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
            width: size,
            height: size,
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
  final double progress;
  final Color color;
  final Color borderColor;
  const _CountdownArcPainter(
      {required this.progress, required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 5;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = borderColor
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke);

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
      progress != old.progress ||
      color != old.color ||
      borderColor != old.borderColor;
}
