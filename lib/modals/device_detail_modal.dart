import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dose_ring.dart';
import '../widgets/badge_chip.dart';
import '../utils/calculations.dart';

class DeviceDetailPage extends ConsumerWidget {
  final Device device;
  final VoidCallback onLogManual;
  final VoidCallback onLogNfc;

  const DeviceDetailPage({
    super.key,
    required this.device,
    required this.onLogManual,
    required this.onLogNfc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch live device so remaining doses update after logging
    final liveDevice = ref.watch(devicesProvider)
        .where((d) => d.id == device.id)
        .firstOrNull ?? device;

    final logs = ref.watch(doseLogsProvider)
        .where((l) => l.deviceId == device.id)
        .take(5)
        .toList();

    final color = doseColor(liveDevice.remainingDoses, liveDevice.totalDoses);
    final pct = liveDevice.remainingPct;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(liveDevice.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${liveDevice.vendor} · ${liveDevice.batchNumber}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ])),
                  TextButton(
                    onPressed: () => _archive(context, ref),
                    child: const Text('Archive', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  // Ring
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(children: [
                      DoseRing(remaining: liveDevice.remainingDoses, total: liveDevice.totalDoses, size: 140, strokeWidth: 10),
                      const SizedBox(height: 12),
                      if (liveDevice.remainingDoses <= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Depleted',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary, letterSpacing: 0.3)),
                        )
                      else
                        Text('${(pct * 100).round()}% remaining',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Info grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Expanded(child: _InfoTile('Peptide', '${liveDevice.peptideMg}mg')),
                          const SizedBox(width: 8),
                          Expanded(child: _InfoTile('Recon vol', '${liveDevice.reconVolumeMl}mL')),
                          const SizedBox(width: 8),
                          Expanded(child: _InfoTile('Dose', '${liveDevice.desiredDoseMcg.toStringAsFixed(0)}mcg')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _InfoTile('Dose vol', '${liveDevice.doseVolumeIu.toStringAsFixed(0)} IU')),
                          const SizedBox(width: 8),
                          Expanded(child: _InfoTile('Total', '${liveDevice.totalDoses} doses')),
                          const SizedBox(width: 8),
                          Expanded(child: _InfoTile('Schedule', liveDevice.schedule.label.split(' ').first)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Meta table
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Column(children: [
                        _MetaRow('Type', liveDevice.type == ContainerType.pen ? 'Injectable Pen' : 'Vial'),
                        const Divider(height: 0),
                        _MetaRow('NFC tag', liveDevice.nfcTagId != null ? 'Enrolled' : 'Not enrolled'),
                        const Divider(height: 0),
                        _MetaRow('Reconstituted', liveDevice.reconstitutionDate),
                        const Divider(height: 0),
                        _MetaRow('Alert at', '${liveDevice.alertThresholdPct}% remaining'),
                        if (liveDevice.coaUrl != null) ...[
                          const Divider(height: 0),
                          _MetaRow('COA', liveDevice.coaUrl!),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recent doses
                  if (logs.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text('Recent doses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Column(
                          children: logs.indexed.map((entry) {
                            final i = entry.$1;
                            final log = entry.$2;
                            return Column(children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${formatLogDate(log.loggedAt)}  ·  ${formatLogTime(log.loggedAt)}',
                                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                    Text(log.method.name == 'nfc' ? 'NFC' : 'Manual',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('${log.doseMcg.toStringAsFixed(0)}mcg',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary, fontFamily: 'Courier New')),
                                    Text('${log.doseIu.toStringAsFixed(0)}IU',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Courier New')),
                                  ]),
                                ]),
                              ),
                              if (i < logs.length - 1) const Divider(height: 0, indent: 16),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom action bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: liveDevice.remainingDoses <= 0
            ? Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () => _archive(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Archive Container'),
                )),
              ])
            : Row(children: [
                if (liveDevice.nfcTagId != null) ...[
                  Expanded(child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); onLogNfc(); },
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    child: const Text('Log via NFC'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(
                    onPressed: () { Navigator.pop(context); onLogManual(); },
                    child: const Text('Log Manual'),
                  )),
                ] else
                  Expanded(child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); onLogManual(); },
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    child: const Text('Log Dose'),
                  )),
              ]),
      ),
    );
  }

  void _archive(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive Container'),
        content: Text('Archive ${device.name}? This will mark it as depleted and cancel reminders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(appProvider.notifier).archiveDevice(device.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Courier New')),
        ),
      ],
    ),
  );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      Flexible(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}
