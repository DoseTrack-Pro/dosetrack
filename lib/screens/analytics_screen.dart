import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _rangeDays = 14;
  String? _consistencyDeviceId;
  _ScorecardSort _scorecardSort = _ScorecardSort.risk;

  static const _rangeOptions = [7, 14, 30, 90];

  @override
  Widget build(BuildContext context) {
    final activeDevices = ref.watch(activeDevicesProvider);
    final logs = ref.watch(doseLogsProvider);
    final now = DateTime.now();
    final rangeStart =
        _startOfDay(now.subtract(Duration(days: _rangeDays - 1)));
    final rangeEnd = _startOfDay(now);
    final previousRangeEnd = rangeStart.subtract(const Duration(days: 1));
    final previousRangeStart =
        previousRangeEnd.subtract(Duration(days: _rangeDays - 1));
    final rangeLogs = logs
        .where((l) => !_startOfDay(l.loggedAt).isBefore(rangeStart))
        .toList();

    final adherence = calcAdherenceForDays(activeDevices, logs, _rangeDays);
    final loggedCount = rangeLogs.length;
    final missedCount = calcMissedDosesForDays(activeDevices, logs, _rangeDays);
    final streak = calcStreak(logs);
    final consistencyDeviceIds = activeDevices.map((d) => d.id).toSet();
    if (_consistencyDeviceId != null &&
        !consistencyDeviceIds.contains(_consistencyDeviceId)) {
      _consistencyDeviceId = null;
    }

    final dailyStatuses = _buildConsistencyStatuses(
      activeDevices: activeDevices,
      logs: logs,
      start: rangeStart,
      days: _rangeDays,
      deviceId: _consistencyDeviceId,
    );
    final actionItems = _buildActionItems(
      activeDevices: activeDevices,
      logs: logs,
      now: now,
    );
    final scorecards = _buildScorecards(
      activeDevices: activeDevices,
      logs: logs,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      previousRangeStart: previousRangeStart,
      previousRangeEnd: previousRangeEnd,
    );
    final sortedScorecards = _sortScorecards(scorecards);
    final projections = _buildInventoryOutlook(
      activeDevices: activeDevices,
      logs: logs,
      now: now,
    );
    final siteStats = _buildSiteStats(rangeLogs);

    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              color: context.clrSurface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.clrText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Insights for selected period',
                    style: TextStyle(fontSize: 12, color: context.clrTextSub),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _RangeSelector(
                    selectedDays: _rangeDays,
                    onChanged: (days) => setState(() => _rangeDays = days),
                  ),
                  const SizedBox(height: 16),
                  if (actionItems.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Action needed',
                      context: context,
                      child: Column(
                        children: actionItems
                            .map((item) => _ActionItemRow(item: item))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _KpiSummary(
                    adherence: adherence,
                    loggedCount: loggedCount,
                    missedCount: missedCount,
                    streak: streak,
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Consistency calendar',
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeDevices.isNotEmpty) ...[
                          _ConsistencyFilterRow(
                            devices: activeDevices,
                            selectedDeviceId: _consistencyDeviceId,
                            onChanged: (v) =>
                                setState(() => _consistencyDeviceId = v),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _ConsistencyLegend(context: context),
                        const SizedBox(height: 10),
                        if (dailyStatuses.isEmpty)
                          Text(
                            'No schedule-based data in this period.',
                            style: TextStyle(
                                fontSize: 12, color: context.clrTextHint),
                          )
                        else
                          _ConsistencyGrid(statuses: dailyStatuses),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Compound scorecards',
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScorecardSortRow(
                          selected: _scorecardSort,
                          onChanged: (v) => setState(() => _scorecardSort = v),
                        ),
                        const SizedBox(height: 12),
                        if (sortedScorecards.isEmpty)
                          Text(
                            'No active compounds to analyze.',
                            style: TextStyle(
                                fontSize: 12, color: context.clrTextHint),
                          )
                        else
                          ...sortedScorecards
                              .map((entry) => _CompoundScorecard(entry: entry)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Inventory outlook',
                    context: context,
                    child: projections.isEmpty
                        ? Text(
                            'No active compounds with remaining doses.',
                            style: TextStyle(
                                fontSize: 12, color: context.clrTextHint),
                          )
                        : Column(
                            children: projections
                                .map((p) => _InventoryOutlookRow(item: p))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Site rotation insight',
                    context: context,
                    child: siteStats == null
                        ? Text(
                            'Log injection sites to unlock rotation insights.',
                            style: TextStyle(
                                fontSize: 12, color: context.clrTextHint),
                          )
                        : _SiteInsightContent(stats: siteStats),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ActionItem> _buildActionItems({
    required List<Device> activeDevices,
    required List<DoseLog> logs,
    required DateTime now,
  }) {
    final items = <_ActionItem>[];
    final today = _startOfDay(now);
    final weekStart = today.subtract(const Duration(days: 6));

    final missedDevices = <Device>[];
    for (final device in activeDevices) {
      var missedDays = 0;
      for (int i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: i));
        if (!isScheduledOnDate(device, day)) continue;
        if (day.isBefore(weekStart)) continue;
        final hasLog = logs
            .any((l) => l.deviceId == device.id && _isSameDay(l.loggedAt, day));
        if (!hasLog) missedDays++;
      }
      if (missedDays > 0) missedDevices.add(device);
    }
    if (missedDevices.isNotEmpty) {
      items.add(
        _ActionItem(
          icon: Icons.event_busy_rounded,
          color: AppColors.red,
          text:
              '${missedDevices.length} compound(s) missed scheduled doses this week',
        ),
      );
    }

    final lowStockDevices = activeDevices.where((d) {
      final pct = (d.remainingPct * 100);
      final projected = calcProjectedDepletion(d, logs);
      final daysLeft = projected?.difference(now).inDays ?? 9999;
      return pct <= d.alertThresholdPct || daysLeft <= 14;
    }).toList();
    if (lowStockDevices.isNotEmpty) {
      items.add(
        _ActionItem(
          icon: Icons.inventory_2_rounded,
          color: AppColors.amber,
          text:
              '${lowStockDevices.length} compound(s) need refill planning soon',
        ),
      );
    }

    final staleDevices = activeDevices.where((d) {
      final deviceLogs = logs.where((l) => l.deviceId == d.id).toList();
      if (deviceLogs.isEmpty) return true;
      deviceLogs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      final days =
          today.difference(_startOfDay(deviceLogs.first.loggedAt)).inDays;
      return days >= 7;
    }).toList();
    if (staleDevices.isNotEmpty) {
      items.add(
        _ActionItem(
          icon: Icons.schedule_rounded,
          color: AppColors.blue,
          text: '${staleDevices.length} compound(s) have no logs in 7+ days',
        ),
      );
    }
    return items;
  }

  List<_ConsistencyDayStatus> _buildConsistencyStatuses({
    required List<Device> activeDevices,
    required List<DoseLog> logs,
    required DateTime start,
    required int days,
    required String? deviceId,
  }) {
    final devices = deviceId == null
        ? activeDevices
        : activeDevices.where((d) => d.id == deviceId).toList();
    if (devices.isEmpty) return const [];

    final statuses = <_ConsistencyDayStatus>[];
    for (int i = 0; i < days; i++) {
      final date = _startOfDay(start.add(Duration(days: i)));
      int expected = 0;
      int loggedCount = 0;
      for (final device in devices) {
        final isTrackable = device.schedule != DoseSchedule.custom ||
            effectiveScheduleDays(device).isNotEmpty;
        if (!isTrackable || !isScheduledOnDate(device, date)) continue;
        expected++;
        final hasLog = logs.any(
            (l) => l.deviceId == device.id && _isSameDay(l.loggedAt, date));
        if (hasLog) loggedCount++;
      }

      final status = expected == 0
          ? _ConsistencyStatus.notScheduled
          : loggedCount == 0
              ? _ConsistencyStatus.missed
              : loggedCount < expected
                  ? _ConsistencyStatus.partial
                  : _ConsistencyStatus.onTrack;
      statuses.add(_ConsistencyDayStatus(
        date: date,
        status: status,
        expected: expected,
        logged: loggedCount,
      ));
    }
    return statuses;
  }

  List<_CompoundScoreEntry> _buildScorecards({
    required List<Device> activeDevices,
    required List<DoseLog> logs,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime previousRangeStart,
    required DateTime previousRangeEnd,
  }) {
    final entries = <_CompoundScoreEntry>[];
    for (final device in activeDevices) {
      final current = _deviceRangeMetrics(device, logs, rangeStart, rangeEnd);
      final previous = _deviceRangeMetrics(
          device, logs, previousRangeStart, previousRangeEnd);

      final deviceLogs = logs.where((l) => l.deviceId == device.id).toList();
      deviceLogs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      final lastLoggedAt =
          deviceLogs.isEmpty ? null : deviceLogs.first.loggedAt;

      final trend =
          (current.adherencePct != null && previous.adherencePct != null)
              ? current.adherencePct! - previous.adherencePct!
              : null;
      entries.add(
        _CompoundScoreEntry(
          device: device,
          adherencePct: current.adherencePct,
          missed: current.missed,
          lastLoggedAt: lastLoggedAt,
          trendDelta: trend,
        ),
      );
    }
    return entries;
  }

  List<_CompoundScoreEntry> _sortScorecards(List<_CompoundScoreEntry> entries) {
    final sorted = List<_CompoundScoreEntry>.from(entries);
    switch (_scorecardSort) {
      case _ScorecardSort.risk:
        sorted.sort((a, b) {
          final ap = a.adherencePct ?? -1;
          final bp = b.adherencePct ?? -1;
          final missedCmp = b.missed.compareTo(a.missed);
          if (missedCmp != 0) return missedCmp;
          return ap.compareTo(bp);
        });
      case _ScorecardSort.best:
        sorted.sort((a, b) {
          final ap = a.adherencePct ?? -1;
          final bp = b.adherencePct ?? -1;
          final adherenceCmp = bp.compareTo(ap);
          if (adherenceCmp != 0) return adherenceCmp;
          return a.missed.compareTo(b.missed);
        });
      case _ScorecardSort.az:
        sorted.sort((a, b) => a.device.name.compareTo(b.device.name));
    }
    return sorted;
  }

  _DeviceRangeMetrics _deviceRangeMetrics(
    Device device,
    List<DoseLog> logs,
    DateTime start,
    DateTime end,
  ) {
    int expected = 0;
    int logged = 0;
    for (DateTime day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      if (!isScheduledOnDate(device, day)) continue;
      expected++;
      final hasLog = logs
          .any((l) => l.deviceId == device.id && _isSameDay(l.loggedAt, day));
      if (hasLog) logged++;
    }
    if (expected == 0) {
      return const _DeviceRangeMetrics(adherencePct: null, missed: 0);
    }
    final adherence = ((logged / expected) * 100).round().clamp(0, 100);
    return _DeviceRangeMetrics(
        adherencePct: adherence, missed: expected - logged);
  }

  List<_InventoryOutlookItem> _buildInventoryOutlook({
    required List<Device> activeDevices,
    required List<DoseLog> logs,
    required DateTime now,
  }) {
    final items = activeDevices.where((d) => d.remainingDoses > 0).map((d) {
      final projected = calcProjectedDepletion(d, logs);
      final daysLeft = projected?.difference(now).inDays;
      return _InventoryOutlookItem(
        device: d,
        projectedDate: projected,
        daysLeft: daysLeft,
      );
    }).toList();

    items.sort((a, b) {
      final ad = a.daysLeft ?? 9999;
      final bd = b.daysLeft ?? 9999;
      return ad.compareTo(bd);
    });
    return items.take(6).toList();
  }

  _SiteStats? _buildSiteStats(List<DoseLog> rangeLogs) {
    final siteCounts = <String, int>{for (final s in kInjectionSites) s: 0};
    DoseLog? lastLogWithSite;
    for (final log in rangeLogs) {
      final site = normalizeInjectionSite(log.injectionSite);
      if (site == null) continue;
      siteCounts[site] = (siteCounts[site] ?? 0) + 1;
      if (lastLogWithSite == null ||
          log.loggedAt.isAfter(lastLogWithSite.loggedAt)) {
        lastLogWithSite = log;
      }
    }
    final hasSiteData = siteCounts.values.any((v) => v > 0);
    if (!hasSiteData) return null;

    final mostUsed = siteCounts.entries.reduce((best, current) {
      if (current.value > best.value) return current;
      if (current.value == best.value &&
          kInjectionSites.indexOf(current.key) <
              kInjectionSites.indexOf(best.key)) {
        return current;
      }
      return best;
    });

    final lastUsedSite = normalizeInjectionSite(lastLogWithSite?.injectionSite);
    final nextSite = _suggestNextSite(lastUsedSite, siteCounts);
    return _SiteStats(
      mostUsedSite: mostUsed.key,
      mostUsedCount: mostUsed.value,
      lastUsedSite: lastUsedSite ?? mostUsed.key,
      lastUsedCount: siteCounts[lastUsedSite] ?? 0,
      suggestedNextSite: nextSite,
    );
  }

  String _suggestNextSite(String? lastUsedSite, Map<String, int> counts) {
    if (lastUsedSite != null) {
      final idx = kInjectionSites.indexOf(lastUsedSite);
      if (idx >= 0) {
        return kInjectionSites[(idx + 1) % kInjectionSites.length];
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.first.key;
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

enum _ScorecardSort { risk, best, az }

class _ActionItem {
  final IconData icon;
  final Color color;
  final String text;
  const _ActionItem({
    required this.icon,
    required this.color,
    required this.text,
  });
}

class _RangeSelector extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onChanged;
  const _RangeSelector({required this.selectedDays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: _AnalyticsScreenState._rangeOptions.map((days) {
        final active = selectedDays == days;
        return GestureDetector(
          onTap: () => onChanged(days),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: active ? AppColors.teal : context.clrSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? AppColors.teal : context.clrBorder,
                width: active ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              '${days}d',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : context.clrTextSub,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionItemRow extends StatelessWidget {
  final _ActionItem item;
  const _ActionItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: item.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 13,
                color: context.clrText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSummary extends StatelessWidget {
  final int adherence;
  final int loggedCount;
  final int missedCount;
  final int streak;
  const _KpiSummary({
    required this.adherence,
    required this.loggedCount,
    required this.missedCount,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                value: '$adherence%',
                label: 'Adherence',
                sublabel: 'Scheduled doses completed',
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                value: '$loggedCount',
                label: 'Logged doses',
                sublabel: 'Total logs in period',
                color: AppColors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                value: '$missedCount',
                label: 'Missed doses',
                sublabel: 'Scheduled but not logged',
                color: AppColors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                value: '${streak}d',
                label: 'Current streak',
                sublabel: 'Consecutive logged days',
                color: AppColors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final String sublabel;
  final Color color;
  const _KpiCard({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.clrBorder, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.clrText,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sublabel,
            style: TextStyle(fontSize: 10, color: context.clrTextSub),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final BuildContext context;
  const _SectionCard({
    required this.title,
    required this.child,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.clrBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.clrText,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

enum _ConsistencyStatus { onTrack, partial, missed, notScheduled }

class _ConsistencyDayStatus {
  final DateTime date;
  final _ConsistencyStatus status;
  final int expected;
  final int logged;
  const _ConsistencyDayStatus({
    required this.date,
    required this.status,
    required this.expected,
    required this.logged,
  });
}

class _ConsistencyFilterRow extends StatelessWidget {
  final List<Device> devices;
  final String? selectedDeviceId;
  final ValueChanged<String?> onChanged;
  const _ConsistencyFilterRow({
    required this.devices,
    required this.selectedDeviceId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TinyChip(
            label: 'All compounds',
            active: selectedDeviceId == null,
            onTap: () => onChanged(null),
          ),
          ...devices.map(
            (d) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _TinyChip(
                label: d.name,
                active: selectedDeviceId == d.id,
                onTap: () => onChanged(d.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TinyChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? context.clrTealBg : context.clrBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.teal : context.clrBorder,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.tealDark : context.clrTextSub,
          ),
        ),
      ),
    );
  }
}

class _ConsistencyLegend extends StatelessWidget {
  final BuildContext context;
  const _ConsistencyLegend({required this.context});

  @override
  Widget build(BuildContext _) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendDot(label: 'On track', color: AppColors.teal),
        _LegendDot(label: 'Partial', color: AppColors.amber),
        _LegendDot(label: 'Missed', color: AppColors.red),
        _LegendDot(label: 'Not scheduled', color: Color(0xFFCBD5E1)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: context.clrTextSub)),
      ],
    );
  }
}

class _ConsistencyGrid extends StatelessWidget {
  final List<_ConsistencyDayStatus> statuses;
  const _ConsistencyGrid({required this.statuses});

  Color _colorFor(_ConsistencyStatus status) {
    switch (status) {
      case _ConsistencyStatus.onTrack:
        return AppColors.teal;
      case _ConsistencyStatus.partial:
        return AppColors.amber;
      case _ConsistencyStatus.missed:
        return AppColors.red;
      case _ConsistencyStatus.notScheduled:
        return const Color(0xFFCBD5E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: statuses.map((s) {
        final tooltip = '${DateFormat('MMM d').format(s.date)} • '
            '${s.logged}/${s.expected == 0 ? '-' : s.expected} logged';
        return Tooltip(
          message: tooltip,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _colorFor(s.status),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CompoundScoreEntry {
  final Device device;
  final int? adherencePct;
  final int missed;
  final DateTime? lastLoggedAt;
  final int? trendDelta;
  const _CompoundScoreEntry({
    required this.device,
    required this.adherencePct,
    required this.missed,
    required this.lastLoggedAt,
    required this.trendDelta,
  });
}

class _ScorecardSortRow extends StatelessWidget {
  final _ScorecardSort selected;
  final ValueChanged<_ScorecardSort> onChanged;
  const _ScorecardSortRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Sort by:',
          style: TextStyle(fontSize: 12, color: context.clrTextSub),
        ),
        _TinyChip(
          label: 'Most at risk',
          active: selected == _ScorecardSort.risk,
          onTap: () => onChanged(_ScorecardSort.risk),
        ),
        _TinyChip(
          label: 'Best',
          active: selected == _ScorecardSort.best,
          onTap: () => onChanged(_ScorecardSort.best),
        ),
        _TinyChip(
          label: 'A-Z',
          active: selected == _ScorecardSort.az,
          onTap: () => onChanged(_ScorecardSort.az),
        ),
      ],
    );
  }
}

class _CompoundScorecard extends StatelessWidget {
  final _CompoundScoreEntry entry;
  const _CompoundScorecard({required this.entry});

  Color _adherenceColor(int? adherence) {
    if (adherence == null) return AppColors.blue;
    if (adherence >= 80) return AppColors.teal;
    if (adherence >= 50) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final adherence = entry.adherencePct;
    final color = _adherenceColor(adherence);
    final trend = entry.trendDelta;
    final trendLabel = trend == null ? '--' : '${trend > 0 ? '+' : ''}$trend%';
    final trendColor = trend == null
        ? context.clrTextSub
        : trend >= 0
            ? AppColors.teal
            : AppColors.red;
    final lastLoggedLabel = entry.lastLoggedAt == null
        ? 'No logs yet'
        : _relativeDate(entry.lastLoggedAt!);
    final progress = adherence == null ? 0.0 : (adherence / 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.clrBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.clrBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.device.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.clrText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                adherence == null ? '--' : '$adherence%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.clrBorder,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                label: 'Missed: ${entry.missed}',
                color: context.clrTextSub,
              ),
              _MetaPill(
                label: 'Last log: $lastLoggedLabel',
                color: context.clrTextSub,
              ),
              _MetaPill(
                label: 'Trend: $trendLabel',
                color: trendColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return '1d ago';
    return '${diff}d ago';
  }
}

class _InventoryOutlookItem {
  final Device device;
  final DateTime? projectedDate;
  final int? daysLeft;
  const _InventoryOutlookItem({
    required this.device,
    required this.projectedDate,
    required this.daysLeft,
  });
}

class _InventoryOutlookRow extends StatelessWidget {
  final _InventoryOutlookItem item;
  const _InventoryOutlookRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final daysLeft = item.daysLeft;
    final color = daysLeft == null
        ? context.clrTextSub
        : daysLeft <= 7
            ? AppColors.red
            : daysLeft <= 14
                ? AppColors.amber
                : AppColors.teal;
    final dateLabel = item.projectedDate == null
        ? 'N/A'
        : DateFormat('MMM d').format(item.projectedDate!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.device.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.clrText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  daysLeft == null ? '~$dateLabel' : '$daysLeft d',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 19),
            child: Text(
              '${item.device.remainingDoses} doses remaining',
              style: TextStyle(fontSize: 12, color: context.clrTextSub),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.clrBorder, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SiteStats {
  final String mostUsedSite;
  final int mostUsedCount;
  final String lastUsedSite;
  final int lastUsedCount;
  final String suggestedNextSite;
  const _SiteStats({
    required this.mostUsedSite,
    required this.mostUsedCount,
    required this.lastUsedSite,
    required this.lastUsedCount,
    required this.suggestedNextSite,
  });
}

class _SiteInsightContent extends StatelessWidget {
  final _SiteStats stats;
  const _SiteInsightContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _siteRow(
          context: context,
          label: 'Most used',
          value: '${_displaySite(stats.mostUsedSite)} (${stats.mostUsedCount})',
          color: AppColors.teal,
        ),
        const SizedBox(height: 8),
        _siteRow(
          context: context,
          label: 'Last used',
          value: '${_displaySite(stats.lastUsedSite)} (${stats.lastUsedCount})',
          color: AppColors.amber,
        ),
        const SizedBox(height: 8),
        _siteRow(
          context: context,
          label: 'Suggested next site',
          value: _displaySite(stats.suggestedNextSite),
          color: AppColors.blue,
        ),
      ],
    );
  }

  Widget _siteRow({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: context.clrTextSub),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _displaySite(String site) {
    switch (site) {
      case 'L Abd':
        return 'Left Abdomen';
      case 'R Abd':
        return 'Right Abdomen';
      case 'L Thigh':
        return 'Left Thigh';
      case 'R Thigh':
        return 'Right Thigh';
      case 'L Arm':
        return 'Left Arm';
      case 'R Arm':
        return 'Right Arm';
      case 'L Glute':
        return 'Left Glute';
      case 'R Glute':
        return 'Right Glute';
      default:
        return site;
    }
  }
}

class _DeviceRangeMetrics {
  final int? adherencePct;
  final int missed;
  const _DeviceRangeMetrics({
    required this.adherencePct,
    required this.missed,
  });
}
