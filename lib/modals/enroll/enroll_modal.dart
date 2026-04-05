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

  // Accumulated form data
  ContainerType _type = ContainerType.pen;
  bool _useNfc = true;
  String? _nfcTagId;
  String _name = '', _vendor = '', _batchNumber = '', _coaUrl = '', _reconDate = '';
  double _peptideMg = 0, _reconMl = 0, _desiredMcg = 0;
  DoseSchedule _schedule = DoseSchedule.dailyAm;
  int _alertPct = 20;

  bool get _isNfcFlow => _useNfc;
  int get _totalSteps => _isNfcFlow ? 4 : 3;

  int get _displayStep {
    if (!_isNfcFlow && _step >= 2) return _step - 1;
    return _step;
  }

  void _next() => setState(() => _step++);

  void _back() {
    if (_step == 0) { Navigator.pop(context); return; }
    if (_step == 2 && !_isNfcFlow) { setState(() => _step = 0); return; }
    setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      await ref.read(appProvider.notifier).enrollDevice(
        name: _name, type: _type, vendor: _vendor,
        batchNumber: _batchNumber, coaUrl: _coaUrl,
        reconstitutionDate: _reconDate,
        peptideMg: _peptideMg, reconVolumeMl: _reconMl,
        desiredDoseMcg: _desiredMcg, schedule: _schedule,
        alertThresholdPct: _alertPct,
        nfcTagId: _nfcTagId,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrollment failed: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(children: [
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                GestureDetector(
                  onTap: _back,
                  child: Text(_step == 0 ? 'Cancel' : '← Back',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.teal)),
                ),
                const Expanded(child: Center(child: Text('Enroll Container',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)))),
                const SizedBox(width: 60),
              ]),
              const SizedBox(height: 14),
              // Progress bar
              Row(
                children: List.generate(_totalSteps, (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 5 : 0),
                    decoration: BoxDecoration(
                      color: i <= _displayStep ? AppColors.teal : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ]),
          ),
          const SizedBox(height: 4),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: _buildStep(),
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
        onNext: (type, useNfc) {
          setState(() { _type = type; _useNfc = useNfc; });
          if (!useNfc) { setState(() => _step = 2); } else { _next(); }
        },
      );
    }

    if (_step == 1 && _isNfcFlow) {
      return StepNfcScan(
        onTagWritten: (tagId) { setState(() => _nfcTagId = tagId); _next(); },
        onSkip: () { setState(() { _useNfc = false; _nfcTagId = null; _step = 2; }); },
      );
    }

    if (_step == 2) {
      return StepCompoundDetails(
        initialName: _name, initialVendor: _vendor,
        initialBatch: _batchNumber, initialCoa: _coaUrl, initialDate: _reconDate,
        onNext: (name, vendor, batch, coa, date) {
          setState(() { _name = name; _vendor = vendor; _batchNumber = batch; _coaUrl = coa; _reconDate = date; });
          _next();
        },
      );
    }

    return StepDosingConfig(
      onFinish: (mg, ml, mcg, schedule, alertPct) {
        setState(() { _peptideMg = mg; _reconMl = ml; _desiredMcg = mcg; _schedule = schedule; _alertPct = alertPct; });
        _finish();
      },
      loading: _loading,
    );
  }
}
