import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dose_ring.dart';
import '../utils/calculations.dart';

class LogDoseModal extends ConsumerWidget {
  final Device device;
  final VoidCallback? onNfcScan;

  const LogDoseModal({super.key, required this.device, this.onNfcScan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depleted = device.remainingDoses <= 0;
    final color = depleted ? AppColors.textTertiary : doseColor(device.remainingDoses, device.totalDoses);
    final pct = device.remainingPct;

    Future<void> confirm() async {
      if (depleted) return;
      await ref.read(appProvider.notifier).logDose(device.id, LogMethod.manual);
      if (context.mounted) Navigator.pop(context);
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),

              Text(device.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('${device.type.name[0].toUpperCase()}${device.type.name.substring(1)}  ·  ${device.vendor}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),

              // Ring + stats
              Row(
                children: [
                  DoseRing(remaining: device.remainingDoses, total: device.totalDoses, size: 120, strokeWidth: 8),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Expanded(child: _StatCard(label: 'Dose', value: '${device.desiredDoseMcg.toStringAsFixed(0)}mcg')),
                          const SizedBox(width: 8),
                          Expanded(child: _StatCard(label: 'Volume', value: '${device.doseVolumeIu.toStringAsFixed(0)} IU')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _StatCard(label: 'Remaining', value: '${(pct * 100).round()}%')),
                          const SizedBox(width: 8),
                          Expanded(child: _StatCard(label: 'Schedule', value: device.schedule.label)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // NFC switch option
              if (device.nfcTagId != null && onNfcScan != null)
                GestureDetector(
                  onTap: () { Navigator.pop(context); onNfcScan!(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.blueMid, width: 0.5),
                    ),
                    child: const Row(children: [
                      Icon(Icons.nfc_rounded, color: AppColors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Log via NFC instead', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blueDark)),
                        Text('Tap to open NFC scanner', style: TextStyle(fontSize: 11, color: AppColors.blue)),
                      ])),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.blue, size: 14),
                    ]),
                  ),
                ),
              if (device.nfcTagId != null && onNfcScan != null) const SizedBox(height: 14),

              if (depleted) ...[
                // Depleted status pill
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                ]),
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
                    onPressed: confirm,
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    child: const Text('Confirm Dose Logged'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}
