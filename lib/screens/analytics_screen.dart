import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _rangeDays = 14; // 14, 30, or 90

  static const _deviceColors = [
    AppColors.teal, AppColors.purple, AppColors.blue, AppColors.amber, AppColors.red,
  ];

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeDevicesProvider);
    final logs = ref.watch(doseLogsProvider);
    final adherence = calcAdherence(active, logs);
    final streak = calcStreak(logs);
    final days = List.generate(_rangeDays, (i) => DateTime.now().subtract(Duration(days: _rangeDays - 1 - i)));

    final missed = active
        .where((d) => d.schedule == DoseSchedule.dailyAm || d.schedule == DoseSchedule.dailyPm)
        .length * _rangeDays -
        logs.where((l) => l.loggedAt.isAfter(DateTime.now().subtract(Duration(days: _rangeDays)))).length;

    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(children: [
                Text('Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.clrText)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Date range selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [14, 30, 90].map((d) {
                      final active = _rangeDays == d;
                      return GestureDetector(
                        onTap: () => setState(() => _rangeDays = d),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? AppColors.teal : context.clrSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? AppColors.teal : context.clrBorder, width: active ? 1.5 : 0.5),
                          ),
                          child: Text('${d}d', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: active ? Colors.white : context.clrTextSub,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // KPI grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.8,
                    children: [
                      _KpiCard(value: '$adherence%', label: 'Adherence rate', color: AppColors.teal, context: context),
                      _KpiCard(value: '${logs.length}', label: 'Total doses', color: AppColors.purple, context: context),
                      _KpiCard(value: '${streak}d', label: 'Day streak', color: AppColors.blue, context: context),
                      _KpiCard(value: '${missed.clamp(0, 999)}', label: 'Missed doses', color: AppColors.amber, context: context),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (active.isNotEmpty) ...[
                    // Line chart
                    _SectionCard(
                      title: 'Daily doses — last ${_rangeDays}d',
                      legend: active.take(4).toList().asMap().entries.map((e) =>
                          _LegendItem(label: e.value.name, color: _deviceColors[e.key % _deviceColors.length])
                      ).toList(),
                      child: SizedBox(
                        height: 180,
                        child: ClipRect(child: LineChart(_buildLineChart(active.take(4).toList(), logs, days))),
                      ),
                      context: context,
                    ),
                    const SizedBox(height: 16),

                    // Usage bar chart
                    _SectionCard(
                      title: 'Compound usage',
                      legend: const [
                        _LegendItem(label: 'Remaining', color: AppColors.teal),
                        _LegendItem(label: 'Used', color: Color(0xFF94A3B8)),
                      ],
                      child: SizedBox(height: 220, child: BarChart(_buildBarChart(active))),
                      context: context,
                    ),
                    const SizedBox(height: 16),

                    // Per-compound breakdown
                    _SectionCard(
                      title: 'Compound breakdown',
                      context: context,
                      child: Column(
                        children: active.take(5).toList().asMap().entries.map((e) {
                          final device = e.value;
                          final color = _deviceColors[e.key % _deviceColors.length];
                          final totalLogged = logs.where((l) => l.deviceId == device.id).length;
                          final pct = device.remainingPct;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(device.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.clrText))),
                                  Text('$totalLogged doses', style: TextStyle(fontSize: 12, color: context.clrTextSub)),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(value: 1 - pct, backgroundColor: context.clrBorder,
                                    valueColor: AlwaysStoppedAnimation(color), minHeight: 4),
                                ),
                                const SizedBox(height: 3),
                                Text('${(pct * 100).round()}% remaining', style: TextStyle(fontSize: 11, color: context.clrTextHint)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _AdherenceByCompoundCard(devices: active, logs: logs),
                    const SizedBox(height: 16),
                    _ProjectedDepletionCard(devices: active, logs: logs),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChart(List<Device> devices, List<DoseLog> logs, List<DateTime> days) {
    final fmt = DateFormat('M/d');
    double maxCount = 2;
    for (final device in devices) {
      for (final day in days) {
        final count = logs.where((l) =>
          l.deviceId == device.id &&
          l.loggedAt.year == day.year &&
          l.loggedAt.month == day.month &&
          l.loggedAt.day == day.day,
        ).length.toDouble();
        if (count > maxCount) maxCount = count;
      }
    }
    final maxY = (maxCount + 1).ceilToDouble();
    final double interval = days.length > 14 ? (days.length / 6).ceil().toDouble() : 4;

    return LineChartData(
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: context.clrBorder, strokeWidth: 0.5),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22,
          getTitlesWidget: (v, _) => v == v.roundToDouble()
              ? Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: context.clrTextHint))
              : const SizedBox.shrink(),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 22, interval: interval,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= days.length) return const SizedBox.shrink();
            return Text(fmt.format(days[i]), style: TextStyle(fontSize: 9, color: context.clrTextHint));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      minY: 0, maxY: maxY,
      lineBarsData: devices.asMap().entries.map((e) {
        final device = e.value;
        final color = _deviceColors[e.key % _deviceColors.length];
        final spots = days.asMap().entries.map((de) {
          final count = logs.where((l) =>
            l.deviceId == device.id &&
            l.loggedAt.year == de.value.year &&
            l.loggedAt.month == de.value.month &&
            l.loggedAt.day == de.value.day,
          ).length;
          return FlSpot(de.key.toDouble(), count.toDouble());
        }).toList();
        return LineChartBarData(
          spots: spots, color: color, barWidth: 2, isCurved: true, curveSmoothness: 0.3,
          dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
            FlDotCirclePainter(radius: 2.5, color: color, strokeWidth: 0)),
          belowBarData: BarAreaData(show: false),
        );
      }).toList(),
    );
  }

  BarChartData _buildBarChart(List<Device> devices) {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: devices.fold<double>(0, (m, d) => d.totalDoses.toDouble() > m ? d.totalDoses.toDouble() : m) * 1.1,
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: context.clrBorder, strokeWidth: 0.5),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: context.clrTextHint)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i >= devices.length) return const SizedBox.shrink();
            final name = devices[i].name;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(name.length > 6 ? '${name.substring(0, 6)}..' : name,
                style: TextStyle(fontSize: 9, color: context.clrTextHint)),
            );
          },
        )),
      ),
      barGroups: devices.asMap().entries.map((e) {
        final d = e.value;
        final remaining = d.remainingDoses.toDouble();
        final total = d.totalDoses.toDouble();
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: total, width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: [
              BarChartRodStackItem(0, remaining, AppColors.teal),
              BarChartRodStackItem(remaining, total, const Color(0xFF94A3B8)),
            ],
          ),
        ]);
      }).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String value, label;
  final Color color;
  final BuildContext context;
  const _KpiCard({required this.value, required this.label, required this.color, required this.context});

  @override
  Widget build(BuildContext _) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: context.clrSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.clrBorder, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color, fontFamily: 'Courier New'))),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, color: context.clrTextSub), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> legend;
  final Widget child;
  final BuildContext context;
  const _SectionCard({required this.title, this.legend = const [], required this.child, required this.context});

  @override
  Widget build(BuildContext _) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.clrSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.clrBorder, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.clrText)),
        if (legend.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 16, children: legend)],
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: context.clrTextSub)),
    ],
  );
}

