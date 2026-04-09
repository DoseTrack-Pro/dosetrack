import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/calculations.dart';

enum _CalcMode { draw, water }

class ReconCalculatorModal extends StatefulWidget {
  const ReconCalculatorModal({super.key});

  @override
  State<ReconCalculatorModal> createState() => _ReconCalculatorModalState();
}

class _ReconCalculatorModalState extends State<ReconCalculatorModal> {
  _CalcMode _mode = _CalcMode.draw;

  // Draw mode: peptide mg + recon mL + dose mcg → IU to draw + total doses
  final _mgCtrl = TextEditingController();
  final _mlCtrl = TextEditingController();
  final _mcgCtrl = TextEditingController();

  // Water mode: peptide mg + dose mcg + desired doses → BAC water mL + IU to draw
  final _mgWCtrl = TextEditingController();
  final _mcgWCtrl = TextEditingController();
  final _dosesCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _mgCtrl,
      _mlCtrl,
      _mcgCtrl,
      _mgWCtrl,
      _mcgWCtrl,
      _dosesCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Draw mode results
  double get _drawMg => double.tryParse(_mgCtrl.text) ?? 0;
  double get _drawMl => double.tryParse(_mlCtrl.text) ?? 0;
  double get _drawMcg => double.tryParse(_mcgCtrl.text) ?? 0;
  double get _drawIu => calcDoseIu(_drawMg, _drawMl, _drawMcg);
  int get _drawTotal => calcTotalDoses(_drawMl, _drawIu);

  // Water mode results
  double get _waterMg => double.tryParse(_mgWCtrl.text) ?? 0;
  double get _waterMcg => double.tryParse(_mcgWCtrl.text) ?? 0;
  int get _waterDoses => int.tryParse(_dosesCtrl.text) ?? 0;
  double get _waterMl => calcReconVolume(_waterMg, _waterMcg, _waterDoses);
  double get _waterIu => calcDoseIu(_waterMg, _waterMl, _waterMcg);

