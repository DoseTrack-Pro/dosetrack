import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_chip.dart';
import '../widgets/empty_state.dart';
import '../modals/enroll/enroll_modal.dart';
import '../modals/device_detail_modal.dart';
import '../modals/log_dose_modal.dart';
import '../modals/nfc_scan_modal.dart';

enum _Filter { all, active, depleted, archived, pen, vial }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);

    final filtered = devices.where((d) {
      switch (_filter) {
        case _Filter.active:   return d.active && d.remainingDoses > 0;
        case _Filter.depleted: return d.active && d.remainingDoses == 0;
        case _Filter.archived: return !d.active;
        case _Filter.pen:      return d.type == ContainerType.pen;
        case _Filter.vial:     return d.type == ContainerType.vial;
        case _Filter.all:      return true;
      }
    }).toList();

    final filterLabels = {
      _Filter.all: 'All',
      _Filter.active: 'Active',
      _Filter.depleted: 'Depleted',
      _Filter.archived: 'Archived',
      _Filter.pen: 'Pen',
      _Filter.vial: 'Vial',
    };

    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  Expanded(child: Text('Inventory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.clrText))),
                  TextButton(
                    onPressed: () => showModalBottomSheet(
                      context: context, isScrollControlled: true, useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const EnrollModal(),
                    ),
                    child: const Text('+ Enroll', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.teal)),
                  ),
                ],
              ),
            ),
            // Filter chips
            Container(
              color: context.clrSurface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: _Filter.values.map((f) {
                    final active = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? context.clrTealBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? AppColors.teal : context.clrBorder, width: active ? 1 : 0.5),
                          ),
                          child: Text(filterLabels[f]!, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: active ? AppColors.tealDark : context.clrTextSub,
                          )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(title: 'No compounds', subtitle: 'Enroll a pen or vial to get started', icon: Icons.inventory_2_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _DeviceRow(
                        device: filtered[i],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceDetailPage(
                          device: filtered[i],
                          onLogManual: () => _openLog(context, filtered[i]),
                          onLogNfc: () => _openNfc(context),
                        ))),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLog(BuildContext context, Device device) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogDoseModal(device: device, onNfcScan: () => _openNfc(context)),
    );
  }

  void _openNfc(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NfcScanModal(onManualLog: (d) => _openLog(context, d)),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  const _DeviceRow({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = doseColor(device.remainingDoses, device.totalDoses);
    final pct = device.totalDoses > 0 ? device.remainingDoses / device.totalDoses : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.clrSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.clrBorder, width: 0.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: device.type == ContainerType.pen ? context.clrPurpleBg : context.clrTealBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(
                device.type == ContainerType.pen ? 'PEN' : 'VIAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: device.type == ContainerType.pen ? AppColors.purpleDark : AppColors.tealDark),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(device.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.clrText), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    if (device.nfcTagId != null) BadgeChip(label: 'NFC', bg: context.clrBlueBg, fg: AppColors.blueDark),
                    if (!device.active) const SizedBox(width: 4),
                    if (!device.active) BadgeChip(label: 'Archived', bg: AppColors.border, fg: AppColors.textSecondary),
                  ]),
                  const SizedBox(height: 3),
                  Text('${device.vendor} · ${device.reconstitutionDate}', style: TextStyle(fontSize: 12, color: context.clrTextSub)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: pct, backgroundColor: context.clrBorder, valueColor: AlwaysStoppedAnimation(color), minHeight: 3),
                  ),
                  const SizedBox(height: 3),
                  Text('${device.remainingDoses}/${device.totalDoses} doses · ${(pct * 100).round()}%', style: TextStyle(fontSize: 11, color: context.clrTextHint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.clrTextHint, size: 18),
          ],
        ),
      ),
    );
  }
}
