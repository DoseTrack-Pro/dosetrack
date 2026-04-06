import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/dose_log.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import '../widgets/empty_state.dart';
import '../modals/dose_detail_modal.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedDeviceId; // null = all

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final allLogs = ref.watch(doseLogsProvider);
    final adherence = calcAdherence(ref.watch(activeDevicesProvider), allLogs);
    final streak = calcStreak(allLogs);

    // Filter logs by selected compound
    final logs = _selectedDeviceId == null
        ? allLogs
        : allLogs.where((l) => l.deviceId == _selectedDeviceId).toList();

    // Group by display date
    final groups = <String, List<DoseLog>>{};
    for (final log in logs) {
      final key = formatLogDate(log.loggedAt);
      groups.putIfAbsent(key, () => []).add(log);
    }
    final groupKeys = groups.keys.toList();

    // Devices that have logs (for filter chips)
    final deviceIds = allLogs.map((l) => l.deviceId).toSet();
    final loggedDevices = devices.where((d) => deviceIds.contains(d.id)).toList();

    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(children: [
                Text('History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.clrText)),
              ]),
            ),
            // Compound filter chips
            if (loggedDevices.length > 1)
              Container(
                color: context.clrSurface,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      _FilterChip(label: 'All', active: _selectedDeviceId == null,
                          onTap: () => setState(() => _selectedDeviceId = null)),
                      ...loggedDevices.map((d) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: d.name,
                          active: _selectedDeviceId == d.id,
                          onTap: () => setState(() => _selectedDeviceId = d.id),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Summary cards
                  Row(children: [
                    _SummaryCard(value: '${allLogs.length}', label: 'Total doses'),
                    const SizedBox(width: 10),
                    _SummaryCard(value: '$adherence%', label: 'Adherence'),
                    const SizedBox(width: 10),
                    _SummaryCard(value: '${streak}d', label: 'Streak'),
                  ]),
                  const SizedBox(height: 20),

                  if (logs.isEmpty)
                    const EmptyState(title: 'No doses logged yet', subtitle: 'Log your first dose from the Dashboard', icon: Icons.history_rounded)
                  else
                    ...groupKeys.map((key) {
                      final entries = groups[key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(key.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.clrTextSub, letterSpacing: 0.7)),
                          const SizedBox(height: 8),
                          ...entries.map((log) {
                            final device = devices.where((d) => d.id == log.deviceId).firstOrNull;
                            final color = device != null
                                ? doseColor(device.remainingDoses, device.totalDoses)
                                : AppColors.teal;
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => DoseDetailPage(log: log, device: device),
                              )),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(
                                  color: context.clrSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: context.clrBorder, width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(device?.name ?? 'Unknown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.clrText)),
                                          Row(children: [
                                            Text('${formatLogTime(log.loggedAt)}  ·  ${log.method.name == 'nfc' ? 'NFC' : 'Manual'}',
                                                style: TextStyle(fontSize: 12, color: context.clrTextSub)),
                                            if (log.injectionSite != null) ...[
                                              Text('  ·  ', style: TextStyle(fontSize: 12, color: context.clrTextHint)),
                                              Flexible(child: Text(log.injectionSite!,
                                                  style: TextStyle(fontSize: 12, color: context.clrTextHint),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ]),
                                          if (log.notes != null) ...[
                                            const SizedBox(height: 3),
                                            Text(log.notes!,
                                                style: TextStyle(fontSize: 12, color: context.clrTextSub, fontStyle: FontStyle.italic, height: 1.3),
                                                maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${log.doseMcg.toStringAsFixed(0)}mcg',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.clrText, fontFamily: 'Courier New')),
                                        Text('${log.doseIu.toStringAsFixed(1)}IU',
                                            style: TextStyle(fontSize: 11, color: context.clrTextSub, fontFamily: 'Courier New')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 14),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? context.clrTealBg : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.teal : context.clrBorder, width: active ? 1 : 0.5),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: active ? AppColors.tealDark : context.clrTextSub,
      ),
      maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  const _SummaryCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: context.clrSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.clrBorder, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: context.clrText, fontFamily: 'Courier New'))),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, color: context.clrTextSub),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
