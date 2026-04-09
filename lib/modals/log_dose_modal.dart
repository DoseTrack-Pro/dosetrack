import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';
import '../widgets/dose_ring.dart';
import '../widgets/body_site_picker.dart';

class LogDoseModal extends ConsumerStatefulWidget {
  final Device device;
  final VoidCallback? onNfcScan;

  const LogDoseModal({super.key, required this.device, this.onNfcScan});

  @override
  ConsumerState<LogDoseModal> createState() => _LogDoseModalState();
}

class _LogDoseModalState extends ConsumerState<LogDoseModal> {
  late TextEditingController _notesCtrl;
  late TextEditingController _mcgCtrl;
  late TextEditingController _iuCtrl;
  String? _selectedSite;
  bool _overriding = false;
  bool _syncingFromMcg = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _mcgCtrl =
        TextEditingController(text: _fmtDose(widget.device.desiredDoseMcg));
    _iuCtrl = TextEditingController(
        text: widget.device.doseVolumeIu.toStringAsFixed(1));
    _selectedSite = _suggestNextSite();

    _mcgCtrl.addListener(_onMcgChanged);
    _iuCtrl.addListener(_onIuChanged);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _mcgCtrl.dispose();
    _iuCtrl.dispose();
    super.dispose();
  }

  String _fmtDose(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  void _onMcgChanged() {
    if (_syncingFromMcg) return;
    final mcg = double.tryParse(_mcgCtrl.text) ?? 0;
    final d = widget.device;
    if (d.peptideMg > 0 && d.reconVolumeMl > 0) {
      final iu = calcDoseIu(d.peptideMg, d.reconVolumeMl, mcg);
      _syncingFromMcg = true;
      _iuCtrl.text = iu > 0 ? iu.toStringAsFixed(1) : '';
      _syncingFromMcg = false;
    }
    setState(() {});
  }

  void _onIuChanged() {
    if (_syncingFromMcg) return;
    final iu = double.tryParse(_iuCtrl.text) ?? 0;
    final d = widget.device;
    if (d.peptideMg > 0 && d.reconVolumeMl > 0) {
      final mcg = calcDoseMcg(d.peptideMg, d.reconVolumeMl, iu);
      _syncingFromMcg = true;
      _mcgCtrl.text = mcg > 0 ? _fmtDose(mcg) : '';
      _syncingFromMcg = false;
    }
    setState(() {});
  }

  String _suggestNextSite() {
    final logs = ref
        .read(doseLogsProvider)
        .where((l) => l.deviceId == widget.device.id && l.injectionSite != null)
        .toList();
    if (logs.isEmpty) return kInjectionSites.first;
    logs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final normalized = normalizeInjectionSite(logs.first.injectionSite);
    final idx = normalized != null ? kInjectionSites.indexOf(normalized) : -1;
    return kInjectionSites[(idx + 1) % kInjectionSites.length];
  }

  bool _alreadyLoggedToday() {
    final today = DateTime.now();
    return ref.read(doseLogsProvider).any(
          (l) =>
              l.deviceId == widget.device.id &&
              l.loggedAt.year == today.year &&
              l.loggedAt.month == today.month &&
              l.loggedAt.day == today.day,
        );
  }

  double get _currentMcg =>
      double.tryParse(_mcgCtrl.text) ?? widget.device.desiredDoseMcg;
  double get _currentIu =>
      double.tryParse(_iuCtrl.text) ?? widget.device.doseVolumeIu;

  bool get _isDoseModified =>
      (_currentMcg - widget.device.desiredDoseMcg).abs() > 0.5 ||
      (_currentIu - widget.device.doseVolumeIu).abs() > 0.05;

  Future<void> _confirm() async {
    final device = widget.device;
    if (device.remainingDoses <= 0) return;

    if (_alreadyLoggedToday()) {
      final proceed = await _showDuplicateWarning();
      if (!proceed) return;
    }

    await ref.read(appProvider.notifier).logDose(
          device.id,
          LogMethod.manual,
          notes: _notesCtrl.text,
          injectionSite: _selectedSite,
          overrideDoseMcg: _isDoseModified ? _currentMcg : null,
          overrideDoseIu: _isDoseModified ? _currentIu : null,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _showDuplicateWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.clrSurface,
        title: Text('Already logged today',
            style: TextStyle(color: context.clrText)),
        content: Text(
          'You\'ve already logged a dose of ${widget.device.name} today. Log another anyway?',
          style: TextStyle(color: context.clrTextSub),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.amber),
            child: const Text('Log anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final depleted = device.remainingDoses <= 0;
    final pct = device.remainingPct;

    return Container(
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.clrBorderStrong,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),

              Text(device.name,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.clrText)),
              Text(
                  '${device.type.name[0].toUpperCase()}${device.type.name.substring(1)}  ·  ${device.vendor}',
                  style: TextStyle(fontSize: 13, color: context.clrTextSub)),
              const SizedBox(height: 20),

              // Ring + stats
              Row(children: [
                DoseRing(
                    remaining: device.remainingDoses,
                    total: device.totalDoses,
                    size: 110,
                    strokeWidth: 8),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Remaining',
                            value: '${(pct * 100).round()}%')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatCard(
                            label: 'Schedule', value: device.schedule.label)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Doses left',
                            value:
                                '${device.remainingDoses}/${device.totalDoses}')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatCard(
                            label: 'Vendor',
                            value: device.vendor,
                            small: true)),
                  ]),
                ])),
              ]),
              const SizedBox(height: 16),

              // Dose amount (editable)
              if (!depleted) ...[
                GestureDetector(
                  onTap: () => setState(() => _overriding = !_overriding),
                  child: Row(children: [
                    Text('DOSE AMOUNT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.clrTextSub,
                            letterSpacing: 0.6)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _overriding ? context.clrAmberBg : context.clrBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _overriding
                                ? AppColors.amber
                                : context.clrBorder,
                            width: 0.5),
                      ),
                      child: Text(_overriding ? 'custom' : 'configured',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _overriding
                                  ? AppColors.amberDark
                                  : context.clrTextHint)),
                    ),
                    const Spacer(),
                    if (!_overriding)
                      Text('tap to override',
                          style: TextStyle(
                              fontSize: 10, color: context.clrTextHint)),
                  ]),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _DoseField(
                    label: 'mcg',
                    controller: _mcgCtrl,
                    enabled: _overriding,
                  )),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('=',
                        style: TextStyle(
                            fontSize: 18, color: context.clrTextHint)),
                  ),
                  Expanded(
                      child: _DoseField(
                    label: 'IU',
                    controller: _iuCtrl,
                    enabled: _overriding,
                  )),
                ]),
                if (_overriding && _isDoseModified) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.amber),
                    const SizedBox(width: 5),
                    Text(
                        'Dose differs from configured ${device.desiredDoseMcg.toStringAsFixed(0)}mcg',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.amberDark)),
                  ]),
                ],
                const SizedBox(height: 16),
              ],

              // NFC option
              if (device.nfcTagId != null && widget.onNfcScan != null)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNfcScan!();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.clrBlueBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.blueMid, width: 0.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.nfc_rounded,
                          color: AppColors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Log via NFC instead',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blueDark)),
                            const Text('Tap to open NFC scanner',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.blue)),
                          ])),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: AppColors.blue, size: 14),
                    ]),
                  ),
                ),
              if (device.nfcTagId != null && widget.onNfcScan != null)
                const SizedBox(height: 14),

              if (depleted) ...[
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                        color: context.clrBorder,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('Depleted — no doses remaining',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.clrTextHint)),
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))),
              ] else ...[
                // Injection site picker
                Text('INJECTION SITE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.clrTextSub,
                        letterSpacing: 0.6)),
                const SizedBox(height: 10),
                BodySitePicker(
                  selectedSite: _selectedSite,
                  recentCounts: siteUsageCounts(
                      ref.read(doseLogsProvider), widget.device.id),
                  onChanged: (site) => setState(() => _selectedSite = site),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: context.clrText),
                  decoration: const InputDecoration(
                      hintText:
                          'Notes (optional) — side effects, how you felt…'),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal),
                    child: const Text('Confirm and log dose'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                    child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: context.clrTextSub)),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final bool small;
  const _StatCard(
      {required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: context.clrBg, borderRadius: BorderRadius.circular(8)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 10, color: context.clrTextSub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: small ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: context.clrText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
      );
}

class _DoseField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  const _DoseField(
      {required this.label, required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: enabled ? context.clrBg : context.clrSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled ? AppColors.teal : context.clrBorder,
                width: enabled ? 1.5 : 0.5,
              ),
            ),
            child: Row(children: [
              Expanded(
                  child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: enabled ? context.clrText : context.clrTextSub,
                  fontFamily: 'Inter',
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              )),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.clrTextHint,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      );
}
