import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../providers/app_state.dart';
import '../services/nfc_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_chip.dart';
import '../widgets/dose_ring.dart';

enum _Phase { scanning, detected, timeout, error }

class NfcScanModal extends ConsumerStatefulWidget {
  final void Function(Device device) onManualLog;
  const NfcScanModal({super.key, required this.onManualLog});

  @override
  ConsumerState<NfcScanModal> createState() => _NfcScanModalState();
}

class _NfcScanModalState extends ConsumerState<NfcScanModal> with TickerProviderStateMixin {
  _Phase _phase = _Phase.scanning;
  int _countdown = 10;
  Device? _detected;
  String _error = '';
  Timer? _timer;

  late AnimationController _ring1;
  late AnimationController _ring2;

  @override
  void initState() {
    super.initState();
    _ring1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _ring2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward(from: 0.33)
      ..repeat();
    _startScan();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ring1.dispose();
    _ring2.dispose();
    NfcService.instance.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() { _phase = _Phase.scanning; _countdown = 10; _detected = null; _error = ''; });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); _onTimeout(); }
    });

    try {
      final tagId = await NfcService.instance.readTagId();
      _timer?.cancel();
      if (!mounted) return;

      if (tagId == null) { _onTimeout(); return; }

      final device = await DatabaseService.instance.getDeviceByNfcTagId(tagId);
      if (!mounted) return;

      if (device == null) {
        setState(() { _phase = _Phase.error; _error = 'This tag is not registered to any active container.'; });
      } else {
        setState(() { _phase = _Phase.detected; _detected = device; });
      }
    } catch (e) {
      _timer?.cancel();
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('user')) {
        if (mounted) Navigator.pop(context);
      } else {
        setState(() { _phase = _Phase.error; _error = 'Scan failed: $e'; });
      }
    }
  }

  void _onTimeout() {
    if (!mounted) return;
    NfcService.instance.cancel();
    setState(() => _phase = _Phase.timeout);
  }

  Future<void> _confirmLog() async {
    if (_detected == null) return;
    if (_detected!.remainingDoses <= 0) return; // depleted — guard
    await ref.read(appProvider.notifier).logDose(_detected!.id, LogMethod.nfc);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final nfcDevices = ref.watch(activeDevicesProvider).where((d) => d.nfcTagId != null).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              if (_phase == _Phase.scanning) _buildScanning(nfcDevices),
              if (_phase == _Phase.detected && _detected != null) _buildDetected(),
              if (_phase == _Phase.timeout || _phase == _Phase.error) _buildTimeout(nfcDevices),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scanning state ─────────────────────────────────────────

  Widget _buildScanning(List<Device> nfcDevices) {
    final timerColor = _countdown > 5 ? AppColors.teal : _countdown > 2 ? AppColors.amber : AppColors.red;

    return Column(
      children: [
        const Text('NFC Scan Active', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Hold any registered container near the top of your phone',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 28),

        // Countdown ring with pulsing rings behind
        SizedBox(
          width: 160, height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing rings
              AnimatedBuilder(animation: _ring1, builder: (_, __) => _PulseRing(progress: _ring1.value, size: 120)),
              AnimatedBuilder(animation: _ring2, builder: (_, __) => _PulseRing(progress: _ring2.value, size: 90)),
              // SVG countdown arc
              CustomPaint(size: const Size(160, 160), painter: _CountdownArcPainter(
                progress: _countdown / 10, color: timerColor,
              )),
              // Center circle
              Container(
                width: 62, height: 62,
                decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                child: Center(child: Text('${_countdown}s',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: Colors.white, fontFamily: 'Courier New'))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (nfcDevices.isNotEmpty) ...[
          const Align(alignment: Alignment.centerLeft,
            child: Text('LISTENING FOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary, letterSpacing: 0.6))),
          const SizedBox(height: 8),
          ...nfcDevices.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Container(width: 7, height: 7,
                  decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(d.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
              BadgeChip(
                label: d.type.name.toUpperCase(),
                bg: d.type == ContainerType.pen ? AppColors.purpleLight : AppColors.tealLight,
                fg: d.type == ContainerType.pen ? AppColors.purpleDark : AppColors.tealDark,
              ),
            ]),
          )),
          const SizedBox(height: 16),
        ],

        TextButton(
          onPressed: () { NfcService.instance.cancel(); Navigator.pop(context); },
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  // ── Detected state ─────────────────────────────────────────

  Widget _buildDetected() {
    final d = _detected!;
    final color = doseColor(d.remainingDoses, d.totalDoses);

    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: AppColors.teal, size: 36),
        ),
        const SizedBox(height: 14),
        const Text('NFC Tag Detected', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Confirm the dose for the matched container',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 20),

        // Device card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            DoseRing(remaining: d.remainingDoses, total: d.totalDoses, size: 70),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(d.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                const SizedBox(width: 6),
                const BadgeChip(label: 'NFC', bg: AppColors.blueLight, fg: AppColors.blueDark),
              ]),
              const SizedBox(height: 3),
              Text(d.vendor, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${d.schedule.label}  ·  ${d.desiredDoseMcg.toStringAsFixed(0)}mcg / ${d.doseVolumeIu.toStringAsFixed(0)}IU',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        if (d.remainingDoses <= 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Depleted — no doses remaining',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textTertiary)),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ] else ...[
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmLog,
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('Confirm Dose Logged'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
        ],
      ],
    );
  }

  // ── Timeout / error state ──────────────────────────────────

  Widget _buildTimeout(List<Device> nfcDevices) {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: AppColors.redLight, shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 36),
        ),
        const SizedBox(height: 14),
        Text(_phase == _Phase.error ? 'Tag Not Recognized' : 'No Tag Detected',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(
          _error.isNotEmpty ? _error : 'The scan timed out without finding an NFC tag.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),

        SizedBox(width: double.infinity,
          child: ElevatedButton(onPressed: _startScan, child: const Text('Try Again'))),
        const SizedBox(height: 16),

        if (nfcDevices.isNotEmpty) ...[
          const Align(alignment: Alignment.centerLeft,
            child: Text('LOG MANUALLY INSTEAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary, letterSpacing: 0.6))),
          const SizedBox(height: 8),
          ...nfcDevices.where((d) => d.remainingDoses > 0).map((d) => GestureDetector(
            onTap: () { Navigator.pop(context); widget.onManualLog(d); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(child: Text(d.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                const Text('Log →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
              ]),
            ),
          )),
          const SizedBox(height: 8),
        ],

        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
      ],
    );
  }
}

// ── Pulse ring animation widget ────────────────────────────────

class _PulseRing extends StatelessWidget {
  final double progress;
  final double size;
  const _PulseRing({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    return Opacity(
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
}

// ── Countdown arc painter ──────────────────────────────────────

class _CountdownArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _CountdownArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;

    canvas.drawCircle(center, radius, Paint()
      ..color = AppColors.border
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownArcPainter old) => progress != old.progress || color != old.color;
}
