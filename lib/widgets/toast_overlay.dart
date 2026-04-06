import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ToastOverlay extends ConsumerWidget {
  final Widget child;
  const ToastOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(toastProvider);
    final undoLogId = ref.watch(undoLogIdProvider);
    final showUndo = undoLogId != null;

    return Stack(
      children: [
        child,
        if (message != null)
          Positioned(
            bottom: 96,
            left: 20, right: 20,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.clrSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.clrBorder, width: 0.5),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16, offset: const Offset(0, 4),
                  )],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(message,
                          style: TextStyle(color: context.clrText,
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    if (showUndo) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => ref.read(appProvider.notifier).undoLastDose(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Undo',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
