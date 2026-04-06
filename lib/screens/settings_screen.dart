import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _doseReminders;
  late bool _lowInventory;
  late bool _missedDose;
  late bool _autoLog;
  late bool _confirmLog;
  late int _nfcTimeout;
  late int _themeModePref;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _doseReminders = s.doseReminders;
    _lowInventory  = s.lowInventoryAlerts;
    _missedDose    = s.missedDoseAlerts;
    _autoLog       = s.nfcAutoLog;
    _confirmLog    = s.nfcConfirmLog;
    _nfcTimeout    = s.nfcScanTimeout;
    _themeModePref = s.themeModePref;
  }

  Future<void> _setDoseReminders(bool v) async {
    await SettingsService.instance.setDoseReminders(v);
    setState(() => _doseReminders = v);
    final devices = ref.read(devicesProvider).where((d) => d.active).toList();
    if (!v) {
      await NotificationService.instance.cancelAllReminders();
    } else {
      for (final d in devices) {
        await NotificationService.instance.scheduleDoseReminder(d);
      }
    }
  }

  Future<void> _setLowInventory(bool v) async {
    await SettingsService.instance.setLowInventoryAlerts(v);
    setState(() => _lowInventory = v);
  }

  Future<void> _setMissedDose(bool v) async {
    await SettingsService.instance.setMissedDoseAlerts(v);
    setState(() => _missedDose = v);
  }

  Future<void> _setAutoLog(bool v) async {
    await SettingsService.instance.setNfcAutoLog(v);
    setState(() => _autoLog = v);
  }

  Future<void> _setConfirmLog(bool v) async {
    await SettingsService.instance.setNfcConfirmLog(v);
    setState(() => _confirmLog = v);
  }

  Future<void> _setNfcTimeout(int v) async {
    await SettingsService.instance.setNfcScanTimeout(v);
    setState(() => _nfcTimeout = v);
  }

  Future<void> _setThemeMode(int v) async {
    await SettingsService.instance.setThemeModePref(v);
    setState(() => _themeModePref = v);
    if (mounted) {
      ref.read(themeModeProvider.notifier).state = SettingsService.instance.themeMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.clrBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: context.clrSurface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(children: [
                Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.clrText)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Appearance
                  _Section(title: 'Appearance', children: [
                    _SegmentRow(
                      label: 'Theme',
                      options: const ['System', 'Light', 'Dark'],
                      selected: _themeModePref,
                      onChanged: _setThemeMode,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Notifications
                  _Section(title: 'Notifications', children: [
                    _ToggleRow(label: 'Dose reminders', subtitle: 'Alert when a dose is due', value: _doseReminders, onChanged: _setDoseReminders),
                    _ToggleRow(label: 'Low inventory', subtitle: 'Alert when a compound is running low', value: _lowInventory, onChanged: _setLowInventory),
                    _ToggleRow(label: 'Missed dose', subtitle: 'Alert on next launch when a dose was skipped', value: _missedDose, onChanged: _setMissedDose),
                  ]),
                  const SizedBox(height: 20),

                  // NFC
                  _Section(title: 'NFC Scanning', children: [
                    _ToggleRow(label: 'Auto-log on scan', subtitle: 'Record dose immediately when tag detected (no confirmation)', value: _autoLog, onChanged: _setAutoLog),
                    _ToggleRow(label: 'Confirm before logging', subtitle: 'Always show confirmation step before saving', value: _confirmLog, onChanged: _setConfirmLog),
                    _SegmentRow(
                      label: 'Scan timeout',
                      subtitle: 'seconds to wait for a tag',
                      options: const ['10s', '20s', '30s'],
                      optionValues: const [10, 20, 30],
                      selected: [10, 20, 30].indexOf(_nfcTimeout).clamp(0, 2),
                      onChanged: (i) => _setNfcTimeout([10, 20, 30][i]),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Inventory
                  _Section(title: 'Inventory Thresholds', children: [
                    _InfoRow(label: 'Low stock alert', value: '${SettingsService.instance.nfcScanTimeout} sec scan'),
                    const _InfoRow(label: 'Low stock threshold', value: 'Per compound'),
                  ]),
                  const SizedBox(height: 20),

                  // Data
                  _Section(title: 'Data & Export', children: [
                    _ActionRow(label: 'Export as CSV', subtitle: 'Download all data as a spreadsheet', onTap: _exportCsv),
                    _ActionRow(label: 'Export as PDF', subtitle: 'Download a formatted dose report', onTap: _exportPdf),
                    _ActionRow(label: 'Backup data (JSON)', subtitle: 'Export all data for safekeeping', onTap: _backupJson),
                    _ActionRow(label: 'Restore from backup', subtitle: 'Pick a JSON backup file to restore', onTap: _pickAndRestore),
                  ]),
                  const SizedBox(height: 20),

                  // Danger zone
                  _Section(title: 'Danger Zone', children: [
                    _ActionRow(label: 'Clear all data', subtitle: 'Permanently erase all compounds and logs', danger: true, onTap: _clearData),
                  ]),
                  const SizedBox(height: 32),
                  Center(child: Text('PeptideTrack v1.0.0', style: TextStyle(fontSize: 12, color: context.clrTextHint))),
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

  Future<void> _backupJson() async {
    final state = ref.read(appProvider);
    try {
      final data = {
        'version': 1,
        'exported': DateTime.now().toIso8601String(),
        'devices': state.devices.map((d) => d.toMap()).toList(),
        'logs': state.doseLogs.map((l) => l.toMap()).toList(),
      };
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Share.share(json, subject: 'PeptideTrack Backup');
    } catch (e) {
      if (mounted) _showError('Backup failed: $e');
    }
  }

  Future<void> _pickAndRestore() async {
    // Confirm before overwriting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.clrSurface,
        title: Text('Restore from Backup', style: TextStyle(color: context.clrText)),
        content: Text(
          'This will replace ALL current data with the contents of the backup file. This cannot be undone.',
          style: TextStyle(fontSize: 13, color: context.clrTextSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Choose File'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) {
        if (mounted) _showError('Could not read file path');
        return;
      }
      final content = await File(path).readAsString();
      await _restoreJson(content);
    } catch (e) {
      if (mounted) _showError('Restore failed: $e');
    }
  }

  Future<void> _restoreJson(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final deviceMaps = (data['devices'] as List).cast<Map<String, dynamic>>();
      final logMaps = (data['logs'] as List).cast<Map<String, dynamic>>();
      final devices = deviceMaps.map(Device.fromMap).toList();
      final logs = logMaps.map(DoseLog.fromMap).toList();

      await ref.read(appProvider.notifier).clearAllData();
      for (final d in devices) {
        await ref.read(appProvider.notifier).enrollDevice(
          name: d.name, type: d.type, vendor: d.vendor,
          batchNumber: d.batchNumber, coaUrl: d.coaUrl,
          reconstitutionDate: d.reconstitutionDate,
          peptideMg: d.peptideMg, reconVolumeMl: d.reconVolumeMl,
          desiredDoseMcg: d.desiredDoseMcg, schedule: d.schedule,
          alertThresholdPct: d.alertThresholdPct, nfcTagId: d.nfcTagId,
        );
      }
      for (final log in logs) {
        await DatabaseService.instance.insertDoseLog(log);
      }
      await ref.read(appProvider.notifier).initialize();
      if (mounted) _showMessage('Backup restored successfully');
    } catch (e) {
      if (mounted) _showError('Restore failed: invalid backup file');
    }
  }

  void _clearData() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.clrSurface,
        title: Text('Clear All Data', style: TextStyle(color: context.clrText)),
        content: Text('This will permanently delete all compounds and dose history. This cannot be undone.',
            style: TextStyle(color: context.clrTextSub)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.red));
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Sub-widgets ────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: context.clrTextSub, letterSpacing: 0.7)),
      ),
      Container(
        decoration: BoxDecoration(
          color: context.clrSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.clrBorder, width: 0.5),
        ),
        child: Column(
          children: children.indexed.map((entry) {
            final idx = entry.$1;
            final child = entry.$2;
            return Column(children: [
              child,
              if (idx < children.length - 1) Divider(height: 0, indent: 16, color: context.clrBorder),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}

class _ToggleRow extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.clrText)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12, color: context.clrTextSub)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: AppColors.teal),
    ]),
  );
}

class _SegmentRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final List<String> options;
  final List<int>? optionValues;
  final int selected;
  final ValueChanged<int> onChanged;
  const _SegmentRow({required this.label, this.subtitle, required this.options, this.optionValues, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.clrText)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: TextStyle(fontSize: 12, color: context.clrTextSub)),
        ],
      ])),
      const SizedBox(width: 12),
      Container(
        decoration: BoxDecoration(
          color: context.clrBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.clrBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.asMap().entries.map((e) {
            final active = selected == e.key;
            return GestureDetector(
              onTap: () => onChanged(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(e.value, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : context.clrTextSub,
                )),
              ),
            );
          }).toList(),
        ),
      ),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.clrText))),
      Text(value, style: TextStyle(fontSize: 13, color: context.clrTextSub)),
    ]),
  );
}

class _ActionRow extends StatelessWidget {
  final String label, subtitle;
  final bool danger;
  final VoidCallback onTap;
  const _ActionRow({required this.label, required this.subtitle, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
              color: danger ? AppColors.red : context.clrText)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: context.clrTextSub)),
        ])),
        Icon(Icons.chevron_right_rounded, color: danger ? AppColors.red : context.clrTextHint, size: 20),
      ]),
    ),
  );
}
