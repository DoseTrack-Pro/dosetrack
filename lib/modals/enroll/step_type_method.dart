import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../theme/app_theme.dart';

class StepTypeMethod extends StatefulWidget {
  final ContainerType initialType;
  final bool initialUseNfc;
  final List<Device> previousDevices;
  final void Function(ContainerType type, bool useNfc) onNext;
  final void Function(Device device) onCopyPrevious;

  const StepTypeMethod({
    super.key,
    required this.initialType,
    required this.initialUseNfc,
    required this.onNext,
    required this.onCopyPrevious,
    this.previousDevices = const [],
  });

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
        Text('Compound Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.clrText)),
        const SizedBox(height: 4),
        Text('What are you enrolling?', style: TextStyle(fontSize: 14, color: context.clrTextSub)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _TypeCard(label: 'Injectable Pen', tag: 'PEN',
              tagBg: context.clrPurpleBg, tagFg: AppColors.purpleDark,
              selected: _type == ContainerType.pen,
              onTap: () => setState(() => _type = ContainerType.pen))),
          const SizedBox(width: 12),
          Expanded(child: _TypeCard(label: 'Vial', tag: 'VIAL',
              tagBg: context.clrTealBg, tagFg: AppColors.tealDark,
              selected: _type == ContainerType.vial,
              onTap: () => setState(() => _type = ContainerType.vial))),
        ]),
        const SizedBox(height: 28),

        Text('Tracking Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.clrText)),
        const SizedBox(height: 4),
        Text('How will you identify this compound?', style: TextStyle(fontSize: 14, color: context.clrTextSub)),
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

        // Re-enroll previous
        if (widget.previousDevices.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('RE-ENROLL PREVIOUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: context.clrTextSub, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...widget.previousDevices.take(5).map((d) => GestureDetector(
            onTap: () => widget.onCopyPrevious(d),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: context.clrBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.clrBorder, width: 0.5),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: context.clrText), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${d.vendor}  ·  ${d.desiredDoseMcg.toStringAsFixed(0)}mcg  ·  ${d.schedule.label}',
                        style: TextStyle(fontSize: 12, color: context.clrTextSub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                const SizedBox(width: 8),
                const Text('Copy →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
              ]),
            ),
          )),
        ],
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
        color: selected ? context.clrTealBg : context.clrBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.teal : context.clrBorder, width: selected ? 2 : 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(4)),
            child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tagFg))),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: selected ? AppColors.tealDark : context.clrText)),
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
        color: selected ? context.clrTealBg : context.clrBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.teal : context.clrBorder, width: selected ? 2 : 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (recommended) ...[
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(4)),
              child: const Text('Recommended', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
          const SizedBox(height: 6),
        ],
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: selected ? AppColors.tealDark : context.clrText)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(fontSize: 12, color: context.clrTextSub, height: 1.3)),
      ]),
    ),
  );
}
