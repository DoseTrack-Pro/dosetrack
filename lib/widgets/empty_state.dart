import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.science_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: context.clrTealBg, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.teal, size: 36),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.clrText), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 14, color: context.clrTextSub, height: 1.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
