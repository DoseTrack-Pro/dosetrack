import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'services/nfc_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Boot services in order
  await DatabaseService.instance.init();
  await NotificationService.instance.init();
  await NfcService.instance.init();
  await SettingsService.instance.init();

  runApp(const ProviderScope(child: PeptideTrackApp()));
}