// ── Adherence by Compound ────────────────────────────────��─────
class _AdherenceByCompoundCard extends StatelessWidget {
  final List<Device> devices;
  final List<DoseLog> logs;
  const _AdherenceByCompoundCard({required this.devices, required this.logs});

  Color _adherenceColor(int pct) {
    if (pct >= 80) return AppColors.teal;
    if (pct >= 50) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final trackable = devices.where((d) => d.schedule != DoseSchedule.custom).toList();
    if (trackable.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Adherence by compound',
      context: context,
      child: Column(
        children: trackable.take(5).map((device) {
          final pct = calcDeviceAdherence(device, logs);
          final color = _adherenceColor(pct);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(device.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.clrText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: pct / 100, backgroundColor: context.clrBorder,
                  valueColor: AlwaysStoppedAnimation(color), minHeight: 4)),
              const SizedBox(height: 3),
              Text(device.schedule.label, style: TextStyle(fontSize: 11, color: context.clrTextHint)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Projected Depletion ────────────────────────────────────────
class _ProjectedDepletionCard extends StatelessWidget {
  final List<Device> devices;
  final List<DoseLog> logs;
  const _ProjectedDepletionCard({required this.devices, required this.logs});

  @override
  Widget build(BuildContext context) {
    final projections = devices
        .where((d) => d.remainingDoses > 0)
        .map((d) => (device: d, date: calcProjectedDepletion(d, logs)))
        .where((p) => p.date != null)
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    if (projections.isEmpty) return const SizedBox.shrink();

    final fmt = DateFormat('MMM d');
    final now = DateTime.now();

    return _SectionCard(
      title: 'Projected depletion',
      context: context,
      child: Column(
        children: projections.take(5).map((p) {
          final daysLeft = p.date!.difference(now).inDays;
          final Color color;
          if (daysLeft <= 7) {
            color = AppColors.red;
          } else if (daysLeft <= 14) {
            color = AppColors.amber;
          } else {
            color = AppColors.teal;
          }
          final dateLabel = daysLeft == 0 ? 'Today' : daysLeft == 1 ? 'Tomorrow' : fmt.format(p.date!);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(p.device.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.clrText), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${p.device.remainingDoses} doses left', style: TextStyle(fontSize: 12, color: context.clrTextSub)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('~$dateLabel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}
