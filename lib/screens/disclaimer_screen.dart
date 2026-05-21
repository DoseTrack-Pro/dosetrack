import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/legal_text.dart';
import '../theme/app_theme.dart';

class DisclaimerScreen extends StatefulWidget {
  final VoidCallback onAccept;

  const DisclaimerScreen({super.key, required this.onAccept});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final horizontalPadding = isLandscape ? 24.0 : 20.0;
    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isLandscape ? 16 : 24,
                  horizontalPadding,
                  16,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Important Disclaimer',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: context.clrText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          kLegalDisclaimerText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: context.clrTextSub,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.clrAmberBg,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.amber, width: 0.5),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox.adaptive(
                                value: _acknowledged,
                                onChanged: (v) =>
                                    setState(() => _acknowledged = v ?? false),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    'I have read and agree to this disclaimer.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.clrText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _acknowledged ? widget.onAccept : null,
                      child: const Text('Agree and continue'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => SystemNavigator.pop(),
                      child: const Text('Decline and exit'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
