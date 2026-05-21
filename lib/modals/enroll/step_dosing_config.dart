import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/device.dart';
import '../../theme/app_theme.dart';
import '../../utils/calculations.dart';

class StepDosingConfig extends StatefulWidget {
  final void Function(
    double mg,
    double ml,
    double mcg,
    bool isBlend,
    List<BlendComponent>? blendComponents,
    DoseSchedule schedule,
    List<int>? scheduleDays,
    String scheduleStartDate,
    int alertPct,
    int startingRemainingDoses,
  ) onFinish;
  final bool loading;
  final double initialMg;
  final double initialMl;
  final double initialMcg;
  final bool initialIsBlend;
  final List<BlendComponent>? initialBlendComponents;
  final DoseSchedule initialSchedule;
  final String initialStartDate;
  final List<int>? initialScheduleDays;
  final int initialAlertPct;
  final int? initialStartingRemainingDoses;
  final NfcMode nfcMode;

  const StepDosingConfig({
    super.key,
    required this.onFinish,
    required this.loading,
    this.initialMg = 0,
    this.initialMl = 0,
    this.initialMcg = 0,
    this.initialIsBlend = false,
    this.initialBlendComponents,
    this.initialSchedule = DoseSchedule.daily,
    this.initialStartDate = '',
    this.initialScheduleDays,
    this.initialAlertPct = 10,
    this.initialStartingRemainingDoses,
    this.nfcMode = NfcMode.tag,
  });

  @override
  State<StepDosingConfig> createState() => _StepDosingConfigState();
}

class _StepDosingConfigState extends State<StepDosingConfig> {
  late final TextEditingController _mgCtrl;
  late final TextEditingController _mlCtrl;
  late final TextEditingController _mcgCtrl;
  late final TextEditingController _startingRemainingCtrl;
  final _form = GlobalKey<FormState>();
  bool _isBlend = false;
  late final List<_BlendRowData> _blendRows;

  late DoseSchedule _schedule;
  late DateTime _startDate;
  late List<int> _scheduleDays;
  late int _alertPct;
  bool _startingRemainingEdited = false;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static String _fmt(double v) {
    if (v == 0) return '';
    return v % 1 == 0 ? v.toInt().toString() : v.toString();
  }

  @override
  void initState() {
    super.initState();
    _mgCtrl = TextEditingController(text: _fmt(widget.initialMg));
    _mlCtrl = TextEditingController(text: _fmt(widget.initialMl));
    _mcgCtrl = TextEditingController(text: _fmt(widget.initialMcg));
    _isBlend = widget.initialIsBlend;
    _blendRows = (widget.initialBlendComponents == null ||
            widget.initialBlendComponents!.isEmpty)
        ? [
            _BlendRowData(name: '', mg: ''),
            _BlendRowData(name: '', mg: ''),
          ]
        : widget.initialBlendComponents!
            .map((c) => _BlendRowData(name: c.name, mg: _fmt(c.mg)))
            .toList();
    _schedule = widget.initialSchedule;
    final parsedStart = DateTime.tryParse(widget.initialStartDate);
    _startDate = parsedStart ?? DateTime.now();
    _scheduleDays = widget.initialScheduleDays != null
        ? List<int>.from(widget.initialScheduleDays!)
        : _defaultDays(widget.initialSchedule);
    _alertPct = widget.initialAlertPct;
    final initialTotal = _calcTotalFromInputs();
    final seededRemaining = widget.initialStartingRemainingDoses;
    final safeRemaining = seededRemaining != null &&
            seededRemaining > 0 &&
            (initialTotal <= 0 || seededRemaining <= initialTotal)
        ? seededRemaining
        : (initialTotal > 0 ? initialTotal : 0);
    _startingRemainingCtrl = TextEditingController(
      text: safeRemaining > 0 ? '$safeRemaining' : '',
    );
    if (_isBlend) {
      _syncBlendTotalToMg();
    }
  }

