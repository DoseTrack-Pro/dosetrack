import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../models/protocol.dart';
import '../services/nfc_service.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import '../widgets/animated_progress_bar.dart';
import '../widgets/device_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/pressable_scale.dart';
import '../modals/nfc_scan_modal.dart';
import '../modals/log_dose_modal.dart';
import '../modals/device_detail_modal.dart';
import '../modals/enroll/enroll_modal.dart';
import '../modals/recon_calculator_modal.dart';
import '../modals/create_protocol_modal.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _alertDismissed = false;
  bool _expiryDismissed = false;
  bool _missedDismissed = false;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeDevicesProvider);
    final logs = ref.watch(doseLogsProvider);
    final protocols = ref.watch(protocolsProvider);
    final deviceProtocols = ref.watch(deviceProtocolsProvider);
    final nfcAvailable = NfcService.instance.isSupported;

    final today = DateTime.now();
    final lowDevices = active
        .where((d) => d.remainingPct * 100 < d.alertThresholdPct)
        .toList();
    final expiredDevices = active.where((d) => isExpired(d)).toList();
    final expiringSoonDevices =
        active.where((d) => !isExpired(d) && daysUntilExpiry(d) <= 7).toList();
    final dueDevices = active
        .where((d) => d.remainingDoses > 0 && isDueToday(d, logs))
        .toList();
    final nfcDevices = active.where((d) => d.nfcTagId != null).toList();
    final yesterday = today.subtract(const Duration(days: 1));
    final missedYesterday = active.where((d) {
      if (d.remainingDoses <= 0) return false;
      if (!isScheduledOnDate(d, yesterday)) return false;
      final hadLog = logs.any((l) =>
          l.deviceId == d.id &&
          l.loggedAt.year == yesterday.year &&
          l.loggedAt.month == yesterday.month &&
          l.loggedAt.day == yesterday.day);
      return !hadLog;
    }).toList();
    int weeklyExpected = 0;
    int weeklyLogged = 0;
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      for (final device in active) {
        if (device.remainingDoses <= 0) continue;
        if (!isScheduledOnDate(device, date)) continue;
        weeklyExpected++;
        final hasLog = logs.any((l) =>
            l.deviceId == device.id &&
            l.loggedAt.year == date.year &&
            l.loggedAt.month == date.month &&
            l.loggedAt.day == date.day);
        if (hasLog) weeklyLogged++;
      }
    }
    final weeklyAdherence = calcAdherenceForDays(active, logs, 7);
    final weeklyStreak = calcStreak(logs);

    bool dosedToday(Device d) => logs.any(
          (l) =>
              l.deviceId == d.id &&
              l.loggedAt.year == today.year &&
              l.loggedAt.month == today.month &&
              l.loggedAt.day == today.day,
        );

    // Group devices: protocol → [devices], then ungrouped
    final protocolDevices = <String, List<Device>>{};
    final ungrouped = <Device>[];

    for (final device in active) {
      final protocolId = deviceProtocols[device.id];
      if (protocolId != null && protocols.any((p) => p.id == protocolId)) {
        protocolDevices.putIfAbsent(protocolId, () => []).add(device);
      } else {
        ungrouped.add(device);
      }
    }

    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('EEEE, MMMM d').format(today),
                                style: TextStyle(
                                    fontSize: 12, color: context.clrTextSub)),
                            Text('At a Glance',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: context.clrText,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 2),
                            Text('Your compounds, schedule, and alerts today',
                                style: TextStyle(
                                    fontSize: 12, color: context.clrTextSub)),
                          ],
                        ),
                      ),
                      // Calculator button
                      PressableScale(
                        onTap: () => _openCalculator(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: context.clrBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.clrBorder, width: 0.5),
                          ),
                          child: Icon(Icons.calculate_outlined,
                              color: context.clrTextSub, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Enroll button
                      PressableScale(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const EnrollModal(),
                        ),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                              color: AppColors.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (active.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TodayProgress(devices: active, logs: logs),
                  ],
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.teal,
                onRefresh: () => ref.read(appProvider.notifier).initialize(),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // NFC Scan Button
                    if (nfcAvailable && nfcDevices.isNotEmpty) ...[
                      _NfcScanButton(onTap: () => _openNfcScan(context, ref)),
                      const SizedBox(height: 12),
                    ],

                    // Expiry banner
                    if ((expiredDevices.isNotEmpty ||
                            expiringSoonDevices.isNotEmpty) &&
                        !_expiryDismissed) ...[
                      _ExpiryBanner(
                        expiredDevices: expiredDevices,
                        expiringSoonDevices: expiringSoonDevices,
                        onDismiss: () =>
                            setState(() => _expiryDismissed = true),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (weeklyExpected > 0) ...[
                      _WeeklyCheckInCard(
                        expected: weeklyExpected,
                        logged: weeklyLogged,
                        adherencePct: weeklyAdherence,
                        streakDays: weeklyStreak,
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (missedYesterday.isNotEmpty && !_missedDismissed) ...[
                      _MissedYesterdayCard(
                        missedDevices: missedYesterday,
                        onTap: () => _openMissedYesterdayDetails(
                            context, ref, missedYesterday),
                        onDismiss: () =>
                            setState(() => _missedDismissed = true),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Low stock banner
                    if (lowDevices.isNotEmpty && !_alertDismissed) ...[
                      _AlertBanner(
                        devices: lowDevices,
                        onDismiss: () => setState(() => _alertDismissed = true),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Due today chips
                    if (dueDevices.isNotEmpty) ...[
                      Text('DUE TODAY',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.clrTextSub,
                              letterSpacing: 0.7)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: dueDevices.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final d = dueDevices[i];
                            return GestureDetector(
                              onTap: () => _openLog(context, ref, d),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                    color: doseColor(
                                        d.remainingDoses, d.totalDoses),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Center(
                                    child: Text(d.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Empty state
                    if (active.isEmpty)
                      const EmptyState(
                          title: 'No compounds yet',
                          subtitle:
                              'Tap + to enroll your first peptide pen or vial',
                          icon: Icons.science_outlined),

                    // Protocol sections
                    ...protocols
                        .where((p) => protocolDevices.containsKey(p.id))
                        .map((protocol) => _ProtocolSection(
                              protocol: protocol,
                              devices: protocolDevices[protocol.id]!,
                              dosedToday: dosedToday,
                              onEdit: () =>
                                  _openEditProtocol(context, protocol),
                              onDeviceTap: (d) => _openDetail(context, ref, d),
                              onLogTap: (d) => _openLog(context, ref, d),
                            )),

                    // Ungrouped devices
                    if (ungrouped.isNotEmpty) ...[
                      if (protocols.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('OTHER',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.clrTextSub,
                                  letterSpacing: 0.7)),
                        ),
                      ],
                      ...ungrouped.map((device) => DeviceCard(
                            device: device,
                            dosedToday: dosedToday(device),
                            onTap: () => _openDetail(context, ref, device),
                            onLogTap: () => _openLog(context, ref, device),
                          )),
                    ],

                    // Create protocol nudge
                    if (active.length >= 2) ...[
                      const SizedBox(height: 8),
                      _CreateProtocolButton(
                          onTap: () => _openCreateProtocol(context)),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCalculator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReconCalculatorModal(),
    );
  }

  void _openCreateProtocol(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateProtocolModal(),
    );
  }

  void _openEditProtocol(BuildContext context, Protocol protocol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateProtocolModal(existing: protocol),
    );
  }

  void _openNfcScan(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          NfcScanModal(onManualLog: (device) => _openLog(context, ref, device)),
    );
  }

  void _openLog(BuildContext context, WidgetRef ref, Device device) {
    if (device.remainingDoses <= 0) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogDoseModal(
          device: device, onNfcScan: () => _openNfcScan(context, ref)),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, Device device) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceDetailPage(
            device: device,
            onLogManual: () => _openLog(context, ref, device),
            onLogNfc: () => _openNfcScan(context, ref),
          ),
        ));
  }

  void _openMissedYesterdayDetails(
    BuildContext context,
    WidgetRef ref,
    List<Device> missedDevices,
  ) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateLabel = DateFormat('EEEE, MMM d').format(yesterday);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: context.clrSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.clrBorderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Missed yesterday',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.clrText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: TextStyle(fontSize: 13, color: context.clrTextSub),
                ),
                const SizedBox(height: 14),
                ...missedDevices.map((device) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: context.clrBorder, width: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.clrText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  device.schedule.label,
                                  style: TextStyle(
                                      fontSize: 12, color: context.clrTextSub),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _openLog(context, ref, device);
                            },
                            child: const Text('Log now'),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Protocol Section ───────────────────────────────────────────
class _ProtocolSection extends StatelessWidget {
  final Protocol protocol;
  final List<Device> devices;
  final bool Function(Device) dosedToday;
  final VoidCallback onEdit;
  final void Function(Device) onDeviceTap;
  final void Function(Device) onLogTap;

  const _ProtocolSection({
    required this.protocol,
    required this.devices,
    required this.dosedToday,
    required this.onEdit,
    required this.onDeviceTap,
    required this.onLogTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayNum = protocol.dayNumber;
    final totalDays = protocol.totalDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Protocol header
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.clrTealBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(children: [
                Expanded(
                    child: Row(children: [
                  Expanded(
                    child: Text(
                      protocol.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      totalDays != null
                          ? 'Day $dayNum / $totalDays'
                          : 'Day $dayNum',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark),
                    ),
                  ),
                ])),
                const Icon(Icons.edit_outlined,
                    size: 14, color: AppColors.teal),
              ]),
            ),
          ),

          // Device cards
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.2), width: 0.5),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              children: devices.asMap().entries.map((e) {
                final device = e.value;
                final isLast = e.key == devices.length - 1;
                return Column(children: [
                  DeviceCard(
                    device: device,
                    dosedToday: dosedToday(device),
                    onTap: () => onDeviceTap(device),
                    onLogTap: () => onLogTap(device),
                    borderRadius: isLast
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(11))
                        : BorderRadius.zero,
                    showBorder: false,
                  ),
                  if (!isLast) Divider(height: 0, color: context.clrBorder),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Protocol Button ─────────────────────────────────────
class _CreateProtocolButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateProtocolButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.clrSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.clrBorder, width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.playlist_add_rounded,
                color: context.clrTextSub, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Organise into a protocol',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.clrTextSub))),
            Icon(Icons.chevron_right_rounded,
                color: context.clrTextHint, size: 18),
          ]),
        ),
      );
}

