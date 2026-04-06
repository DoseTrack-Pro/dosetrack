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
import '../widgets/device_card.dart';
import '../widgets/empty_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeDevicesProvider);
    final logs = ref.watch(doseLogsProvider);
    final protocols = ref.watch(protocolsProvider);
    final deviceProtocols = ref.watch(deviceProtocolsProvider);
    final nfcAvailable = NfcService.instance.isSupported;

    final today = DateTime.now();
    final lowDevices = active.where((d) => d.remainingPct * 100 < d.alertThresholdPct).toList();
    final expiredDevices = active.where((d) => isExpired(d)).toList();
    final expiringSoonDevices = active.where((d) => !isExpired(d) && daysUntilExpiry(d) <= 7).toList();
    final dueDevices = active.where((d) => d.remainingDoses > 0 && isDueToday(d, logs)).toList();
    final nfcDevices = active.where((d) => d.nfcTagId != null).toList();

    bool dosedToday(Device d) => logs.any((l) =>
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
                                style: TextStyle(fontSize: 12, color: context.clrTextSub)),
                            Text('My Peptides', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                                color: context.clrText, letterSpacing: -0.5)),
                          ],
                        ),
                      ),
                      // Calculator button
                      GestureDetector(
                        onTap: () => _openCalculator(context),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: context.clrBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.clrBorder, width: 0.5),
                          ),
                          child: Icon(Icons.calculate_outlined, color: context.clrTextSub, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Enroll button
                      GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context, isScrollControlled: true, useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const EnrollModal(),
                        ),
                        child: Container(
                          width: 38, height: 38,
                          decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 22),
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
                    if ((expiredDevices.isNotEmpty || expiringSoonDevices.isNotEmpty) && !_expiryDismissed) ...[
                      _ExpiryBanner(
                        expiredDevices: expiredDevices,
                        expiringSoonDevices: expiringSoonDevices,
                        onDismiss: () => setState(() => _expiryDismissed = true),
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
                      Text('DUE TODAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: context.clrTextSub, letterSpacing: 0.7)),
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
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(color: doseColor(d.remainingDoses, d.totalDoses),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Center(child: Text(d.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Empty state
                    if (active.isEmpty)
                      const EmptyState(title: 'No compounds yet',
                          subtitle: 'Tap + to enroll your first peptide pen or vial',
                          icon: Icons.science_outlined),

                    // Protocol sections
                    ...protocols
                        .where((p) => protocolDevices.containsKey(p.id))
                        .map((protocol) => _ProtocolSection(
                          protocol: protocol,
                          devices: protocolDevices[protocol.id]!,
                          dosedToday: dosedToday,
                          onEdit: () => _openEditProtocol(context, protocol),
                          onDeviceTap: (d) => _openDetail(context, ref, d),
                          onLogTap: (d) => _openLog(context, ref, d),
                        )),

                    // Ungrouped devices
                    if (ungrouped.isNotEmpty) ...[
                      if (protocols.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('OTHER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: context.clrTextSub, letterSpacing: 0.7)),
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
                      _CreateProtocolButton(onTap: () => _openCreateProtocol(context)),
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
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReconCalculatorModal(),
    );
  }

  void _openCreateProtocol(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateProtocolModal(),
    );
  }

  void _openEditProtocol(BuildContext context, Protocol protocol) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateProtocolModal(existing: protocol),
    );
  }

  void _openNfcScan(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NfcScanModal(onManualLog: (device) => _openLog(context, ref, device)),
    );
  }

  void _openLog(BuildContext context, WidgetRef ref, Device device) {
    if (device.remainingDoses <= 0) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogDoseModal(device: device, onNfcScan: () => _openNfcScan(context, ref)),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, Device device) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DeviceDetailPage(
        device: device,
        onLogManual: () => _openLog(context, ref, device),
        onLogNfc: () => _openNfcScan(context, ref),
      ),
    ));
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(children: [
                Expanded(child: Row(children: [
                  Text(protocol.name, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.tealDark)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      totalDays != null ? 'Day $dayNum / $totalDays' : 'Day $dayNum',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.tealDark),
                    ),
                  ),
                ])),
                Icon(Icons.edit_outlined, size: 14, color: AppColors.teal),
              ]),
            ),
          ),

          // Device cards
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2), width: 0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
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
                        ? const BorderRadius.vertical(bottom: Radius.circular(11))
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
        Icon(Icons.playlist_add_rounded, color: context.clrTextSub, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('Organise into a protocol',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.clrTextSub))),
        Icon(Icons.chevron_right_rounded, color: context.clrTextHint, size: 18),
      ]),
    ),
  );
}

// ── Today's Progress ──────────────────────────────────────────
class _TodayProgress extends StatelessWidget {
  final List<Device> devices;
  final List<DoseLog> logs;
  const _TodayProgress({required this.devices, required this.logs});

  @override
  Widget build(BuildContext context) {
    final scheduledDevices = devices.where((d) => d.remainingDoses > 0 && isScheduledToday(d)).toList();
    if (scheduledDevices.isEmpty) return const SizedBox.shrink();

    final today = DateTime.now();
    final dosed = scheduledDevices.where((d) => logs.any((l) =>
      l.deviceId == d.id &&
      l.loggedAt.year == today.year &&
      l.loggedAt.month == today.month &&
      l.loggedAt.day == today.day,
    )).length;
    final total = scheduledDevices.length;
    final progress = total > 0 ? dosed / total : 0.0;
    final allDone = dosed >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text("Today's doses", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.clrTextSub)),
          const Spacer(),
          Text(allDone ? 'All done!' : '$dosed / $total',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: allDone ? AppColors.teal : context.clrTextSub)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress, minHeight: 5,
            backgroundColor: context.clrBorder,
            valueColor: AlwaysStoppedAnimation<Color>(allDone ? AppColors.teal : AppColors.amber),
          ),
        ),
      ],
    );
  }
}

// ── NFC Scan Button ────────────────────────────────────────────
class _NfcScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NfcScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.nfc_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scan NFC to Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          SizedBox(height: 2),
          Text('Hold compound near phone to record dose', style: TextStyle(fontSize: 12, color: Color(0xBFFFFFFF))),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Color(0xBFFFFFFF)),
      ]),
    ),
  );
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
      const Text('!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.amber)),
      const SizedBox(width: 10),
      Expanded(child: Text('${devices.map((d) => d.name).join(', ')} running low',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.amberDark))),
      GestureDetector(
        onTap: onDismiss,
        child: const Padding(padding: EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, size: 16, color: AppColors.amber)),
      ),
    ]),
  );
}

// ── Expiry Banner ──────────────────────────────────────────────
class _ExpiryBanner extends StatelessWidget {
  final List<Device> expiredDevices;
  final List<Device> expiringSoonDevices;
  final VoidCallback onDismiss;
  const _ExpiryBanner({required this.expiredDevices, required this.expiringSoonDevices, required this.onDismiss});

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
        ? '$names ${expiredDevices.length == 1 ? 'has' : 'have'} expired (28 days since recon)'
        : '$names expiring within 7 days';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(children: [
        Icon(isExpiredCase ? Icons.warning_rounded : Icons.schedule_rounded, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor))),
        GestureDetector(
          onTap: onDismiss,
          child: Padding(padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 16, color: iconColor)),
        ),
      ]),
    );
  }
}
