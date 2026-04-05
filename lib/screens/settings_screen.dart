import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _doseReminders  = true;
  bool _lowInventory   = true;
  bool _missedDose     = false;
  bool _autoLog        = true;
  bool _confirmLog     = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: const Row(children: [
                Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Section(title: 'Notifications', children: [
                    _ToggleRow(label: 'Dose reminders', subtitle: 'Alert when a dose is due', value: _doseReminders, onChanged: (v) => setState(() => _doseReminders = v)),
                    _ToggleRow(label: 'Low inventory', subtitle: 'Alert when container is running low', value: _lowInventory, onChanged: (v) => setState(() => _lowInventory = v)),
                    _ToggleRow(label: 'Missed dose', subtitle: 'Alert when a scheduled dose was skipped', value: _missedDose, onChanged: (v) => setState(() => _missedDose = v)),
                  ]),
                  const SizedBox(height: 20),
                  _Section(title: 'NFC Scanning', children: [
                    _ToggleRow(label: 'Auto-log on scan', subtitle: 'Record dose immediately when tag detected', value: _autoLog, onChanged: (v) => setState(() => _autoLog = v)),
                    _ToggleRow(label: 'Confirm before logging', subtitle: 'Show confirmation before saving dose', value: _confirmLog, onChanged: (v) => setState(() => _confirmLog = v)),
                  ]),
                  const SizedBox(height: 20),
                  _Section(title: 'Inventory Thresholds', children: [
                    const _InfoRow(label: 'Low stock alert', value: '20% remaining'),
                    const _InfoRow(label: 'Critical alert', value: '10% remaining'),
                  ]),
                  const SizedBox(height: 20),
                  _Section(title: 'Data & Export', children: [
                    _ActionRow(label: 'Export as CSV', subtitle: 'Download all data as a spreadsheet', onTap: _exportCsv),
                    _ActionRow(label: 'Export as PDF', subtitle: 'Download a formatted dose report', onTap: _exportPdf),
                  ]),
                  const SizedBox(height: 20),
                  _Section(title: 'Danger Zone', children: [
                    _ActionRow(label: 'Clear all data', subtitle: 'Permanently erase all containers and logs', danger: true, onTap: _clearData),
                  ]),
                  const SizedBox(height: 32),
                  const Center(
                    child: Text('PeptideTrack v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final state = ref.read(appProvider);
    try {
      await ExportService.instance.exportCsv(state.devices, state.doseLogs);
    } catch (e) {
      if (mounted) _showError('CSV export failed: $e');
    }
  }

  Future<void> _exportPdf() async {
    final state = ref.read(appProvider);
    try {
      await ExportService.instance.exportPdf(state.devices, state.doseLogs);
    } catch (e) {
      if (mounted) _showError('PDF export failed: $e');
    }
  }

  void _clearData() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete all containers and dose history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(appProvider.notifier).clearAllData();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 0.7)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: children.indexed.map((entry) {
              final idx = entry.$1;
              final child = entry.$2;
              return Column(children: [
                child,
                if (idx < children.length - 1)
                  const Divider(height: 0, indent: 16),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.teal),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
        Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;
  const _ActionRow({required this.label, required this.subtitle, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                color: danger ? AppColors.red : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Icon(Icons.chevron_right_rounded, color: danger ? AppColors.red : AppColors.textTertiary, size: 20),
        ]),
      ),
    );
  }
}
