import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.science_outlined,
      title: 'Welcome to Pep Tracker Pro',
      body: 'Your personal peptide dose tracker. Enroll your pens and vials, log doses in seconds, and stay on schedule.',
    ),
    _OnboardingPage(
      icon: Icons.nfc_rounded,
      title: 'NFC-First Logging',
      body:
          'Use NFC your way: attach NFC tag to any pen or vial for quick tap-to-log, or use native support for NovoPen Echo Plus and NovoPen 6 to read built-in NFC dose history directly from the pen.',
    ),
    _OnboardingPage(
      icon: Icons.bar_chart_rounded,
      title: 'Track & Analyze',
      body: 'See adherence, streaks, injection site rotation, and projected depletion dates — everything you need to stay consistent.',
    ),
    _OnboardingPage(
      icon: Icons.shield_rounded,
      title: 'Privacy First',
      body:
          'Privacy by design: your data stays on your device. This app does not use cloud storage, so your compounds, logs, and analytics remain local and under your control.',
    ),
    _OnboardingPage(
      icon: Icons.check_circle_outline_rounded,
      title: 'You\'re ready',
      body: 'Tap "Get Started" to enroll your first compound. You can add NFC tags or track manually.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onComplete,
                child: Text('Skip', style: TextStyle(color: context.clrTextSub, fontSize: 14)),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? AppColors.teal : context.clrBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
            const SizedBox(height: 32),

            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingPage({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final horizontalPadding = isLandscape ? 20.0 : 40.0;
        final iconSize = isLandscape ? 72.0 : 100.0;
        final glyphSize = isLandscape ? 36.0 : 48.0;
        final titleSize = isLandscape ? 18.0 : 24.0;
        final bodySize = isLandscape ? 14.0 : 16.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration:
                      BoxDecoration(color: context.clrTealBg, shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.teal, size: glyphSize),
                ),
                SizedBox(height: isLandscape ? 18 : 36),
                Text(
                  title,
                  style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: context.clrText,
                      letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                      fontSize: bodySize, color: context.clrTextSub, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
