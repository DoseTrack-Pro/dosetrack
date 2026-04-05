import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/toast_overlay.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'history_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  static const _screens = [
    DashboardScreen(),
    InventoryScreen(),
    HistoryScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Inventory'),
    BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
    BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ToastOverlay(
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            items: _items,
          ),
        ),
      ),
    );
  }
}
