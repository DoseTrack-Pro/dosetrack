import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BadgeChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const BadgeChip({super.key, required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
