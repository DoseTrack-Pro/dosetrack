import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../theme/app_theme.dart';

class StepTypeMethod extends StatefulWidget {
  final ContainerType initialType;
  final bool initialUseNfc;
  final void Function(ContainerType type, bool useNfc) onNext;

  const StepTypeMethod({super.key, required this.initialType, required this.initialUseNfc, required this.onNext});

  @override
  State<StepTypeMethod> createState() => _StepTypeMethodState();
}

class _StepTypeMethodState extends State<StepTypeMethod> {
  late ContainerType _type;
  late bool _useNfc;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _useNfc = widget.initialUseNfc;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Container Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('What are you enrolling?', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _TypeCard(label: 'Injectable Pen', tag: 'PEN',
              tagBg: AppColors.purpleLight, tagFg: AppColors.purpleDark,
              selected: _type == ContainerType.pen,
              onTap: () => setState(() => _type = ContainerType.pen))),
          const SizedBox(width: 12),
          Expanded(child: _TypeCard(label: 'Vial', tag: 'VIAL',
              tagBg: AppColors.tealLight, tagFg: AppColors.tealDark,
              selected: _type == ContainerType.vial,
              onTap: () => setState(() => _type = ContainerType.vial))),
        ]),
        const SizedBox(height: 28),

        const Text('Tracking Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('How will you identify this container?', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _MethodCard(label: 'NFC Tag', subtitle: 'Scan to log automatically',
              recommended: true, selected: _useNfc,
              onTap: () => setState(() => _useNfc = true))),
          const SizedBox(width: 12),
          Expanded(child: _MethodCard(label: 'Manual', subtitle: 'Select from app to log',
              recommended: false, selected: !_useNfc,
              onTap: () => setState(() => _useNfc = false))),
        ]),
        const SizedBox(height: 28),

        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onNext(_type, _useNfc),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label, tag;
  final Color tagBg, tagFg;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({required this.label, required this.tag, required this.tagBg, required this.tagFg, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.tealLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.teal : AppColors.border, width: selected ? 2 : 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(4)),
            child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tagFg))),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: selected ? AppColors.tealDark : AppColors.textPrimary)),
      ]),
    ),
  );
}

class _MethodCard extends StatelessWidget {
  final String label, subtitle;
  final bool recommended, selected;
  final VoidCallback onTap;
  const _MethodCard({required this.label, required this.subtitle, required this.recommended, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.tealLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.teal : AppColors.border, width: selected ? 2 : 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (recommended) ...[
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(4)),
              child: const Text('Recommended', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
          const SizedBox(height: 6),
        ],
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: selected ? AppColors.tealDark : AppColors.textPrimary)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
      ]),
    ),
  );
}
