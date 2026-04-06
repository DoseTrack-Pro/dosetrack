import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_state.dart';
import 'screens/main_scaffold.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

class PeptideTrackApp extends ConsumerWidget {
  const PeptideTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'PeptideTrack',
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
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(appProvider.notifier).initialize();
      if (!SettingsService.instance.onboardingComplete && mounted) {
        setState(() => _showOnboarding = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: () {
        SettingsService.instance.setOnboardingComplete();
        setState(() => _showOnboarding = false);
      });
    }
    return const MainScaffold();
  }
}
