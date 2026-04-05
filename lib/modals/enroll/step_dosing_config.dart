import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../theme/app_theme.dart';
import '../../utils/calculations.dart';

class StepDosingConfig extends StatefulWidget {
  final void Function(double mg, double ml, double mcg, DoseSchedule schedule, int alertPct) onFinish;
  final bool loading;

  const StepDosingConfig({super.key, required this.onFinish, required this.loading});

  @override
  State<StepDosingConfig> createState() => _StepDosingConfigState();
}

class _StepDosingConfigState extends State<StepDosingConfig> {
  final _mgCtrl  = TextEditingController(text: '10');
  final _mlCtrl  = TextEditingController(text: '2');
  final _mcgCtrl = TextEditingController(text: '250');
  final _form    = GlobalKey<FormState>();

  DoseSchedule _schedule = DoseSchedule.dailyAm;
  int _alertPct = 20;

  double get _mg  => double.tryParse(_mgCtrl.text)  ?? 0;
  double get _ml  => double.tryParse(_mlCtrl.text)  ?? 0;
  double get _mcg => double.tryParse(_mcgCtrl.text) ?? 0;
  double get _iu  => calcDoseIu(_mg, _ml, _mcg);
  int    get _total => calcTotalDoses(_ml, _iu);

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (_iu <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dose volume must be > 0 IU. Check your inputs.'), backgroundColor: AppColors.red),
      );
      return;
    }
    widget.onFinish(_mg, _ml, _mcg, _schedule, _alertPct);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dosing Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Enter the peptide and reconstitution details', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          // Peptide mg + recon mL
          Row(children: [
            Expanded(child: _NumField(label: 'Peptide content (mg)', controller: _mgCtrl, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: _NumField(label: 'Recon volume (mL)', controller: _mlCtrl, onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 4),
          _NumField(label: 'Desired dose (mcg)', controller: _mcgCtrl, onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),

          // Live calculation result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Dose volume', style: TextStyle(fontSize: 11, color: AppColors.tealDeep)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(_iu > 0 ? '${_iu.toStringAsFixed(0)} IU' : '—',
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
          const Text('Dose frequency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: DoseSchedule.values.map((s) {
              final active = _schedule == s;
              return GestureDetector(
                onTap: () => setState(() => _schedule = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? AppColors.tealLight : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: active ? AppColors.teal : AppColors.border, width: active ? 1.5 : 0.5),
                  ),
                  child: Text(s.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: active ? AppColors.tealDark : AppColors.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Alert threshold
          const Text('Low stock alert at', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.2)),
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
                      color: active ? AppColors.tealLight : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? AppColors.teal : AppColors.border, width: active ? 1.5 : 0.5),
                    ),
                    child: Center(child: Text('$t%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: active ? AppColors.tealDark : AppColors.textSecondary))),
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
  final TextEditingController controller;
  final void Function(String) onChanged;

  const _NumField({required this.label, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.2)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: const InputDecoration(hintText: '0'),
      ),
    ]),
  );
}
