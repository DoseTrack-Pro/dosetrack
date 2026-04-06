import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';

class DoseDetailPage extends ConsumerStatefulWidget {
  final DoseLog log;
  final Device? device;

  const DoseDetailPage({super.key, required this.log, this.device});

  @override
  ConsumerState<DoseDetailPage> createState() => _DoseDetailPageState();
}

class _DoseDetailPageState extends ConsumerState<DoseDetailPage> {
  late TextEditingController _mcgCtrl;
  late TextEditingController _iuCtrl;
  late TextEditingController _notesCtrl;
  late String? _selectedSite;
  late DateTime _loggedAt;
  bool _saving = false;

  static String _fmtMcg(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  static String _fmtIu(double v) => v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _mcgCtrl = TextEditingController(text: _fmtMcg(widget.log.doseMcg));
    _iuCtrl  = TextEditingController(text: _fmtIu(widget.log.doseIu));
    _notesCtrl = TextEditingController(text: widget.log.notes ?? '');
    _selectedSite = widget.log.injectionSite;
    _loggedAt = widget.log.loggedAt;
  }

  @override
  void dispose() {
    _mcgCtrl.dispose();
    _iuCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // When user edits mcg → recalculate IU
  void _onMcgChanged(String value) {
    final d = widget.device;
    if (d == null) return;
    final mcg = double.tryParse(value);
    if (mcg != null && mcg > 0) {
      final iu = calcDoseIu(d.peptideMg, d.reconVolumeMl, mcg);
      _iuCtrl.text = _fmtIu(iu);
    }
    setState(() {});
  }

  // When user edits IU → recalculate mcg
  void _onIuChanged(String value) {
    final d = widget.device;
    if (d == null) return;
    final iu = double.tryParse(value);
    if (iu != null && iu > 0) {
      final mcg = calcDoseMcg(d.peptideMg, d.reconVolumeMl, iu);
      _mcgCtrl.text = _fmtMcg(mcg);
    }
    setState(() {});
  }

  double get _currentMcg => double.tryParse(_mcgCtrl.text) ?? widget.log.doseMcg;
  double get _currentIu  => double.tryParse(_iuCtrl.text)  ?? widget.log.doseIu;

  bool get _hasChanges =>
      _currentMcg != widget.log.doseMcg ||
      _currentIu  != widget.log.doseIu  ||
      _notesCtrl.text.trim() != (widget.log.notes ?? '') ||
      _selectedSite != widget.log.injectionSite ||
      _loggedAt != widget.log.loggedAt;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.teal),
        ),
        child: child!,
      ),
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.teal),
        ),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;

    setState(() {
      _loggedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_hasChanges) { Navigator.pop(context); return; }
    setState(() => _saving = true);
    final updated = DoseLog(
      id: widget.log.id,
      deviceId: widget.log.deviceId,
      loggedAt: _loggedAt,
      method: widget.log.method,
      doseMcg: _currentMcg,
      doseIu: _currentIu,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      injectionSite: _selectedSite,
    );
    await ref.read(appProvider.notifier).updateDoseLog(updated);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.clrSurface,
        title: Text('Delete Dose', style: TextStyle(color: context.clrText)),
        content: Text('Remove this dose log? The dose will be restored to the compound\'s remaining count.',
            style: TextStyle(color: context.clrTextSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(appProvider.notifier).deleteDoseLog(widget.log.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: context.clrText,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Edit Dose',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.clrText)),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save',
                        style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [

                  // Context card — device info (read-only)
                  if (device != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.clrSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.clrBorder, width: 0.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: context.clrTealBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.medication_rounded, color: AppColors.teal, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(device.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                              color: context.clrText), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${device.vendor}  ·  ${device.schedule.label}',
                              style: TextStyle(fontSize: 12, color: context.clrTextSub),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.log.method == LogMethod.nfc ? context.clrBlueBg : context.clrTealBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.log.method == LogMethod.nfc ? 'NFC' : 'Manual',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: widget.log.method == LogMethod.nfc ? AppColors.blueDark : AppColors.tealDark,
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Date & Time
                  _SectionLabel('DATE & TIME'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: context.clrSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.clrBorder, width: 0.5),
                      ),
                      child: Row(children: [
                        Icon(Icons.schedule_rounded, size: 18, color: context.clrTextSub),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          '${dateFmt.format(_loggedAt)}  ·  ${timeFmt.format(_loggedAt)}',
                          style: TextStyle(fontSize: 14, color: context.clrText),
                        )),
                        Icon(Icons.chevron_right_rounded, size: 18, color: context.clrTextHint),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dose amount — both fields editable, synced
                  _SectionLabel('DOSE AMOUNT'),
                  const SizedBox(height: 4),
                  Text('Edit either value — the other updates automatically.',
                      style: TextStyle(fontSize: 11, color: context.clrTextHint)),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('mcg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: context.clrTextSub, letterSpacing: 0.2)),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _mcgCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 15, color: context.clrText),
                          decoration: const InputDecoration(hintText: '0'),
                          onChanged: _onMcgChanged,
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        SizedBox(width: 10),
                        Icon(Icons.swap_horiz_rounded, color: AppColors.teal, size: 22),
                        SizedBox(width: 10),
                      ]),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('IU (syringe volume)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: context.clrTextSub, letterSpacing: 0.2)),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _iuCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 15, color: context.clrText),
                          decoration: const InputDecoration(hintText: '0'),
                          onChanged: _onIuChanged,
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Injection site
                  _SectionLabel('INJECTION SITE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kInjectionSites.map((site) {
                      final active = _selectedSite == site;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSite = site),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? context.clrTealBg : context.clrSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? AppColors.teal : context.clrBorder,
                              width: active ? 1.5 : 0.5,
                            ),
                          ),
                          child: Text(site, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: active ? AppColors.tealDark : context.clrTextSub,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Notes
                  _SectionLabel('NOTES'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    style: TextStyle(fontSize: 14, color: context.clrText),
                    decoration: const InputDecoration(
                      hintText: 'Side effects, how you felt, observations…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delete
                  Center(
                    child: TextButton(
                      onPressed: _delete,
                      child: const Text('Delete this dose',
                          style: TextStyle(color: AppColors.red, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: context.clrTextSub, letterSpacing: 0.6));
}