  List<int> _defaultDays(DoseSchedule s) {
    if (s == DoseSchedule.twiceWeekly) return [1, 4];
    if (s == DoseSchedule.onceWeekly) return [1];
    return [];
  }

  @override
  void dispose() {
    _mgCtrl.dispose();
    _mlCtrl.dispose();
    _mcgCtrl.dispose();
    _startingRemainingCtrl.dispose();
    for (final row in _blendRows) {
      row.dispose();
    }
    super.dispose();
  }

  double get _mg => double.tryParse(_mgCtrl.text) ?? 0;
  double get _ml => double.tryParse(_mlCtrl.text) ?? 0;
  double get _mcg => double.tryParse(_mcgCtrl.text) ?? 0;
  double get _blendTotalMg => _blendRows.fold<double>(0, (sum, row) {
        final mg = double.tryParse(row.mg.text.trim()) ?? 0;
        return sum + (mg > 0 ? mg : 0);
      });
  double get _iu => widget.nfcMode == NfcMode.novoPen
      ? calcNovoPenAdjustedDoseIu(_mg, _ml, _mcg)
      : calcDoseIu(_mg, _ml, _mcg);
  int get _total => calcTotalDoses(_ml, _iu);
  int get _startingRemaining => int.tryParse(_startingRemainingCtrl.text) ?? 0;

  int _calcTotalFromInputs() {
    final mg = double.tryParse(_mgCtrl.text) ?? 0;
    final ml = double.tryParse(_mlCtrl.text) ?? 0;
    final mcg = double.tryParse(_mcgCtrl.text) ?? 0;
    final iu = widget.nfcMode == NfcMode.novoPen
        ? calcNovoPenAdjustedDoseIu(mg, ml, mcg)
        : calcDoseIu(mg, ml, mcg);
    return calcTotalDoses(ml, iu);
  }

  void _onDoseInputsChanged(String _) {
    setState(() {
      if (_isBlend) {
        _syncBlendTotalToMg();
      }
      if (!_startingRemainingEdited) {
        final total = _calcTotalFromInputs();
        _startingRemainingCtrl.text = total > 0 ? '$total' : '';
      }
    });
  }

  void _syncBlendTotalToMg() {
    final total = _blendTotalMg;
    _mgCtrl.text = total > 0 ? _fmt(total) : '';
  }

  void _setBlendMode(bool isBlend) {
    setState(() {
      _isBlend = isBlend;
      if (_isBlend) {
        _syncBlendTotalToMg();
      }
      _onDoseInputsChanged('');
    });
  }

  void _addBlendRow() {
    if (_blendRows.length >= 6) return;
    setState(() => _blendRows.add(_BlendRowData(name: '', mg: '')));
  }

  void _removeBlendRow(int index) {
    if (_blendRows.length <= 2) return;
    final row = _blendRows.removeAt(index);
    row.dispose();
    _onDoseInputsChanged('');
  }

  String? _validateBlend() {
    if (!_isBlend) return null;
    if (_blendRows.length < 2) return 'Add at least 2 ingredients for blends.';
    final seen = <String>{};
    for (final row in _blendRows) {
      final name = row.name.text.trim();
      final mgRaw = row.mg.text.trim();
      final mg = double.tryParse(mgRaw);
      if (name.isEmpty) return 'Each ingredient needs a name.';
      if (mgRaw.isEmpty) return 'Each ingredient amount (mg) is required.';
      if (mg == null || mg <= 0) return 'Each ingredient mg must be above 0.';
      final key = name.toLowerCase();
      if (seen.contains(key)) return 'Ingredient names must be unique.';
      seen.add(key);
    }
    if (_blendTotalMg <= 0) return 'Blend total mg must be above 0.';
    return null;
  }

  List<BlendComponent> _buildBlendComponents() {
    return _blendRows
        .map((row) => BlendComponent(
              name: row.name.text.trim(),
              mg: double.parse(row.mg.text.trim()),
            ))
        .toList();
  }