// ── Today's Progress ──────────────────────────────────────────
class _TodayProgress extends StatefulWidget {
  final List<Device> devices;
  final List<DoseLog> logs;
  const _TodayProgress({required this.devices, required this.logs});

  @override
  State<_TodayProgress> createState() => _TodayProgressState();
}

class _TodayProgressState extends State<_TodayProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  bool _prevAllDone = false;
  String _celebratedDayKey = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_pulseController);
    _prevAllDone = _stats().allDone;
  }

  @override
  void didUpdateWidget(covariant _TodayProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stats = _stats();
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (stats.allDone && !_prevAllDone && _celebratedDayKey != todayKey) {
      _celebratedDayKey = todayKey;
      _pulseController.forward(from: 0);
    }
    _prevAllDone = stats.allDone;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  _TodayStats _stats() {
    final scheduledDevices = widget.devices
        .where((d) => d.remainingDoses > 0 && isScheduledToday(d))
        .toList();
    final today = DateTime.now();
    final dosed = scheduledDevices
        .where((d) => widget.logs.any((l) =>
            l.deviceId == d.id &&
            l.loggedAt.year == today.year &&
            l.loggedAt.month == today.month &&
            l.loggedAt.day == today.day))
        .length;
    final total = scheduledDevices.length;
    final progress = total > 0 ? dosed / total : 0.0;
    return _TodayStats(
      scheduledCount: total,
      dosedCount: dosed,
      progress: progress,
      allDone: total > 0 && dosed >= total,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    if (stats.scheduledCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text("Today's doses",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.clrTextSub)),
          const Spacer(),
          ScaleTransition(
            scale:
                stats.allDone ? _pulseScale : const AlwaysStoppedAnimation(1),
            child: Text(
              stats.allDone
                  ? 'All done!'
                  : '${stats.dosedCount} / ${stats.scheduledCount}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: stats.allDone ? AppColors.teal : context.clrTextSub),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        AnimatedProgressBar(
          value: stats.progress,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: context.clrBorder,
          valueColor: stats.allDone ? AppColors.teal : AppColors.amber,
        ),
      ],
    );
  }
}

