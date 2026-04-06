import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/protocol.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class CreateProtocolModal extends ConsumerStatefulWidget {
  /// If non-null, we are editing an existing protocol.
  final Protocol? existing;

  const CreateProtocolModal({super.key, this.existing});

  @override
  ConsumerState<CreateProtocolModal> createState() => _CreateProtocolModalState();
}

class _CreateProtocolModalState extends ConsumerState<CreateProtocolModal> {
  final _nameCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  late DateTime _startDate;
  DateTime? _endDate;
  Set<String> _selectedDeviceIds = {};
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _nameCtrl.text  = ex.name;
      _notesCtrl.text = ex.notes ?? '';
      _startDate = ex.startDate;
      _endDate   = ex.endDate;
      // Pre-select currently assigned devices
      final deviceProtocols = ref.read(deviceProtocolsProvider);
      _selectedDeviceIds = deviceProtocols.entries
          .where((e) => e.value == ex.id)
          .map((e) => e.key)
          .toSet();
    } else {
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeviceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one compound for this protocol.'), backgroundColor: AppColors.amber),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(appProvider.notifier);
      final deviceIds = _selectedDeviceIds.toList();
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          clearEndDate: _endDate == null,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          clearNotes: _notesCtrl.text.trim().isEmpty,
        );
        await notifier.updateProtocol(updated, deviceIds);
      } else {
        await notifier.createProtocol(
          name: _nameCtrl.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          deviceIds: deviceIds,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDevices = ref.watch(activeDevicesProvider);
    final fmt = DateFormat('MMM d, yyyy');

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(children: [
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: context.clrBorderStrong, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.teal)),
                ),
                Expanded(child: Center(child: Text(_isEditing ? 'Edit Protocol' : 'New Protocol',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.clrText)))),
                const SizedBox(width: 60),
              ]),
            ]),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  // Name
                  _label(context, 'Protocol name *'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(fontSize: 15, color: context.clrText),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: const InputDecoration(hintText: 'e.g. Healing Protocol'),
                    ),
                  ),

                  // Dates
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label(context, 'Start date'),
                      GestureDetector(
                        onTap: _pickStartDate,
                        child: _DateButton(text: fmt.format(_startDate)),
                      ),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label(context, 'Goal / end date'),
                      GestureDetector(
                        onTap: _pickEndDate,
                        child: _DateButton(
                          text: _endDate != null ? fmt.format(_endDate!) : 'None (ongoing)',
                          placeholder: _endDate == null,
                          trailing: _endDate != null
                              ? GestureDetector(
                                  onTap: () => setState(() => _endDate = null),
                                  child: Icon(Icons.close_rounded, size: 14, color: context.clrTextHint),
                                )
                              : null,
                        ),
                      ),
                    ])),
                  ]),

                  if (_endDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${_endDate!.difference(_startDate).inDays + 1}-day protocol',
                      style: TextStyle(fontSize: 12, color: context.clrTextHint),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Compounds
                  _label(context, 'Compounds in this protocol *'),
                  const SizedBox(height: 4),
                  Text('Tap to include. A compound can only be in one protocol at a time.',
                      style: TextStyle(fontSize: 12, color: context.clrTextHint)),
                  const SizedBox(height: 10),

                  if (activeDevices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('No active compounds to include.',
                          style: TextStyle(fontSize: 13, color: context.clrTextHint)),
                    )
                  else
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: activeDevices.map((device) {
                        final selected = _selectedDeviceIds.contains(device.id);
                        // Check if assigned to a different protocol
                        final deviceProtocols = ref.watch(deviceProtocolsProvider);
                        final assignedProtocolId = deviceProtocols[device.id];
                        final inOtherProtocol = assignedProtocolId != null &&
                            assignedProtocolId != widget.existing?.id;

                        return GestureDetector(
                          onTap: inOtherProtocol ? null : () {
                            setState(() {
                              if (selected) {
                                _selectedDeviceIds.remove(device.id);
                              } else {
                                _selectedDeviceIds.add(device.id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: inOtherProtocol
                                  ? context.clrBg
                                  : selected ? context.clrTealBg : context.clrBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: inOtherProtocol
                                    ? context.clrBorder
                                    : selected ? AppColors.teal : context.clrBorder,
                                width: selected ? 1.5 : 0.5,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (selected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(Icons.check_circle_rounded, size: 14, color: AppColors.teal),
                                ),
                              Text(device.name, style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: inOtherProtocol
                                    ? context.clrTextHint
                                    : selected ? AppColors.tealDark : context.clrText,
                              )),
                              if (inOtherProtocol)
                                Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Text('(other)', style: TextStyle(fontSize: 10, color: context.clrTextHint)),
                                ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 18),

                  // Notes
                  _label(context, 'Notes (optional)'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: TextStyle(fontSize: 14, color: context.clrText),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Post-surgery recovery, started after shoulder labrum repair…',
                      ),
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : (_isEditing ? 'Save Changes' : 'Create Protocol')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: context.clrTextSub, letterSpacing: 0.2)),
  );
}

class _DateButton extends StatelessWidget {
  final String text;
  final bool placeholder;
  final Widget? trailing;
  const _DateButton({required this.text, this.placeholder = false, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: context.clrSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.clrBorder),
    ),
    child: Row(children: [
      const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.teal),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(
        fontSize: 13,
        color: placeholder ? context.clrTextHint : context.clrText,
      ), maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (trailing != null) trailing!,
    ]),
  );
}
