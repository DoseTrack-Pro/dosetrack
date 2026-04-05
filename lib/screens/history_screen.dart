import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/dose_log.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import '../widgets/empty_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final logs = ref.watch(doseLogsProvider);
    final adherence = calcAdherence(ref.watch(activeDevicesProvider), logs);
    final streak = calcStreak(logs);

    // Group logs by display date
    final groups = <String, List<DoseLog>>{};
    for (final log in logs) {
      final key = formatLogDate(log.loggedAt);
      groups.putIfAbsent(key, () => []).add(log);
    }
    final groupKeys = groups.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: const Row(
                children: [
                  Text('History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Summary cards
                  Row(children: [
                    _SummaryCard(value: '${logs.length}', label: 'Total doses'),
                    const SizedBox(width: 10),
                    _SummaryCard(value: '$adherence%', label: 'Adherence'),
                    const SizedBox(width: 10),
                    _SummaryCard(value: '${streak}d', label: 'Streak'),
                  ]),
                  const SizedBox(height: 20),

                  if (logs.isEmpty)
                    const EmptyState(
                      title: 'No doses logged yet',
                      subtitle: 'Log your first dose from the Dashboard',
                      icon: Icons.history_rounded,
                    )
                  else
                    ...groupKeys.map((key) {
                      final entries = groups[key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(key.toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary, letterSpacing: 0.7)),
                          const SizedBox(height: 8),
                          ...entries.map((log) {
                            final device = devices.where((d) => d.id == log.deviceId).firstOrNull;
                            final color = device != null
                                ? doseColor(device.remainingDoses, device.totalDoses)
                                : AppColors.teal;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(device?.name ?? 'Unknown',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        Text('${formatLogTime(log.loggedAt)}  ·  ${log.method.name == 'nfc' ? 'NFC' : 'Manual'}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${log.doseMcg.toStringAsFixed(0)}mcg',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary, fontFamily: 'Courier New')),
                                      Text('${log.doseIu.toStringAsFixed(0)}IU',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Courier New')),
                                    ],
                                  ),
                                ],
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Courier New')),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
