import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'step_type_method.dart';
import 'step_nfc_scan.dart';
import 'step_compound_details.dart';
import 'step_dosing_config.dart';

class EnrollModal extends ConsumerStatefulWidget {
  const EnrollModal({super.key});

  @override
  ConsumerState<EnrollModal> createState() => _EnrollModalState();
}

class _EnrollModalState extends ConsumerState<EnrollModal> {
  int _step = 0;
  bool _loading = false;

  ContainerType _type = ContainerType.pen;
  bool _useNfc = true;
  String? _nfcTagId;
  String _name = '',
      _vendor = '',
      _batchNumber = '',
      _coaUrl = '',
      _reconDate = '';
  double _peptideMg = 0, _reconMl = 0, _desiredMcg = 0;
  bool _isBlend = false;
  List<BlendComponent>? _blendComponents;
  int _expiryDays = 30;
  DoseSchedule _schedule = DoseSchedule.dailyAm;
  String _scheduleStartDate = '';
  List<int>? _scheduleDays;
  int _alertPct = 20;
  int? _startingRemainingDoses;

  bool get _isNfcFlow => _useNfc;
  int get _totalSteps => _isNfcFlow ? 4 : 3;

  int get _displayStep {
    if (!_isNfcFlow && _step >= 2) return _step - 1;
    return _step;
  }

  void _next() => setState(() => _step++);

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    if (_step == 2 && !_isNfcFlow) {
      setState(() => _step = 0);
      return;
    }
    setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      await ref.read(appProvider.notifier).enrollDevice(
            name: _name,
            type: _type,
            vendor: _vendor,
            batchNumber: _batchNumber,
            coaUrl: _coaUrl,
            reconstitutionDate: _reconDate,
            peptideMg: _peptideMg,
            reconVolumeMl: _reconMl,
            desiredDoseMcg: _desiredMcg,
            isBlend: _isBlend,
            blendComponents: _blendComponents,
            schedule: _schedule,
            scheduleStartDate: _scheduleStartDate,
            scheduleDays: _scheduleDays,
            alertThresholdPct: _alertPct,
            startingRemainingDoses: _startingRemainingDoses,
            expiryDays: _expiryDays,
            nfcTagId: _nfcTagId,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Enrollment failed: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final safeBottomInset = media.viewPadding.bottom;
    final contentBottomPadding =
        28.0 + (safeBottomInset > 12 ? safeBottomInset : 12);
    return Container(
      height: media.size.height * 0.92,
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.clrBorderStrong,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                GestureDetector(
                  onTap: _back,
                  child: Text(_step == 0 ? 'Cancel' : '← Back',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.teal)),
                ),
                Expanded(
                    child: Center(
                        child: Text('Enroll Compound',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: context.clrText)))),
                const SizedBox(width: 60),
              ]),
              const SizedBox(height: 14),
              Row(
                children: List.generate(
                    _totalSteps,
                    (i) => Expanded(
                          child: Container(
                            height: 3,
                            margin: EdgeInsets.only(
                                right: i < _totalSteps - 1 ? 5 : 0),
                            decoration: BoxDecoration(
                              color: i <= _displayStep
                                  ? AppColors.teal
                                  : context.clrBorder,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        )),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 16, 20, contentBottomPadding),
                child: _buildStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return StepTypeMethod(
        initialType: _type,
        initialUseNfc: _useNfc,
        previousDevices: ref.watch(devicesProvider),
        onCopyPrevious: (d) => setState(() {
          _type = d.type;
          _name = d.name;
          _vendor = d.vendor;
          _peptideMg = d.peptideMg;
          _reconMl = d.reconVolumeMl;
          _desiredMcg = d.desiredDoseMcg;
          _isBlend = d.isBlend;
          _blendComponents = d.blendComponents;
          _schedule = d.schedule;
          _scheduleStartDate = d.scheduleStartDate ?? '';
          _scheduleDays =
              d.scheduleDays != null ? List<int>.from(d.scheduleDays!) : null;
          _alertPct = d.alertThresholdPct;
          _expiryDays = d.expiryDays;
          _step = 2;
        }),
        onNext: (type, useNfc) {
          setState(() {
            _type = type;
            _useNfc = useNfc;
          });
          if (!useNfc) {
            setState(() => _step = 2);
          } else {
            _next();
          }
        },
      );
    }

    if (_step == 1 && _isNfcFlow) {
      return StepNfcScan(
        onTagWritten: (tagId) {
          setState(() => _nfcTagId = tagId);
          _next();
        },
        onSkip: () {
          setState(() {
            _useNfc = false;
            _nfcTagId = null;
            _step = 2;
          });
        },
      );
    }

    if (_step == 2) {
      return StepCompoundDetails(
        initialName: _name,
        initialVendor: _vendor,
        initialBatch: _batchNumber,
        initialCoa: _coaUrl,
        initialDate: _reconDate,
        initialExpiryDays: _expiryDays,
        onNext: (name, vendor, batch, coa, date, expiryDays) {
          setState(() {
            _name = name;
            _vendor = vendor;
            _batchNumber = batch;
            _coaUrl = coa;
            _reconDate = date;
            _expiryDays = expiryDays;
          });
          _next();
        },
      );
    }

    return StepDosingConfig(
      initialMg: _peptideMg,
      initialMl: _reconMl,
      initialMcg: _desiredMcg,
      initialIsBlend: _isBlend,
      initialBlendComponents: _blendComponents,
      initialSchedule: _schedule,
      initialStartDate: _scheduleStartDate,
      initialScheduleDays: _scheduleDays,
      initialAlertPct: _alertPct,
      initialStartingRemainingDoses: _startingRemainingDoses,
      onFinish: (mg, ml, mcg, isBlend, blendComponents, schedule, scheduleDays,
          scheduleStartDate, alertPct, startingRemainingDoses) {
        setState(() {
          _peptideMg = mg;
          _reconMl = ml;
          _desiredMcg = mcg;
          _isBlend = isBlend;
          _blendComponents = blendComponents;
          _schedule = schedule;
          _scheduleStartDate = scheduleStartDate;
          _scheduleDays = scheduleDays;
          _alertPct = alertPct;
          _startingRemainingDoses = startingRemainingDoses;
        });
        _finish();
      },
      loading: _loading,
    );
  }
}
