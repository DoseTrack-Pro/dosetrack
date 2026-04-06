import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/device.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dose_ring.dart';
import '../utils/calculations.dart';
import 'edit_device_modal.dart';

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
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: context.clrText,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(liveDevice.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.clrText)),
                    Text('${liveDevice.vendor} · ${liveDevice.batchNumber}', style: TextStyle(fontSize: 12, color: context.clrTextSub)),
                  ])),
                  // F2: Edit button
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EditDevicePage(device: liveDevice),
                    )),
                    child: const Text('Edit', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
                  ),
                  if (!liveDevice.active)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Archived', style: TextStyle(fontSize: 13, color: context.clrTextHint, fontWeight: FontWeight.w600)),
                    )
                  else
                    TextButton(
                      onPressed: () => _archive(context, ref),
                      child: Text(
                        liveDevice.type == ContainerType.pen ? 'Archive Pen' : 'Archive Vial',
                        style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  // Ring
                  Container(
                    color: context.clrSurface,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(children: [
                      DoseRing(remaining: liveDevice.remainingDoses, total: liveDevice.totalDoses, size: 140, strokeWidth: 10),
                      const SizedBox(height: 12),
                      if (liveDevice.remainingDoses <= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: context.clrBorder,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Depleted',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: context.clrTextHint, letterSpacing: 0.3)),
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
                          Expanded(child: _InfoTile('Dose vol', '${liveDevice.doseVolumeIu.toStringAsFixed(1)} IU')),
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
                        color: context.clrSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.clrBorder, width: 0.5),
                      ),
                      child: Column(children: [
                        _MetaRow('Type', liveDevice.type == ContainerType.pen ? 'Injectable Pen' : 'Vial'),
                        Divider(height: 0, color: context.clrBorder),
                        _MetaRow('NFC tag', liveDevice.nfcTagId != null ? 'Enrolled' : 'Not enrolled'),
                        Divider(height: 0, color: context.clrBorder),
                        _MetaRow('Reconstituted', liveDevice.reconstitutionDate),
                        Divider(height: 0, color: context.clrBorder),
                        _MetaRow('Alert at', '${liveDevice.alertThresholdPct}% remaining'),
                        // F3: COA URL tappable
                        if (liveDevice.coaUrl != null && liveDevice.coaUrl!.isNotEmpty) ...[
                          Divider(height: 0, color: context.clrBorder),
                          _CoaRow(url: liveDevice.coaUrl!),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recent doses
                  if (logs.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text('Recent doses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.clrText)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.clrSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.clrBorder, width: 0.5),
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
                                        style: TextStyle(fontSize: 13, color: context.clrText)),
                                    Text(log.method.name == 'nfc' ? 'NFC' : 'Manual',
                                        style: TextStyle(fontSize: 12, color: context.clrTextSub)),
                                  ])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('${log.doseMcg.toStringAsFixed(0)}mcg',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                            color: context.clrText, fontFamily: 'Courier New')),
                                    Text('${log.doseIu.toStringAsFixed(1)}IU',
                                        style: TextStyle(fontSize: 11, color: context.clrTextSub, fontFamily: 'Courier New')),
                                  ]),
                                ]),
                              ),
                              if (i < logs.length - 1) Divider(height: 0, indent: 16, color: context.clrBorder),
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
        decoration: BoxDecoration(
          color: context.clrSurface,
          border: Border(top: BorderSide(color: context.clrBorder, width: 0.5)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: liveDevice.remainingDoses <= 0
            ? Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                )),
                if (liveDevice.active) ...[
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(
                    onPressed: () => _archive(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(liveDevice.type == ContainerType.pen ? 'Archive Pen' : 'Archive Vial'),
                  )),
                ],
              ])
            : Row(children: [
                if (liveDevice.nfcTagId != null) ...[
                  Expanded(child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); onLogNfc(); },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
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
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
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
        backgroundColor: context.clrSurface,
        title: Text('Archive Compound', style: TextStyle(color: context.clrText)),
        content: Text('Archive ${device.name}? This will mark it as depleted and cancel reminders.',
            style: TextStyle(color: context.clrTextSub)),
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

class _CoaRow extends StatelessWidget {
  final String url;
  const _CoaRow({required this.url});

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _open,
    borderRadius: const BorderRadius.only(
      bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Expanded(child: Text('COA', style: TextStyle(fontSize: 13, color: context.clrTextSub))),
        Flexible(child: Text(url,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blue),
          textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
        const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.blue),
      ]),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: context.clrSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.clrBorder, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.clrTextSub),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: context.clrText, fontFamily: 'Courier New')),
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
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: context.clrTextSub))),
      Flexible(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.clrText),
          textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}
