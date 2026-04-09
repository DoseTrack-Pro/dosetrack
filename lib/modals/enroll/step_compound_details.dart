import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class StepCompoundDetails extends StatefulWidget {
  final String initialName,
      initialVendor,
      initialBatch,
      initialCoa,
      initialDate;
  final int initialExpiryDays;
  final void Function(String name, String vendor, String batch, String coa,
      String date, int expiryDays) onNext;

  const StepCompoundDetails({
    super.key,
    required this.initialName,
    required this.initialVendor,
    required this.initialBatch,
    required this.initialCoa,
    required this.initialDate,
    this.initialExpiryDays = 30,
    required this.onNext,
  });

  @override
  State<StepCompoundDetails> createState() => _StepCompoundDetailsState();
}

class _StepCompoundDetailsState extends State<StepCompoundDetails> {
  late TextEditingController _name, _vendor, _batch, _coa;
  late TextEditingController _customExpiryCtrl;
  late DateTime _reconDate;
  late int _expiryDays;
  bool _useCustomExpiry = false;
  final _formKey = GlobalKey<FormState>();

  static const _expiryOptions = [30, 40, 60];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _vendor = TextEditingController(text: widget.initialVendor);
    _batch = TextEditingController(text: widget.initialBatch);
    _coa = TextEditingController(text: widget.initialCoa);
    _customExpiryCtrl = TextEditingController();
    final parsed = DateTime.tryParse(widget.initialDate);
    _reconDate = parsed ?? DateTime.now();
    _useCustomExpiry = !_expiryOptions.contains(widget.initialExpiryDays);
    _expiryDays = widget.initialExpiryDays.clamp(10, 90);
    if (_useCustomExpiry) {
      _customExpiryCtrl.text = _expiryDays.toString();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _vendor, _batch, _coa, _customExpiryCtrl]) {
      c.dispose();
    }
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
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppColors.teal),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reconDate = picked);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_useCustomExpiry) {
        final custom = int.tryParse(_customExpiryCtrl.text.trim());
        if (custom == null || custom < 10 || custom > 90) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Custom expiry must be between 10 and 90 days.'),
              backgroundColor: AppColors.amber,
            ),
          );
          return;
        }
        _expiryDays = custom;
      }
      final dateStr = DateFormat('yyyy-MM-dd').format(_reconDate);
      widget.onNext(_name.text.trim(), _vendor.text.trim(), _batch.text.trim(),
          _coa.text.trim(), dateStr, _expiryDays);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compound Details',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.clrText)),
          const SizedBox(height: 4),
          Text('Enter information from the product label',
              style: TextStyle(fontSize: 14, color: context.clrTextSub)),
          const SizedBox(height: 24),

          _Field(
              label: 'Compound name *',
              controller: _name,
              hint: 'e.g. BPC-157',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
              textCapitalization: TextCapitalization.words),
          _Field(
              label: 'Vendor',
              controller: _vendor,
              hint: 'e.g. Peptide Sciences',
              textCapitalization: TextCapitalization.words),
          _Field(
              label: 'Batch number',
              controller: _batch,
              hint: 'e.g. PS-2024-12',
              textCapitalization: TextCapitalization.characters),
          _Field(
              label: 'COA URL',
              controller: _coa,
              hint: 'https://',
              keyboardType: TextInputType.url),

          // ── Date picker row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reconstitution date *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.clrTextSub,
                      letterSpacing: 0.2)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: context.clrSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.clrBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.teal),
                    const SizedBox(width: 10),
                    Text(DateFormat('MMMM d, yyyy').format(_reconDate),
                        style: TextStyle(fontSize: 15, color: context.clrText)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: context.clrTextHint),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Expiry window picker ─────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stability / expiry window',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.clrTextSub,
                      letterSpacing: 0.2)),
              const SizedBox(height: 2),
              Text('Days after reconstitution before compound expires',
                  style: TextStyle(
                      fontSize: 11, color: context.clrTextHint, height: 1.3)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ..._expiryOptions.map((days) {
                    final active = !_useCustomExpiry && _expiryDays == days;
                    return Expanded(
                        child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _useCustomExpiry = false;
                          _expiryDays = days;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? context.clrTealBg : context.clrBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  active ? AppColors.teal : context.clrBorder,
                              width: active ? 1.5 : 0.5,
                            ),
                          ),
                          child: Center(
                              child: Text('${days}d',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? AppColors.tealDark
                                        : context.clrTextSub,
                                  ))),
                        ),
                      ),
                    ));
                  }),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _useCustomExpiry = true;
                        if (_customExpiryCtrl.text.trim().isEmpty) {
                          _customExpiryCtrl.text = _expiryDays.toString();
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _useCustomExpiry
                              ? context.clrTealBg
                              : context.clrBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _useCustomExpiry
                                ? AppColors.teal
                                : context.clrBorder,
                            width: _useCustomExpiry ? 1.5 : 0.5,
                          ),
                        ),
                        child: Center(
                            child: Text('Custom',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _useCustomExpiry
                                      ? AppColors.tealDark
                                      : context.clrTextSub,
                                ))),
                      ),
                    ),
                  ),
                ],
              ),
              if (_useCustomExpiry) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customExpiryCtrl,
                  keyboardType: TextInputType.number,
                  scrollPadding: const EdgeInsets.only(bottom: 180),
                  validator: (v) {
                    if (!_useCustomExpiry) return null;
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter days (10-90)';
                    }
                    final parsed = int.tryParse(v.trim());
                    if (parsed == null) return 'Enter a whole number';
                    if (parsed < 10 || parsed > 90) {
                      return 'Must be between 10 and 90';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Custom days (10-90)',
                  ),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _submit, child: const Text('Continue'))),
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

  const _Field(
      {required this.label,
      required this.controller,
      required this.hint,
      this.validator,
      this.keyboardType,
      this.textCapitalization = TextCapitalization.none});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.clrTextSub,
                  letterSpacing: 0.2)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            scrollPadding: const EdgeInsets.only(bottom: 180),
            style: TextStyle(fontSize: 15, color: context.clrText),
            decoration: InputDecoration(hintText: hint),
          ),
        ]),
      );
}
