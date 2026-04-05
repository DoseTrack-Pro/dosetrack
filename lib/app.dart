import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_state.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';

class PeptideTrackApp extends ConsumerWidget {
  const PeptideTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PeptideTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppLoader(),
    );
  }
}

/// Loads data once, then shows the main scaffold.
class _AppLoader extends ConsumerStatefulWidget {
  const _AppLoader();

  @override
  ConsumerState<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends ConsumerState<_AppLoader> {
  @override
  void initState() {
    super.initState();
    // Safe: runs once after the first frame, not on every rebuild.
    Future.microtask(() => ref.read(appProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) => const MainScaffold();
}