class _TodayStats {
  final int scheduledCount;
  final int dosedCount;
  final double progress;
  final bool allDone;
  const _TodayStats({
    required this.scheduledCount,
    required this.dosedCount,
    required this.progress,
    required this.allDone,
  });
}

// ── NFC Scan Button ────────────────────────────────────────────
class _NfcScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NfcScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.teal, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  const Icon(Icons.nfc_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Scan NFC to Log Dose',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(height: 2),
                  Text(
                      'Tap to start scanner, then hold tag or NovoPen near your phone NFC reader',
                      style: TextStyle(fontSize: 12, color: Color(0xBFFFFFFF))),
                ])),
            const Icon(Icons.chevron_right_rounded, color: Color(0xBFFFFFFF)),
          ]),
        ),
      );
}

// ── Weekly Check-in ─────────────────────────────────────────────
class _WeeklyCheckInCard extends StatelessWidget {
  final int expected;
  final int logged;
  final int adherencePct;
  final int streakDays;

  const _WeeklyCheckInCard({
    required this.expected,
    required this.logged,
    required this.adherencePct,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final tone = adherencePct >= 80
        ? AppColors.teal
        : adherencePct >= 50
            ? AppColors.amber
            : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.clrBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: tone, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This week: $logged / $expected logged · $adherencePct% adherence · $streakDays day streak',
              style: TextStyle(fontSize: 13, color: context.clrTextSub),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Missed Yesterday ────────────────────────────────────────────
class _MissedYesterdayCard extends StatelessWidget {
  final List<Device> missedDevices;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _MissedYesterdayCard({
    required this.missedDevices,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final count = missedDevices.length;
    final label = count == 1
        ? '1 dose was missed yesterday'
        : '$count doses were missed yesterday';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: context.clrAmberBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.amber, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_toggle_off_rounded,
                color: AppColors.amber, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label  Tap to view',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.amberDark),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.amber),
            GestureDetector(
              onTap: onDismiss,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child:
                    Icon(Icons.close_rounded, size: 16, color: AppColors.amber),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alert Banner ───────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final List<Device> devices;
  final VoidCallback onDismiss;
  const _AlertBanner({required this.devices, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: context.clrAmberBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.amber, width: 0.5),
        ),
        child: Row(children: [
          const Text('!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.amber)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  '${devices.map((d) => d.name).join(', ')} running low',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.amberDark))),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded,
                    size: 16, color: AppColors.amber)),
          ),
        ]),
      );
}

// ── Expiry Banner ──────────────────────────────────────────────
class _ExpiryBanner extends StatelessWidget {
  final List<Device> expiredDevices;
  final List<Device> expiringSoonDevices;
  final VoidCallback onDismiss;
  const _ExpiryBanner(
      {required this.expiredDevices,
      required this.expiringSoonDevices,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isExpiredCase = expiredDevices.isNotEmpty;
    final bgColor = isExpiredCase ? context.clrRedBg : context.clrAmberBg;
    final borderColor = isExpiredCase ? AppColors.red : AppColors.amber;
    final textColor = isExpiredCase ? AppColors.redDark : AppColors.amberDark;
    final iconColor = isExpiredCase ? AppColors.red : AppColors.amber;

    final allAffected = [...expiredDevices, ...expiringSoonDevices];
    final names = allAffected.map((d) => d.name).join(', ');
    final label = isExpiredCase
        ? '$names ${expiredDevices.length == 1 ? 'has' : 'have'} expired based on recon date and expiry setting'
        : '$names expiring within 7 days';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(children: [
        Icon(isExpiredCase ? Icons.warning_rounded : Icons.schedule_rounded,
            size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textColor))),
        GestureDetector(
          onTap: onDismiss,
          child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 16, color: iconColor)),
        ),
      ]),
    );
  }
}
