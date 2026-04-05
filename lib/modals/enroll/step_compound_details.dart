import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class StepCompoundDetails extends StatefulWidget {
  final String initialName, initialVendor, initialBatch, initialCoa, initialDate;
  final void Function(String name, String vendor, String batch, String coa, String date) onNext;

  const StepCompoundDetails({
    super.key,
    required this.initialName, required this.initialVendor,
    required this.initialBatch, required this.initialCoa, required this.initialDate,
    required this.onNext,
  });

  @override
  State<StepCompoundDetails> createState() => _StepCompoundDetailsState();
}

class _StepCompoundDetailsState extends State<StepCompoundDetails> {
  late TextEditingController _name, _vendor, _batch, _coa, _date;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name   = TextEditingController(text: widget.initialName);
    _vendor = TextEditingController(text: widget.initialVendor);
    _batch  = TextEditingController(text: widget.initialBatch);
    _coa    = TextEditingController(text: widget.initialCoa);
    _date   = TextEditingController(
      text: widget.initialDate.isEmpty ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : widget.initialDate,
    );
  }

  @override
  void dispose() {
    for (final c in [_name, _vendor, _batch, _coa, _date]) { c.dispose(); }
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onNext(_name.text.trim(), _vendor.text.trim(), _batch.text.trim(), _coa.text.trim(), _date.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Compound Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Enter information from the product label', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          _Field(label: 'Compound name *', controller: _name, hint: 'e.g. BPC-157',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words),
          _Field(label: 'Vendor *', controller: _vendor, hint: 'e.g. Peptide Sciences',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words),
          _Field(label: 'Batch number *', controller: _batch, hint: 'e.g. PS-2024-12',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.characters),
          _Field(label: 'COA URL', controller: _coa, hint: 'https://',
              keyboardType: TextInputType.url),
          _Field(label: 'Reconstitution date *', controller: _date, hint: 'YYYY-MM-DD',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),

          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton(onPressed: _submit, child: const Text('Continue'))),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _Field({required this.label, required this.controller, required this.hint,
      this.validator, this.keyboardType, this.textCapitalization = TextCapitalization.none});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.2)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(hintText: hint),
      ),
    ]),
  );
}
