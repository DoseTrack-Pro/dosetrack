import 'package:flutter/material.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import 'dose_ring.dart';
import 'badge_chip.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onLogTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onLogTap,
  });

  @override
  Widget build(BuildContext context) {
    final depleted = device.remainingDoses <= 0;
    final color = depleted ? AppColors.textTertiary : doseColor(device.remainingDoses, device.totalDoses);
    final pct = device.totalDoses > 0 ? device.remainingDoses / device.totalDoses : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
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
                          Text(device.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          BadgeChip(
                            label: device.type.name.toUpperCase(),
                            bg: device.type == ContainerType.pen ? AppColors.purpleLight : AppColors.tealLight,
                            fg: device.type == ContainerType.pen ? AppColors.purpleDark : AppColors.tealDark,
                          ),
                          if (device.nfcTagId != null)
                            const BadgeChip(label: 'NFC', bg: AppColors.blueLight, fg: AppColors.blueDark),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(device.vendor, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${device.schedule.label}  ·  ${device.desiredDoseMcg.toStringAsFixed(0)}mcg / ${device.doseVolumeIu.toStringAsFixed(0)}IU',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Courier New'),
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
                      color: depleted ? AppColors.border : color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      depleted ? 'Empty' : 'Log',
                      style: TextStyle(
                        color: depleted ? AppColors.textTertiary : AppColors.textInverse,
                        fontSize: 13, fontWeight: FontWeight.w600,
                      ),
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
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${device.remainingDoses} of ${device.totalDoses} doses', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
