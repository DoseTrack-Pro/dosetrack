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
      body: 'Attach an inexpensive NFC sticker to each compound. Tap your phone to the tag to log doses in seconds — no menus needed.',
    ),
    _OnboardingPage(
      icon: Icons.bar_chart_rounded,
      title: 'Track & Analyze',
      body: 'See adherence, streaks, injection site rotation, and projected depletion dates — everything you need to stay consistent.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: context.clrTealBg, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.teal, size: 48),
          ),
          const SizedBox(height: 36),
          Text(title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                color: context.clrText, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(body,
            style: TextStyle(fontSize: 16, color: context.clrTextSub, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
