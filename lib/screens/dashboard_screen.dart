import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/device.dart';
import '../services/nfc_service.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import '../widgets/device_card.dart';
import '../widgets/empty_state.dart';
import '../modals/nfc_scan_modal.dart';
import '../modals/log_dose_modal.dart';
import '../modals/device_detail_modal.dart';
import '../modals/enroll/enroll_modal.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDevicesProvider);
    final logs = ref.watch(doseLogsProvider);
    final nfcAvailable = NfcService.instance.isSupported;

    final lowDevices = active.where((d) => d.remainingPct * 100 < d.alertThresholdPct).toList();
    final dueDevices = active.where((d) => d.remainingDoses > 0 && isDueToday(d, logs)).toList();
    final nfcDevices = active.where((d) => d.nfcTagId != null).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('EEEE, MMMM d').format(DateTime.now()),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const Text('My Peptides', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
                      ],
                    ),
                  ),
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

                    // Low stock banner
                    if (lowDevices.isNotEmpty) ...[
                      _AlertBanner(devices: lowDevices),
                      const SizedBox(height: 12),
                    ],

                    // Due today chips
                    if (dueDevices.isNotEmpty) ...[
                      const Text('DUE TODAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.7)),
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
                                decoration: BoxDecoration(color: doseColor(d.remainingDoses, d.totalDoses), borderRadius: BorderRadius.circular(20)),
                                child: Center(child: Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Device cards
                    if (active.isEmpty)
                      const EmptyState(title: 'No containers yet', subtitle: 'Tap + to enroll your first peptide pen or vial', icon: Icons.science_outlined)
                    else
                      ...active.map((device) => DeviceCard(
                        device: device,
                        onTap: () => _openDetail(context, ref, device),
                        onLogTap: () => _openLog(context, ref, device),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNfcScan(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NfcScanModal(
        onManualLog: (device) => _openLog(context, ref, device),
      ),
    );
  }

  void _openLog(BuildContext context, WidgetRef ref, Device device) {
    if (device.remainingDoses <= 0) return; // depleted
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogDoseModal(
        device: device,
        onNfcScan: () => _openNfcScan(context, ref),
      ),
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

// ── NFC Scan Button ────────────────────────────────────────────
class _NfcScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NfcScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.nfc_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan NFC to Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Hold container near phone to record dose', style: TextStyle(fontSize: 12, color: Color(0xBFFFFFFF))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xBFFFFFFF)),
          ],
        ),
      ),
    );
  }
}

// ── Alert Banner ───────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final List<Device> devices;
  const _AlertBanner({required this.devices});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber, width: 0.5),
      ),
      child: Row(
        children: [
          const Text('!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.amber)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${devices.map((d) => d.name).join(', ')} running low',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.amberDark),
            ),
          ),
        ],
      ),
    );
  }
}
