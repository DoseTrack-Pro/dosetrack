import 'package:flutter/material.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import 'dose_ring.dart';
import 'badge_chip.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final bool dosedToday;
  final VoidCallback onTap;
  final VoidCallback onLogTap;
  final BorderRadius? borderRadius;
  final bool showBorder;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onLogTap,
    this.dosedToday = false,
    this.borderRadius,
    this.showBorder = true,
  });

  static List<Widget> _expiryBadge(Device device) {
    final days = daysUntilExpiry(device);
    if (days > 7) return [];
    if (days < 0) return [const BadgeChip(label: 'EXPIRED', bg: AppColors.redLight, fg: AppColors.redDark)];
    return [BadgeChip(label: '${days}D LEFT', bg: AppColors.amberLight, fg: AppColors.amberDark)];
  }

  @override
  Widget build(BuildContext context) {
    final depleted = device.remainingDoses <= 0;
    final ringColor = depleted ? AppColors.textTertiary : doseColor(device.remainingDoses, device.totalDoses);
    final pct = device.totalDoses > 0 ? device.remainingDoses / device.totalDoses : 0.0;

    // Log button is always teal when active; gray when depleted
    final logBtnColor = depleted ? context.clrBorder : AppColors.teal;
    final logBtnTextColor = depleted ? context.clrTextHint : AppColors.textInverse;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: showBorder ? const EdgeInsets.only(bottom: 10) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: context.clrSurface,
          borderRadius: borderRadius ?? BorderRadius.circular(14),
          border: showBorder ? Border.all(color: context.clrBorder, width: 0.5) : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                DoseRing(remaining: device.remainingDoses, total: device.totalDoses, size: 70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          Text(device.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.clrText)),
                          BadgeChip(
                            label: device.type.name.toUpperCase(),
                            bg: device.type == ContainerType.pen ? context.clrPurpleBg : context.clrTealBg,
                            fg: device.type == ContainerType.pen ? AppColors.purpleDark : AppColors.tealDark,
                          ),
                          if (device.nfcTagId != null)
                            BadgeChip(label: 'NFC', bg: context.clrBlueBg, fg: AppColors.blueDark),
                          if (device.active) ..._expiryBadge(device),
                          // "Dosed today" indicator
                          if (dosedToday && !depleted)
                            const BadgeChip(label: '✓ DOSED', bg: AppColors.tealLight, fg: AppColors.tealDark),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(device.vendor, style: TextStyle(fontSize: 12, color: context.clrTextSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${device.schedule.label}  ·  ${device.desiredDoseMcg.toStringAsFixed(0)}mcg / ${device.doseVolumeIu.toStringAsFixed(1)}IU',
                        style: TextStyle(fontSize: 12, color: context.clrTextSub, fontFamily: 'Courier New'),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: depleted ? null : onLogTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: logBtnColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      depleted ? 'Empty' : (dosedToday ? 'Log +' : 'Log'),
                      style: TextStyle(color: logBtnTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: context.clrBorder,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${device.remainingDoses} of ${device.totalDoses} doses',
                    style: TextStyle(fontSize: 11, color: context.clrTextHint)),
                Text('${(pct * 100).round()}%',
                    style: TextStyle(fontSize: 11, color: context.clrTextHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
