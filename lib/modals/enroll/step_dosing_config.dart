import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../theme/app_theme.dart';
import '../../utils/calculations.dart';

class StepDosingConfig extends StatefulWidget {
  final void Function(double mg, double ml, double mcg, DoseSchedule schedule, List<int>? scheduleDays, int alertPct) onFinish;
  final bool loading;
  final double initialMg;
  final double initialMl;
  final double initialMcg;
  final DoseSchedule initialSchedule;
  final List<int>? initialScheduleDays;
  final int initialAlertPct;

  const StepDosingConfig({
    super.key,
    required this.onFinish,
    required this.loading,
    this.initialMg = 0,
    this.initialMl = 0,
    this.initialMcg = 0,
    this.initialSchedule = DoseSchedule.dailyAm,
    this.initialScheduleDays,
    this.initialAlertPct = 20,
  });

  @override
  State<StepDosingConfig> createState() => _StepDosingConfigState();
}

class _StepDosingConfigState extends State<StepDosingConfig> {
  late final TextEditingController _mgCtrl;
  late final TextEditingController _mlCtrl;
  late final TextEditingController _mcgCtrl;
  final _form = GlobalKey<FormState>();

  late DoseSchedule _schedule;
  late List<int> _scheduleDays;
  late int _alertPct;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static String _fmt(double v) {
    if (v == 0) return '';
    return v % 1 == 0 ? v.toInt().toString() : v.toString();
  }

  @override
  void initState() {
    super.initState();
    _mgCtrl  = TextEditingController(text: _fmt(widget.initialMg));
    _mlCtrl  = TextEditingController(text: _fmt(widget.initialMl));
    _mcgCtrl = TextEditingController(text: _fmt(widget.initialMcg));
    _schedule = widget.initialSchedule;
    _scheduleDays = widget.initialScheduleDays != null
        ? List<int>.from(widget.initialScheduleDays!)
        : _defaultDays(widget.initialSchedule);
    _alertPct = widget.initialAlertPct;
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
    super.dispose();
  }

  double get _mg  => double.tryParse(_mgCtrl.text)  ?? 0;
  double get _ml  => double.tryParse(_mlCtrl.text)  ?? 0;
  double get _mcg => double.tryParse(_mcgCtrl.text) ?? 0;
  double get _iu  => calcDoseIu(_mg, _ml, _mcg);
  int    get _total => calcTotalDoses(_ml, _iu);

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
    if (_iu <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dose volume must be > 0 IU. Check your inputs.'), backgroundColor: AppColors.red),
      );
      return;
    }
    if (_schedule == DoseSchedule.twiceWeekly && _scheduleDays.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select exactly 2 days for Twice a Week schedule.'), backgroundColor: AppColors.amber),
      );
      return;
    }
    if (_schedule == DoseSchedule.onceWeekly && _scheduleDays.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select exactly 1 day for Once a Week schedule.'), backgroundColor: AppColors.amber),
      );
      return;
    }
    final days = _needsDayPicker && _scheduleDays.isNotEmpty ? _scheduleDays : null;
    widget.onFinish(_mg, _ml, _mcg, _schedule, days, _alertPct);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dosing Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.clrText)),
          const SizedBox(height: 4),
          Text('Enter the peptide and reconstitution details', style: TextStyle(fontSize: 14, color: context.clrTextSub)),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: _NumField(
              label: 'Peptide content (mg)',
              hint: 'e.g. 5',
              subtitle: 'Total peptide in the vial',
              controller: _mgCtrl,
              onChanged: (_) => setState(() {}),
            )),
            const SizedBox(width: 12),
            Expanded(child: _NumField(
              label: 'Recon volume (mL)',
              hint: 'e.g. 2',
              subtitle: 'Bacteriostatic water added',
              controller: _mlCtrl,
              onChanged: (_) => setState(() {}),
            )),
          ]),
          const SizedBox(height: 4),
          _NumField(
            label: 'Desired dose (mcg)',
            hint: 'e.g. 250',
            subtitle: 'Your target dose per injection',
            controller: _mcgCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Live calculation result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.clrTealBg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Dose volume', style: TextStyle(fontSize: 11, color: AppColors.tealDeep)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(_iu > 0 ? '${_iu.toStringAsFixed(1)} IU' : '—',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.tealDark, fontFamily: 'Courier New'))),
              ])),
              Container(width: 0.5, height: 40, color: AppColors.tealMid),
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Total doses', style: TextStyle(fontSize: 11, color: AppColors.tealDeep)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(_total > 0 ? '$_total' : '—',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.tealDark, fontFamily: 'Courier New'))),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // Frequency
          Text('Dose frequency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.clrTextSub, letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: DoseSchedule.values.map((s) {
              final active = _schedule == s;
              return GestureDetector(
                onTap: () => setState(() {
                  _schedule = s;
                  _scheduleDays = _defaultDays(s);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? context.clrTealBg : context.clrBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: active ? AppColors.teal : context.clrBorder, width: active ? 1.5 : 0.5),
                  ),
                  child: Text(s.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: active ? AppColors.tealDark : context.clrTextSub)),
                ),
              );
            }).toList(),
          ),

          // Day picker for weekly/custom schedules
          if (_needsDayPicker) ...[
            const SizedBox(height: 16),
            Row(children: [
              Text(
                _schedule == DoseSchedule.custom ? 'Select days' : 'Dose days',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.clrTextSub, letterSpacing: 0.2),
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
                      child: Center(child: Text(_dayLabels[i], style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : context.clrTextSub,
                      ))),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 24),

          // Alert threshold
          Text('Low stock alert at', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.clrTextSub, letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Row(
            children: [10, 20, 30].map((t) {
              final active = _alertPct == t;
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: t != 30 ? 10 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _alertPct = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? context.clrTealBg : context.clrBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? AppColors.teal : context.clrBorder, width: active ? 1.5 : 0.5),
                    ),
                    child: Center(child: Text('$t%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: active ? AppColors.tealDark : context.clrTextSub))),
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
              child: Text(widget.loading ? 'Enrolling…' : 'Complete Enrollment'),
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
  final void Function(String) onChanged;

  const _NumField({
    required this.label,
    required this.hint,
    required this.subtitle,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.clrTextSub, letterSpacing: 0.2)),
      const SizedBox(height: 2),
      Text(subtitle, style: TextStyle(fontSize: 11, color: context.clrTextHint, height: 1.3)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 15, color: context.clrText),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(hintText: hint),
      ),
    ]),
  );
}
