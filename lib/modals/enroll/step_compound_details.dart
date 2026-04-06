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
  late TextEditingController _name, _vendor, _batch, _coa;
  late DateTime _reconDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name   = TextEditingController(text: widget.initialName);
    _vendor = TextEditingController(text: widget.initialVendor);
    _batch  = TextEditingController(text: widget.initialBatch);
    _coa    = TextEditingController(text: widget.initialCoa);
    final parsed = DateTime.tryParse(widget.initialDate);
    _reconDate = parsed ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final c in [_name, _vendor, _batch, _coa]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reconDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.teal),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reconDate = picked);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_reconDate);
      widget.onNext(_name.text.trim(), _vendor.text.trim(), _batch.text.trim(), _coa.text.trim(), dateStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compound Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.clrText)),
          const SizedBox(height: 4),
          Text('Enter information from the product label', style: TextStyle(fontSize: 14, color: context.clrTextSub)),
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

          // ── Date picker row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reconstitution date *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.clrTextSub, letterSpacing: 0.2)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: context.clrSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.clrBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.teal),
                    const SizedBox(width: 10),
                    Text(DateFormat('MMMM d, yyyy').format(_reconDate),
                        style: TextStyle(fontSize: 15, color: context.clrText)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 18, color: context.clrTextHint),
                  ]),
                ),
              ),
            ]),
          ),

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
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.clrTextSub, letterSpacing: 0.2)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: TextStyle(fontSize: 15, color: context.clrText),
        decoration: InputDecoration(hintText: hint),
      ),
    ]),
  );
}
