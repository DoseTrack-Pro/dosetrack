import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_state.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/main_scaffold.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_gate.dart';

class PeptideTrackApp extends ConsumerWidget {
  const PeptideTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Pep Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: const _AppLoader(),
    );
  }
}

class _AppLoader extends ConsumerStatefulWidget {
  const _AppLoader();

  @override
  ConsumerState<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends ConsumerState<_AppLoader> {
  bool _loading = true;
  bool _showDisclaimer = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(appProvider.notifier).initialize();
      if (!mounted) return;
      final acceptedDisclaimer = SettingsService.instance.disclaimerAccepted;
      final onboardingComplete = SettingsService.instance.onboardingComplete;
      setState(() {
        _loading = false;
        _showDisclaimer = !acceptedDisclaimer;
        _showOnboarding = acceptedDisclaimer && !onboardingComplete;
      });
    });
  }

  Future<void> _acceptDisclaimer() async {
    await SettingsService.instance.setDisclaimerAccepted();
    if (!mounted) return;
    setState(() {
      _showDisclaimer = false;
      _showOnboarding = !SettingsService.instance.onboardingComplete;
    });
  }

  Future<void> _completeOnboarding() async {
    await SettingsService.instance.setOnboardingComplete();
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.clrBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_showDisclaimer) {
      return DisclaimerScreen(onAccept: _acceptDisclaimer);
    }

    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    return const AppLockGate(child: MainScaffold());
  }
}
