import 'package:flutter/material.dart';
import '../models/dose_log.dart';
import '../theme/app_theme.dart';

/// Front/back body image map with 8 tappable injection zones.
/// [selectedSite] — currently selected site name (or null).
/// [recentCounts] — map of site name → number of recent uses (last 14 days).
/// [onChanged]    — called with new site name, or null if deselected.
class BodySitePicker extends StatelessWidget {
  final String? selectedSite;
  final Map<String, int> recentCounts;
  final ValueChanged<String?> onChanged;

  const BodySitePicker({
    super.key,
    required this.selectedSite,
    required this.recentCounts,
    required this.onChanged,
  });

  // Relative rectangles over a 1024x576 reference canvas.
  static const Map<String, _ZoneRect> _zones = {
    'L Abd': _ZoneRect(0.275, 0.393, 0.085, 0.11),
    'R Abd': _ZoneRect(0.130, 0.393, 0.085, 0.11),
    'L Thigh': _ZoneRect(0.285, 0.60, 0.11, 0.18),
    'R Thigh': _ZoneRect(0.10, 0.60, 0.11, 0.18),
    'L Glute': _ZoneRect(0.61, 0.50, 0.095, 0.13),
    'R Glute': _ZoneRect(0.78, 0.50, 0.095, 0.13),
    'L Arm': _ZoneRect(0.345, 0.18, 0.09, 0.17),
    'R Arm': _ZoneRect(0.055, 0.18, 0.09, 0.17),
  };

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = normalizeInjectionSite(selectedSite);

    // Max recent count (for relative "heat" scaling)
    final maxCount = recentCounts.values.fold(0, (m, v) => v > m ? v : m);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1024 / 576,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/injection_sites_map.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    ..._zones.entries.map((entry) {
                      final site = entry.key;
                      final z = entry.value;
                      final left = constraints.maxWidth * z.left;
                      final top = constraints.maxHeight * z.top;
                      final w = constraints.maxWidth * z.width;
                      final h = constraints.maxHeight * z.height;
                      final isSelected = normalizedSelected == site;
                      final count = recentCounts[site] ?? 0;

                      final Color bg;
                      final Color border;
                      final Color labelColor;
                      if (isSelected) {
                        bg = AppColors.teal.withValues(alpha: 0.9);
                        border = AppColors.tealDark;
                        labelColor = Colors.white;
                      } else if (count > 0 && maxCount > 0) {
                        final intensity = (count / maxCount).clamp(0.0, 1.0);
                        bg = Color.lerp(
                            AppColors.tealLight.withValues(alpha: 0.6),
                            const Color(0xFF9FE1CB).withValues(alpha: 0.75),
                            intensity)!;
                        border = AppColors.teal.withValues(alpha: 0.5);
                        labelColor = AppColors.tealDark;
                      } else {
                        bg = Colors.white.withValues(alpha: 0.45);
                        border = Colors.black.withValues(alpha: 0.22);
                        labelColor = const Color(0xFF404040);
                      }

                      return Positioned(
                        left: left,
                        top: top,
                        width: w,
                        height: h,
                        child: GestureDetector(
                          onTap: () => onChanged(isSelected ? null : site),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                site,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: labelColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Selected site label ──────────────────────────────
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            normalizedSelected ?? 'Tap a zone to select',
            key: ValueKey(normalizedSelected),
            style: TextStyle(
              fontSize: 12,
              fontWeight: normalizedSelected != null
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: normalizedSelected != null
                  ? AppColors.teal
                  : context.clrTextHint,
            ),
          ),
        ),

        // ── Legend ───────────────────────────────────────────
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(
                color: context.clrBg,
                border: context.clrBorderStrong,
                label: 'Unused'),
            const SizedBox(width: 14),
            const _LegendDot(
                color: AppColors.tealLight,
                border: AppColors.teal,
                label: 'Recent'),
            const SizedBox(width: 14),
            const _LegendDot(
                color: AppColors.teal,
                border: AppColors.tealDark,
                label: 'Selected'),
          ],
        ),
      ],
    );
  }
}

class _ZoneRect {
  final double left;
  final double top;
  final double width;
  final double height;
  const _ZoneRect(this.left, this.top, this.width, this.height);
}

// ── Legend dot ─────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color, border;
  final String label;
  const _LegendDot(
      {required this.color, required this.border, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: border, width: 1),
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 10, color: context.clrTextHint)),
        ],
      );
}

/// Computes per-site use counts from a list of dose logs over the last [days] days.
Map<String, int> siteUsageCounts(List<DoseLog> logs, String deviceId,
    {int days = 14}) {
  final cutoff = DateTime.now().subtract(Duration(days: days));
  final counts = <String, int>{};
  for (final site in kInjectionSites) {
    counts[site] = logs
        .where((l) =>
            l.deviceId == deviceId &&
            normalizeInjectionSite(l.injectionSite) == site &&
            l.loggedAt.isAfter(cutoff))
        .length;
  }
  return counts;
}
