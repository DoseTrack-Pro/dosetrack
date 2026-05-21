import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Allows editing the non-formula fields of an enrolled device:
/// name, vendor, batch number, COA URL, recon date, schedule, remaining doses,
/// alert %.
/// Dosing formula values (peptide mg / recon mL / dose mcg) are intentionally
/// excluded — changes there would invalidate existing IU and remaining-dose counts.
class EditDevicePage extends ConsumerStatefulWidget {
  final Device device;
  const EditDevicePage({super.key, required this.device});

  @override
  ConsumerState<EditDevicePage> createState() => _EditDevicePageState();
}

class _EditDevicePageState extends ConsumerState<EditDevicePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name, _vendor, _batch, _coa;
  late TextEditingController _remainingDosesCtrl;
  late TextEditingController _customExpiryCtrl;
  late DateTime _reconDate;
  late DateTime _scheduleStartDate;
  late DoseSchedule _schedule;
  late List<int> _scheduleDays;
  late int _alertPct;
  late int _expiryDays;
  bool _useCustomExpiry = false;
  bool _saving = false;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _expiryOptions = [30, 40, 60];

  bool get _needsDayPicker =>
      _schedule == DoseSchedule.twiceWeekly ||
      _schedule == DoseSchedule.onceWeekly ||
      _schedule == DoseSchedule.custom;

  int? get _requiredDays {
    if (_schedule == DoseSchedule.twiceWeekly) return 2;
    if (_schedule == DoseSchedule.onceWeekly) return 1;
    return null;
  }

  List<int> _defaultDays(DoseSchedule s) {
    if (s == DoseSchedule.twiceWeekly) return [1, 4];
    if (s == DoseSchedule.onceWeekly) return [1];
    return [];
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

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _name = TextEditingController(text: d.name);
    _vendor = TextEditingController(text: d.vendor);
    _batch = TextEditingController(text: d.batchNumber);
    _coa = TextEditingController(text: d.coaUrl ?? '');
    _remainingDosesCtrl = TextEditingController(text: '${d.remainingDoses}');
    _customExpiryCtrl = TextEditingController();
    _reconDate = DateTime.tryParse(d.reconstitutionDate) ?? DateTime.now();
    _scheduleStartDate = DateTime.tryParse(d.scheduleStartDate ?? '') ??
        DateTime(d.createdAt.year, d.createdAt.month, d.createdAt.day);
    _schedule = d.schedule;
    _scheduleDays = d.scheduleDays != null
        ? List<int>.from(d.scheduleDays!)
        : _defaultDays(d.schedule);
    _alertPct = d.alertThresholdPct;
    _useCustomExpiry = !_expiryOptions.contains(d.expiryDays);
    _expiryDays = d.expiryDays.clamp(10, 90);
    if (_useCustomExpiry) {
      _customExpiryCtrl.text = _expiryDays.toString();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _vendor,
      _batch,
      _coa,
      _remainingDosesCtrl,
      _customExpiryCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reconDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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

  Future<void> _pickScheduleStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduleStartDate,
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
    if (picked != null) setState(() => _scheduleStartDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Reschedule notification if schedule changed
    final oldStartDate = DateTime.tryParse(widget.device.scheduleStartDate ?? '') ??
        DateTime(widget.device.createdAt.year, widget.device.createdAt.month,
            widget.device.createdAt.day);
    final oldStartKey = DateFormat('yyyy-MM-dd').format(oldStartDate);
    final newStartKey = DateFormat('yyyy-MM-dd').format(_scheduleStartDate);
    final scheduleChanged =
        _schedule != widget.device.schedule || oldStartKey != newStartKey;
    if (scheduleChanged && widget.device.notificationId != null) {
      try {
        await NotificationService.instance
            .cancelReminder(widget.device.notificationId!);
      } catch (_) {}
    }

    // Validate day selection before any awaits to avoid async BuildContext issues
    String? dayError;
    if (_schedule == DoseSchedule.twiceWeekly && _scheduleDays.length != 2) {
      dayError = 'Select exactly 2 days for Twice a Week schedule.';
    } else if (_schedule == DoseSchedule.onceWeekly &&
        _scheduleDays.length != 1) {
      dayError = 'Select exactly 1 day for Once a Week schedule.';
    }
    if (dayError != null) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dayError), backgroundColor: AppColors.amber),
        );
      }
      return;
    }

    final remainingDoses = int.parse(_remainingDosesCtrl.text.trim());
    if (_useCustomExpiry) {
      final custom = int.tryParse(_customExpiryCtrl.text.trim());
      if (custom == null || custom < 10 || custom > 90) {
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Custom expiry must be between 10 and 90 days.'),
              backgroundColor: AppColors.amber,
            ),
          );
        }
        return;
      }
      _expiryDays = custom;
    }
    final days =
        _needsDayPicker && _scheduleDays.isNotEmpty ? _scheduleDays : null;
    final updated = widget.device.copyWith(
      name: _name.text.trim(),
      vendor: _vendor.text.trim(),
      batchNumber: _batch.text.trim(),
      coaUrl: _coa.text.trim().isEmpty ? null : _coa.text.trim(),
      reconstitutionDate: DateFormat('yyyy-MM-dd').format(_reconDate),
      schedule: _schedule,
      scheduleStartDate: newStartKey,
      scheduleDays: days,
      clearScheduleDays: days == null,
      expiryDays: _expiryDays,
      remainingDoses: remainingDoses,
      alertThresholdPct: _alertPct,
    );

    await ref.read(appProvider.notifier).updateDevice(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: context.clrText,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Edit Compound',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.clrText))),
              ]),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _label(context, 'Compound name *'),
                    _textField(_name, context,
                        hint: 'e.g. BPC-157',
                        caps: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null),
                    _label(context, 'Vendor'),
                    _textField(_vendor, context,
                        hint: 'e.g. Peptide Sciences',
                        caps: TextCapitalization.words),
                    _label(context, 'Batch number'),
                    _textField(_batch, context,
                        hint: 'e.g. PS-2024-12',
                        caps: TextCapitalization.characters),
                    _label(context, 'COA URL'),
                    _textField(_coa, context,
                        hint: 'https://', keyboard: TextInputType.url),
                    _label(context, 'Doses remaining now'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'You can update the total calculated if this vial was already in progress',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.clrTextHint,
                          height: 1.3,
                        ),
                      ),
                    ),
                    _textField(
                      _remainingDosesCtrl,
                      context,
                      hint: 'e.g. ${widget.device.totalDoses}',
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final parsed = int.tryParse(v.trim());
                        if (parsed == null) return 'Enter a whole number';
                        if (parsed <= 0) return 'Must be at least 1';
                        if (parsed > widget.device.totalDoses) {
                          return 'Cannot exceed total doses (${widget.device.totalDoses})';
                        }
                        return null;
                      },
                    ),

                    // Recon date picker
                    _label(context, 'Reconstitution date *'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
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
                                style: TextStyle(
                                    fontSize: 15, color: context.clrText)),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: context.clrTextHint),
                          ]),
                        ),
                      ),
                    ),

                    // Schedule
                    _label(context, 'Dose frequency'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DoseSchedule.values.map((s) {
                          final active = _schedule == s;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _schedule = s;
                              _scheduleDays = _defaultDays(s);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color:
                                    active ? context.clrTealBg : context.clrBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: active
                                      ? AppColors.teal
                                      : context.clrBorder,
                                  width: active ? 1.5 : 0.5,
                                ),
                              ),
                              child: Text(s.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: active
                                        ? AppColors.tealDark
                                        : context.clrTextSub,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Day picker
                    if (_needsDayPicker) ...[
                      Row(children: [
                        _label(
                            context,
                            _schedule == DoseSchedule.custom
                                ? 'Select days'
                                : 'Dose days'),
                        const SizedBox(width: 4),
                        if (_requiredDays != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('(pick $_requiredDays)',
                                style: TextStyle(
                                    fontSize: 11, color: context.clrTextHint)),
                          ),
                      ]),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: List.generate(7, (i) {
                            final weekday = i + 1;
                            final selected = _scheduleDays.contains(weekday);
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _toggleDay(weekday),
                                child: Container(
                                  margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.teal
                                        : context.clrBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.teal
                                          : context.clrBorder,
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
                      ),
                    ],

                    _label(context, 'Start date'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: _pickScheduleStartDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: context.clrSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.clrBorder),
                          ),
                          child: Row(children: [
                            const Icon(Icons.event_rounded,
                                size: 16, color: AppColors.teal),
                            const SizedBox(width: 10),
                            Text(
                                DateFormat('MMMM d, yyyy')
                                    .format(_scheduleStartDate),
                                style: TextStyle(
                                    fontSize: 15, color: context.clrText)),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: context.clrTextHint),
                          ]),
                        ),
                      ),
                    ),

                    // Alert threshold
                    _label(context, 'Low stock alert at'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Row(
                        children: [5, 10, 20].map((t) {
                          final active = _alertPct == t;
                          return Expanded(
                              child: Padding(
                            padding: EdgeInsets.only(right: t != 30 ? 10 : 0),
                            child: GestureDetector(
                              onTap: () => setState(() => _alertPct = t),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: active
                                      ? context.clrTealBg
                                      : context.clrBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.teal
                                        : context.clrBorder,
                                    width: active ? 1.5 : 0.5,
                                  ),
                                ),
                                child: Center(
                                    child: Text('$t%',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: active
                                              ? AppColors.tealDark
                                              : context.clrTextSub,
                                        ))),
                              ),
                            ),
                          ));
                        }).toList(),
                      ),
                    ),

                    // Expiry window
                    _label(context, 'Stability / expiry window'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ..._expiryOptions.map((days) {
                                final active =
                                    !_useCustomExpiry && _expiryDays == days;
                                return Expanded(
                                    child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _useCustomExpiry = false;
                                      _expiryDays = days;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? context.clrTealBg
                                            : context.clrBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: active
                                              ? AppColors.teal
                                              : context.clrBorder,
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
                                      _customExpiryCtrl.text =
                                          _expiryDays.toString();
                                    }
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
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
                                      child: Text(
                                        'Custom',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _useCustomExpiry
                                              ? AppColors.tealDark
                                              : context.clrTextSub,
                                        ),
                                      ),
                                    ),
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
                              validator: (v) {
                                if (!_useCustomExpiry) return null;
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter days (10-90)';
                                }
                                final parsed = int.tryParse(v.trim());
                                if (parsed == null) {
                                  return 'Enter a whole number';
                                }
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
                        ],
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save changes'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.clrAmberBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 15, color: AppColors.amber),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                              'Dosing values (peptide mg, recon volume, dose mcg) cannot be edited after enrollment as they affect remaining dose counts. Archive this compound and re-enroll to change them.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.amberDark,
                                  height: 1.4),
                            )),
                          ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.clrTextSub,
                letterSpacing: 0.2)),
      );

  Widget _textField(
    TextEditingController ctrl,
    BuildContext context, {
    required String hint,
    TextCapitalization caps = TextCapitalization.none,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: ctrl,
          validator: validator,
          keyboardType: keyboard,
          textCapitalization: caps,
          style: TextStyle(fontSize: 15, color: context.clrText),
          decoration: InputDecoration(hintText: hint),
        ),
      );
}