  bool get _needsDayPicker =>
      _schedule == DoseSchedule.twiceWeekly ||
      _schedule == DoseSchedule.onceWeekly ||
      _schedule == DoseSchedule.custom;

  int? get _requiredDays {
    if (_schedule == DoseSchedule.twiceWeekly) return 2;
    if (_schedule == DoseSchedule.onceWeekly) return 1;
    return null; // custom: any number
  }

  void _toggleDay(int weekday) {
    setState(() {
      final req = _requiredDays;
      if (_scheduleDays.contains(weekday)) {
        _scheduleDays.remove(weekday);
      } else {
        if (req != null && _scheduleDays.length >= req) {
          _scheduleDays.removeAt(0);
        }
        _scheduleDays.add(weekday);
        _scheduleDays.sort();
      }
    });
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final blendError = _validateBlend();
    if (blendError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blendError), backgroundColor: AppColors.amber),
      );
      return;
    }
    if (_isBlend) {
      _syncBlendTotalToMg();
    }
    if (_iu <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Dose volume must be > 0 IU. Check your inputs.'),
            backgroundColor: AppColors.red),
      );
      return;
    }
    if (_schedule == DoseSchedule.twiceWeekly && _scheduleDays.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select exactly 2 days for Twice a Week schedule.'),
            backgroundColor: AppColors.amber),
      );
      return;
    }
    if (_schedule == DoseSchedule.onceWeekly && _scheduleDays.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select exactly 1 day for Once a Week schedule.'),
            backgroundColor: AppColors.amber),
      );
      return;
    }
    if (_startingRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Starting doses remaining must be at least 1.'),
            backgroundColor: AppColors.amber),
      );
      return;
    }
    if (_startingRemaining > _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Starting doses remaining cannot exceed total doses.'),
            backgroundColor: AppColors.amber),
      );
      return;
    }
    final days =
        _needsDayPicker && _scheduleDays.isNotEmpty ? _scheduleDays : null;
    final components = _isBlend ? _buildBlendComponents() : null;
    widget.onFinish(
        _mg,
        _ml,
        _mcg,
        _isBlend,
        components,
        _schedule,
        days,
        DateFormat('yyyy-MM-dd').format(_startDate),
        _alertPct,
        _startingRemaining);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppColors.teal),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dosing Configuration',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.clrText)),
          const SizedBox(height: 4),
          Text('Enter the peptide and reconstitution details',
              style: TextStyle(fontSize: 14, color: context.clrTextSub)),
          const SizedBox(height: 24),

          Text('Compound type',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.clrTextSub,
                  letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _ChoiceChipButton(
                label: 'Single peptide',
                active: !_isBlend,
                onTap: () => _setBlendMode(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChoiceChipButton(
                label: 'Blend',
                active: _isBlend,
                onTap: () => _setBlendMode(true),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          if (_isBlend) ...[
            Text('Blend composition',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.clrTextSub,
                    letterSpacing: 0.2)),
            const SizedBox(height: 6),
            Text(
                'Add ingredients and mg in vial. Total blend mg is auto-summed.',
                style: TextStyle(
                    fontSize: 11, color: context.clrTextHint, height: 1.3)),
            const SizedBox(height: 10),
            ..._blendRows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: row.name,
                      onChanged: _onDoseInputsChanged,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (!_isBlend) return null;
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                      scrollPadding: const EdgeInsets.only(bottom: 180),
                      decoration:
                          const InputDecoration(hintText: 'Ingredient name'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: row.mg,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onDoseInputsChanged,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (!_isBlend) return null;
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Required';
                        final mg = double.tryParse(text);
                        if (mg == null) return 'Number';
                        if (mg <= 0) return '> 0';
                        return null;
                      },
                      scrollPadding: const EdgeInsets.only(bottom: 180),
                      decoration: const InputDecoration(hintText: 'mg'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed:
                        _blendRows.length > 2 ? () => _removeBlendRow(i) : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.red,
                    tooltip: 'Remove',
                  ),
                ]),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _blendRows.length < 6 ? _addBlendRow : null,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add ingredient'),
              ),
            ),
            const SizedBox(height: 6),
          ],

          Row(children: [
            Expanded(
                child: _NumField(
              label: _isBlend
                  ? 'Total blend content (mg)'
                  : 'Peptide content (mg)',
              hint: _isBlend ? 'Auto-calculated' : 'e.g. 5',
              subtitle: _isBlend
                  ? 'Sum of all blend ingredients'
                  : 'Total peptide in the vial',
              controller: _mgCtrl,
              onChanged: _onDoseInputsChanged,
              enabled: !_isBlend,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _NumField(
              label: 'Recon volume (mL)',
              hint: 'e.g. 2',
              subtitle: 'Bacteriostatic water added',
              controller: _mlCtrl,
              onChanged: _onDoseInputsChanged,
            )),
          ]),
          const SizedBox(height: 4),
          _NumField(
            label: 'Desired dose (mcg)',
            hint: 'e.g. 250',
            subtitle: _isBlend
                ? 'Target total blend dose per injection'
                : 'Your target dose per injection',
            controller: _mcgCtrl,
            onChanged: _onDoseInputsChanged,
          ),
          if (widget.nfcMode == NfcMode.novoPen) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.clrBlueBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.blue, width: 0.5),
              ),
              child: Text(
                'NovoPen mode: displayed IU is pre-adjusted for +8% cartridge overdelivery.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.clrText,
                  height: 1.35,
                ),
              ),
            ),
          ],

          if (_isBlend && _mcg > 0 && _blendTotalMg > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.clrBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.clrBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Per-dose ingredient breakdown',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.clrText)),
                  const SizedBox(height: 6),
                  ..._blendRows.map((row) {
                    final mg = double.tryParse(row.mg.text.trim()) ?? 0;
                    final ratio =
                        _blendTotalMg > 0 ? (mg / _blendTotalMg) : 0.0;
                    final dose = _mcg * ratio;
                    final name = row.name.text.trim().isEmpty
                        ? 'Ingredient'
                        : row.name.text.trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: context.clrTextSub)),
                        ),
                        Text('${dose.toStringAsFixed(1)} mcg',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.clrText)),
                      ]),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          _NumField(
            label: 'Starting doses remaining',
            hint: _total > 0 ? 'e.g. $_total' : 'e.g. 10',
            subtitle:
                'You can update the total calculated if this vial was already in progress',
            controller: _startingRemainingCtrl,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final parsed = int.tryParse(v.trim());
              if (parsed == null) return 'Enter a whole number';
              if (parsed <= 0) return 'Must be at least 1';
              if (_total > 0 && parsed > _total) {
                return 'Cannot exceed total doses ($_total)';
              }
              return null;
            },
            onChanged: (_) => setState(() => _startingRemainingEdited = true),
          ),
          const SizedBox(height: 16),

          // Live calculation result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: context.clrTealBg,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Dose volume',
                    style: TextStyle(fontSize: 11, color: AppColors.tealDeep)),
                const SizedBox(height: 4),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_iu > 0 ? '${_iu.toStringAsFixed(1)} IU' : '—',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDark,
                            fontFamily: 'Inter',
                            fontFeatures: [FontFeature.tabularFigures()]))),
              ])),
              Container(width: 0.5, height: 40, color: AppColors.tealMid),
              Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Total doses',
                    style: TextStyle(fontSize: 11, color: AppColors.tealDeep)),
                const SizedBox(height: 4),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_total > 0 ? '$_total' : '—',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDark,
                            fontFamily: 'Inter',
                            fontFeatures: [FontFeature.tabularFigures()]))),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // Frequency
          Text('Dose frequency',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.clrTextSub,
                  letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              DoseSchedule.daily,
              DoseSchedule.everyOtherDay,
              DoseSchedule.onceWeekly,
              DoseSchedule.twiceWeekly,
              DoseSchedule.custom,
            ].map((s) {
              final active = _schedule == s;
              return GestureDetector(
                onTap: () => setState(() {
                  _schedule = s;
                  _scheduleDays = _defaultDays(s);
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? context.clrTealBg : context.clrBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: active ? AppColors.teal : context.clrBorder,
                        width: active ? 1.5 : 0.5),
                  ),
                  child: Text(s.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? AppColors.tealDark
                              : context.clrTextSub)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text('Start date',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.clrTextSub,
                  letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Text('First date this schedule should begin',
              style: TextStyle(
                  fontSize: 11, color: context.clrTextHint, height: 1.3)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickStartDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: context.clrSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.clrBorder),
              ),
              child: Row(children: [
                const Icon(Icons.event_rounded,
                    size: 16, color: AppColors.teal),
                const SizedBox(width: 10),
                Text(DateFormat('MMMM d, yyyy').format(_startDate),
                    style: TextStyle(fontSize: 15, color: context.clrText)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: context.clrTextHint),
              ]),
            ),
          ),

          // Day picker for weekly/custom schedules
          if (_needsDayPicker) ...[
            const SizedBox(height: 16),
            Row(children: [
              Text(
                _schedule == DoseSchedule.custom ? 'Select days' : 'Dose days',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.clrTextSub,
                    letterSpacing: 0.2),
              ),
              const SizedBox(width: 6),
              if (_requiredDays != null)
                Text('(pick $_requiredDays)',
                    style: TextStyle(fontSize: 11, color: context.clrTextHint)),
            ]),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final selected = _scheduleDays.contains(weekday);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleDay(weekday),
                    child: Container(
                      margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.teal : context.clrBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected ? AppColors.teal : context.clrBorder,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Center(
                          child: Text(_dayLabels[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : context.clrTextSub,
                              ))),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 24),

          // Alert threshold
          Text('Low stock alert at',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.clrTextSub,
                  letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Row(
            children: [5, 10, 20].map((t) {
              final active = _alertPct == t;
              return Expanded(
                  child: Padding(
                padding: EdgeInsets.only(right: t != 30 ? 10 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _alertPct = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? context.clrTealBg : context.clrBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: active ? AppColors.teal : context.clrBorder,
                          width: active ? 1.5 : 0.5),
                    ),
                    child: Center(
                        child: Text('$t%',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? AppColors.tealDark
                                    : context.clrTextSub))),
                  ),
                ),
              ));
            }).toList(),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.loading ? null : _submit,
              child:
                  Text(widget.loading ? 'Enrolling…' : 'Complete Enrollment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final String hint;
  final String subtitle;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String) onChanged;
  final bool enabled;

  const _NumField({
    required this.label,
    required this.hint,
    required this.subtitle,
    required this.controller,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.validator,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.clrTextSub,
                  letterSpacing: 0.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 11, color: context.clrTextHint, height: 1.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            onChanged: onChanged,
            enabled: enabled,
            keyboardType: keyboardType,
            scrollPadding: const EdgeInsets.only(bottom: 180),
            style: TextStyle(fontSize: 15, color: context.clrText),
            validator:
                validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
            decoration: InputDecoration(hintText: hint),
          ),
        ]),
      );
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? context.clrTealBg : context.clrBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.teal : context.clrBorder,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.tealDark : context.clrTextSub,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlendRowData {
  final TextEditingController name;
  final TextEditingController mg;

  _BlendRowData({required String name, required String mg})
      : name = TextEditingController(text: name),
        mg = TextEditingController(text: mg);

  void dispose() {
    name.dispose();
    mg.dispose();
  }
}