  bool get _drawReady =>
      _drawMg > 0 && _drawMl > 0 && _drawMcg > 0 && _drawIu > 0;
  bool get _waterReady =>
      _waterMg > 0 && _waterMcg > 0 && _waterDoses > 0 && _waterMl > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.clrSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.clrBorderStrong,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),

              Row(children: [
                const Icon(Icons.calculate_outlined,
                    color: AppColors.teal, size: 22),
                const SizedBox(width: 10),
                Text('Reconstitution Calculator',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.clrText)),
              ]),
              const SizedBox(height: 4),
              Text('Calculate draw volumes and BAC water amounts',
                  style: TextStyle(fontSize: 13, color: context.clrTextSub)),
              const SizedBox(height: 20),

              // Mode toggle
              Container(
                decoration: BoxDecoration(
                  color: context.clrBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.clrBorder, width: 0.5),
                ),
                child: Row(children: [
                  _ModeTab(
                    label: 'How much to draw?',
                    icon: Icons.colorize_rounded,
                    active: _mode == _CalcMode.draw,
                    onTap: () => setState(() => _mode = _CalcMode.draw),
                  ),
                  _ModeTab(
                    label: 'How much BAC water?',
                    icon: Icons.water_drop_outlined,
                    active: _mode == _CalcMode.water,
                    onTap: () => setState(() => _mode = _CalcMode.water),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              if (_mode == _CalcMode.draw) ...[
                Text('INPUTS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.clrTextSub,
                        letterSpacing: 0.7)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _CalcField(
                          label: 'Peptide (mg)',
                          hint: 'e.g. 5',
                          controller: _mgCtrl,
                          onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _CalcField(
                          label: 'BAC water (mL)',
                          hint: 'e.g. 2',
                          controller: _mlCtrl,
                          onChanged: (_) => setState(() {}))),
                ]),
                _CalcField(
                    label: 'Desired dose (mcg)',
                    hint: 'e.g. 250',
                    controller: _mcgCtrl,
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 16),
                if (_drawReady) ...[
                  _ResultCard(
                    items: [
                      _ResultItem(
                          label: 'Draw volume',
                          value: '${_drawIu.toStringAsFixed(1)} IU',
                          primary: true),
                      _ResultItem(
                          label: 'Total doses from vial',
                          value: '$_drawTotal doses'),
                    ],
                  ),
                ] else
                  _PlaceholderCard(
                      text: 'Fill in all three fields above to see results'),
              ],

              if (_mode == _CalcMode.water) ...[
                Text('INPUTS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.clrTextSub,
                        letterSpacing: 0.7)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _CalcField(
                          label: 'Peptide (mg)',
                          hint: 'e.g. 5',
                          controller: _mgWCtrl,
                          onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _CalcField(
                          label: 'Desired dose (mcg)',
                          hint: 'e.g. 250',
                          controller: _mcgWCtrl,
                          onChanged: (_) => setState(() {}))),
                ]),
                _CalcField(
                    label: 'Doses you want from vial',
                    hint: 'e.g. 20',
                    controller: _dosesCtrl,
                    keyboard: TextInputType.number,
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 16),
                if (_waterReady) ...[
                  _ResultCard(
                    items: [
                      _ResultItem(
                          label: 'Add this much BAC water',
                          value: '${_waterMl.toStringAsFixed(2)} mL',
                          primary: true),
                      _ResultItem(
                          label: 'Draw volume per dose',
                          value: '${_waterIu.toStringAsFixed(1)} IU'),
                    ],
                  ),
                ] else
                  _PlaceholderCard(
                      text: 'Fill in all three fields above to see results'),
              ],

              const SizedBox(height: 20),

              // Reference note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.clrBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.clrBorder, width: 0.5),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Formula reference',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.clrTextSub,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text('IU = (mcg ÷ (mg × 1000)) × mL × 100',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.clrTextHint,
                              fontFamily: 'Inter',
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                      const SizedBox(height: 4),
                      Text(
                          'IU markings on a U-100 insulin syringe represent μL of volume.',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.clrTextHint,
                              height: 1.4)),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.teal : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 14, color: active ? Colors.white : context.clrTextSub),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : context.clrTextSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      );
}

class _CalcField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final void Function(String) onChanged;
  final TextInputType keyboard;
  const _CalcField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.keyboard = const TextInputType.numberWithOptions(decimal: true),
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.clrTextSub,
                  letterSpacing: 0.2)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: keyboard,
            style: TextStyle(fontSize: 15, color: context.clrText),
            decoration: InputDecoration(hintText: hint),
          ),
        ]),
      );
}

class _ResultCard extends StatelessWidget {
  final List<_ResultItem> items;
  const _ResultCard({required this.items});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.clrTealBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.teal.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          children: items.asMap().entries.map((e) {
            final item = e.value;
            final isLast = e.key == items.length - 1;
            return Expanded(
                child: Row(children: [
              Expanded(
                  child: Column(children: [
                Text(item.label,
                    style: TextStyle(fontSize: 11, color: AppColors.tealDeep),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.value,
                        style: TextStyle(
                          fontSize: item.primary ? 28 : 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealDark,
                          fontFamily: 'Inter',
                          fontFeatures: [FontFeature.tabularFigures()],
                        ))),
              ])),
              if (!isLast)
                Container(
                    width: 0.5,
                    height: 44,
                    color: AppColors.tealMid,
                    margin: const EdgeInsets.symmetric(horizontal: 8)),
            ]));
          }).toList(),
        ),
      );
}

class _ResultItem {
  final String label, value;
  final bool primary;
  const _ResultItem(
      {required this.label, required this.value, this.primary = false});
}

class _PlaceholderCard extends StatelessWidget {
  final String text;
  const _PlaceholderCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.clrBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.clrBorder, width: 0.5),
        ),
        child: Center(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: context.clrTextHint),
                textAlign: TextAlign.center)),
      );
}
