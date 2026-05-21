import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/legal_text.dart';
import '../providers/app_state.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../models/protocol.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/app_lock_service.dart';
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
  late bool _appLockEnabled;
  late bool _appLockBiometric;
  late int _appLockTimeoutMins;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _doseReminders = s.doseReminders;
    _lowInventory = s.lowInventoryAlerts;
    _missedDose = s.missedDoseAlerts;
    _autoLog = s.nfcAutoLog;
    _confirmLog = s.nfcConfirmLog;
    _nfcTimeout = s.nfcScanTimeout;
    _themeModePref = s.themeModePref;
    _appLockEnabled = s.appLockEnabled;
    _appLockBiometric = s.appLockBiometrics;
    _appLockTimeoutMins = s.appLockTimeoutMinutes;
    Future.microtask(() async {
      final supported = await AppLockService.instance.supportsBiometrics();
      if (mounted) setState(() => _biometricSupported = supported);
    });
  }

  Future<void> _setDoseReminders(bool v) async {
    await SettingsService.instance.setDoseReminders(v);
    setState(() => _doseReminders = v);
    await ref.read(appProvider.notifier).refreshDoseReminders();
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
      ref.read(themeModeProvider.notifier).refreshFromSettings();
    }
  }

  Future<void> _setAppLockEnabled(bool v) async {
    if (v) {
      final hasPin = await AppLockService.instance.hasPin();
      if (!hasPin) {
        final pin = await _promptForPin(initialSetup: true);
        if (pin == null) return;
        await AppLockService.instance.savePin(pin);
      }
    }
    await SettingsService.instance.setAppLockEnabled(v);
    setState(() => _appLockEnabled = v);
  }

  Future<void> _setAppLockBiometric(bool v) async {
    await SettingsService.instance.setAppLockBiometrics(v);
    setState(() => _appLockBiometric = v);
  }

  Future<void> _setAppLockTimeout(int mins) async {
    await SettingsService.instance.setAppLockTimeoutMinutes(mins);
    setState(() => _appLockTimeoutMins = mins);
  }

  Future<void> _changePin() async {
    final pin = await _promptForPin(initialSetup: false);
    if (pin == null) return;
    await AppLockService.instance.savePin(pin);
    if (mounted) _showMessage('PIN updated');
  }

  void _lockNow() {
    AppLockService.instance.requestLockNow();
    _showMessage('App locked');
  }

  Future<String?> _promptForPin({required bool initialSetup}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinSetupDialog(initialSetup: initialSetup),
    );
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
                Text('Settings',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.clrText)),
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
                    _ToggleRow(
                        label: 'Dose reminders',
                        subtitle: 'Alert when a dose is due',
                        value: _doseReminders,
                        onChanged: _setDoseReminders),
                    _ToggleRow(
                        label: 'Low inventory',
                        subtitle: 'Alert when a compound is running low',
                        value: _lowInventory,
                        onChanged: _setLowInventory),
                    _ToggleRow(
                        label: 'Missed dose',
                        subtitle:
                            'Alert on next launch when a dose was skipped',
                        value: _missedDose,
                        onChanged: _setMissedDose),
                  ]),
                  const SizedBox(height: 20),

                  // Privacy lock
                  _Section(title: 'Privacy Lock', children: [
                    _ToggleRow(
                      label: 'Require unlock',
                      subtitle: 'Lock app content behind PIN/biometric',
                      value: _appLockEnabled,
                      onChanged: _setAppLockEnabled,
                    ),
                    if (_appLockEnabled) ...[
                      _ToggleRow(
                        label: 'Use biometrics',
                        subtitle: _biometricSupported
                            ? 'Use Face ID / fingerprint when available'
                            : 'Biometric unlock is not available on this device',
                        value: _appLockBiometric && _biometricSupported,
                        onChanged:
                            _biometricSupported ? _setAppLockBiometric : (_) {},
                      ),
                      _SegmentRow(
                        label: 'Inactivity lock timer',
                        subtitle:
                            'How long app can stay in background before lock',
                        options: const ['Now', '1m', '5m', '15m'],
                        optionValues: const [0, 1, 5, 15],
                        selected: [0, 1, 5, 15]
                            .indexOf(_appLockTimeoutMins)
                            .clamp(0, 3),
                        onChanged: (i) => _setAppLockTimeout([0, 1, 5, 15][i]),
                      ),
                      _ActionRow(
                        label: 'Change PIN',
                        subtitle: 'Update your 4-digit app lock PIN',
                        onTap: _changePin,
                      ),
                      _ActionRow(
                        label: 'Lock now',
                        subtitle: 'Immediately lock app content',
                        onTap: _lockNow,
                      ),
                      const _NoteRow(
                        text:
                            'Inactivity timer starts when app goes to background. '
                            'App content locks after selected time.',
                      ),
                    ],
                  ]),
                  const SizedBox(height: 20),

                  // NFC
                  _Section(title: 'NFC Scanning', children: [
                    _ToggleRow(
                        label: 'Auto-log on scan',
                        subtitle:
                            'Record dose immediately when tag detected (no confirmation)',
                        value: _autoLog,
                        onChanged: _setAutoLog),
                    _ToggleRow(
                        label: 'Confirm before logging',
                        subtitle: 'Always show confirmation step before saving',
                        value: _confirmLog,
                        onChanged: _setConfirmLog),
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

                  // Data
                  _Section(title: 'Data & Export', children: [
                    _ActionRow(
                        label: 'Export as CSV',
                        subtitle: 'Download all data as a spreadsheet',
                        onTap: _exportCsv),
                    _ActionRow(
                        label: 'Export as PDF',
                        subtitle: 'Download a formatted dose report',
                        onTap: _exportPdf),
                    _ActionRow(
                        label: 'Backup data (JSON)',
                        subtitle: 'Create a .json backup file you can save',
                        onTap: _backupJson),
                    _ActionRow(
                        label: 'Restore from backup',
                        subtitle: 'Import from a previously saved .json file',
                        onTap: _pickAndRestore),
                    const _InfoRow(
                        label: 'Backup includes',
                        value:
                            'Compounds, dose logs, protocols, and protocol links'),
                    const _InfoRow(
                        label: 'Not included in backup',
                        value:
                            'App settings (theme/NFC/alerts), app lock PIN, and OS permissions'),
                  ]),
                  const SizedBox(height: 20),

                  // Legal
                  _Section(title: 'Legal', children: [
                    _ActionRow(
                      label: 'Disclaimer',
                      subtitle:
                          'Educational/informational only. Not medical advice.',
                      onTap: _showDisclaimerSheet,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Danger zone
                  _Section(title: 'Danger Zone', children: [
                    _ActionRow(
                        label: 'Clear all data',
                        subtitle: 'Permanently erase all compounds and logs',
                        danger: true,
                        onTap: _clearData),
                  ]),
                  const SizedBox(height: 32),
                  Center(
                      child: Text('Pep Tracker Pro v1.0.0',
                          style: TextStyle(
                              fontSize: 12, color: context.clrTextHint))),
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
        'protocols': state.protocols.map((p) => p.toMap()).toList(),
        'deviceProtocols': state.deviceProtocols,
      };
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final fileName =
          'peptidetrack_backup_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(json)),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: [fileName],
          subject: 'Pep Tracker Pro Backup',
          text: 'Backup file: $fileName',
        ),
      );
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
        title: Text('Restore from Backup',
            style: TextStyle(color: context.clrText)),
        content: Text(
          'This will replace ALL current data with the contents of the backup file. This cannot be undone.',
          style: TextStyle(fontSize: 13, color: context.clrTextSub),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.pickFiles(
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
      final protocolMaps = ((data['protocols'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final deviceProtocolRaw = (data['deviceProtocols'] as Map?) ?? const {};
      final deviceProtocols = deviceProtocolRaw.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      final devices = deviceMaps.map(Device.fromMap).toList();
      final logs = logMaps.map(DoseLog.fromMap).toList();
      final protocols = protocolMaps.map(Protocol.fromMap).toList();

      await ref.read(appProvider.notifier).clearAllData();
      for (final d in devices) {
        // Restore exact row (preserve IDs, dates, schedule days, thresholds, and linkage).
        await DatabaseService.instance
            .insertDevice(d.copyWith(clearNotificationId: true));
      }
      for (final log in logs) {
        await DatabaseService.instance.insertDoseLog(log);
      }
      for (final protocol in protocols) {
        await DatabaseService.instance.insertProtocol(protocol);
      }
      final idsByProtocol = <String, List<String>>{};
      for (final entry in deviceProtocols.entries) {
        idsByProtocol.putIfAbsent(entry.value, () => []).add(entry.key);
      }
      for (final entry in idsByProtocol.entries) {
        await DatabaseService.instance
            .setDevicesForProtocol(entry.key, entry.value);
      }
      await ref.read(appProvider.notifier).initialize();
      await ref.read(appProvider.notifier).refreshDoseReminders();
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
        content: Text(
            'This will permanently delete all compounds and dose history. This cannot be undone.',
            style: TextStyle(color: context.clrTextSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(appProvider.notifier).clearAllData();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Clear everything'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.clrSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.clrBorderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Legal Disclaimer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.clrText,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      kLegalDisclaimerText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: context.clrTextSub,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.red));
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
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.clrTextSub,
                letterSpacing: 0.7)),
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
              if (idx < children.length - 1)
                Divider(height: 0, indent: 16, color: context.clrBorder),
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
  const _ToggleRow(
      {required this.label,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.clrText)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: context.clrTextSub)),
              ])),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.teal,
          ),
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
  const _SegmentRow(
      {required this.label,
      this.subtitle,
      required this.options,
      this.optionValues,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.clrText)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style:
                          TextStyle(fontSize: 12, color: context.clrTextSub)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AppColors.teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(e.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.clrText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: context.clrTextSub,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
}

class _NoteRow extends StatelessWidget {
  final String text;
  const _NoteRow({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style:
              TextStyle(fontSize: 12, color: context.clrTextSub, height: 1.35),
        ),
      );
}

class _PinSetupDialog extends StatefulWidget {
  final bool initialSetup;
  const _PinSetupDialog({required this.initialSetup});

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.clrSurface,
      title: Text(
        widget.initialSetup ? 'Set app lock PIN' : 'Change PIN',
        style: TextStyle(color: context.clrText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              counterText: '',
              labelText: 'PIN',
              hintText: '4 digits',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              counterText: '',
              labelText: 'Confirm PIN',
              hintText: '4 digits',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label, subtitle;
  final bool danger;
  final VoidCallback onTap;
  const _ActionRow(
      {required this.label,
      required this.subtitle,
      this.danger = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: danger ? AppColors.red : context.clrText)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: context.clrTextSub)),
                ])),
            Icon(Icons.chevron_right_rounded,
                color: danger ? AppColors.red : context.clrTextHint, size: 20),
          ]),
        ),
      );
}
