import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  static const _deviceColors = [
    AppColors.teal,
    AppColors.purple,
    AppColors.blue,
    AppColors.amber,
    AppColors.red,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDevicesProvider);
    final logs = ref.watch(doseLogsProvider);
    final adherence = calcAdherence(active, logs);
    final streak = calcStreak(logs);
    final days = getLast14Days();

    final missed = active
        .where((d) => d.schedule == DoseSchedule.dailyAm || d.schedule == DoseSchedule.dailyPm)
        .length * 14 - logs.where((l) => l.loggedAt.isAfter(DateTime.now().subtract(const Duration(days: 14)))).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: const Row(children: [
                Text('Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // KPI grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.8,
                    children: [
                      _KpiCard(value: '$adherence%', label: 'Adherence rate', color: AppColors.teal),
                      _KpiCard(value: '${logs.length}', label: 'Total doses', color: AppColors.purple),
                      _KpiCard(value: '${streak}d', label: 'Day streak', color: AppColors.blue),
                      _KpiCard(value: '${missed.clamp(0, 999)}', label: 'Missed doses', color: AppColors.amber),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Line chart — daily doses
                  if (active.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Daily doses — last 14 days',
                      legend: active.take(4).toList().asMap().entries.map((e) =>
                          _LegendItem(label: e.value.name, color: _deviceColors[e.key % _deviceColors.length])
                      ).toList(),
                      child: SizedBox(
                        height: 180,
                        child: LineChart(_buildLineChart(active.take(4).toList(), logs, days)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Usage bar chart
                    _SectionCard(
                      title: 'Container usage',
                      legend: const [
                        _LegendItem(label: 'Used', color: AppColors.teal),
                        _LegendItem(label: 'Remaining', color: AppColors.tealMid),
                      ],
                      child: SizedBox(
                        height: 220,
                        child: BarChart(_buildBarChart(active)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Per-compound breakdown
                    _SectionCard(
                      title: 'Compound breakdown',
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
                                  Expanded(child: Text(device.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                  Text('$totalLogged doses', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: 1 - pct,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation(color),
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text('${(pct * 100).round()}% remaining', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
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
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          getTitlesWidget: (v, _) => v == v.roundToDouble()
              ? Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textTertiary))
              : const SizedBox.shrink(),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 4,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= days.length) return const SizedBox.shrink();
            return Text(fmt.format(days[i]), style: const TextStyle(fontSize: 9, color: AppColors.textTertiary));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      minY: 0, maxY: 2,
      lineBarsData: devices.asMap().entries.map((e) {
        final device = e.value;
        final color = [AppColors.teal, AppColors.purple, AppColors.blue, AppColors.amber][e.key % 4];
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
          spots: spots,
          color: color,
          barWidth: 2,
          isCurved: true,
          curveSmoothness: 0.3,
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
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
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
                style: const TextStyle(fontSize: 9, color: AppColors.textTertiary)),
            );
          },
        )),
      ),
      barGroups: devices.asMap().entries.map((e) {
        final d = e.value;
        final used = (d.totalDoses - d.remainingDoses).toDouble();
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: d.totalDoses.toDouble(),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: [
              BarChartRodStackItem(0, used, AppColors.teal),
              BarChartRodStackItem(used, d.totalDoses.toDouble(), AppColors.tealMid),
            ],
          ),
        ]);
      }).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _KpiCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: color, fontFamily: 'Courier New',
          )),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> legend;
  final Widget child;
  const _SectionCard({required this.title, this.legend = const [], required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        if (legend.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 16, children: legend),
        ],
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
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ],
  );
}
