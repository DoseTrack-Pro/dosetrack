# PeptideTrack — Claude Code Project Memory

## What this app is
A native iOS & Android Flutter app for tracking peptide dosing. Users enroll injectable pens and vials, log doses manually or via NFC tag scan, and view adherence analytics. Built for public App Store / Play Store distribution.

## Tech stack
- **Framework**: Flutter 3.41 / Dart 3.3+
- **State**: flutter_riverpod 2.x — use `Notifier<T>` + `NotifierProvider` (NOT the deprecated `StateNotifier`)
- **Database**: sqflite (SQLite, local-first)
- **NFC**: flutter_nfc_kit — read-only UID approach (we read the tag's hardware UID, never write to it)
- **Notifications**: flutter_local_notifications v17 — `zonedSchedule()` requires `uiLocalNotificationDateInterpretation` parameter
- **Charts**: fl_chart
- **PDF/CSV export**: pdf + printing + share_plus
- **IDs**: uuid package

## Project structure
```
lib/
├── main.dart                  # Entry: boots DatabaseService, NotificationService, NfcService
├── app.dart                   # MaterialApp + _AppLoader (initialises state once via initState)
├── theme/app_theme.dart       # AppColors, buildAppTheme(), doseColor(), doseBgColor()
├── models/
│   ├── device.dart            # Device, ContainerType, DoseSchedule + extensions
│   └── dose_log.dart         # DoseLog, LogMethod
├── utils/calculations.dart    # calcDoseIu(), calcTotalDoses(), isDueToday(), calcAdherence(), etc.
├── services/
│   ├── database_service.dart  # sqflite CRUD singleton — DatabaseService.instance
│   ├── nfc_service.dart       # NfcService.instance — readTagId() only (no writes)
│   ├── notification_service.dart
│   └── export_service.dart    # exportCsv() + exportPdf() via share sheet
├── providers/app_state.dart   # AppNotifier extends Notifier<AppState> — single source of truth
├── widgets/
│   ├── dose_ring.dart         # CustomPainter progress ring
│   ├── device_card.dart       # Dashboard card with Log button
│   ├── badge_chip.dart
│   ├── empty_state.dart
│   └── toast_overlay.dart
├── screens/
│   ├── main_scaffold.dart     # Bottom nav (IndexedStack, 5 tabs)
│   ├── dashboard_screen.dart
│   ├── inventory_screen.dart
│   ├── history_screen.dart
│   ├── analytics_screen.dart
│   └── settings_screen.dart
└── modals/
    ├── nfc_scan_modal.dart        # 3-state NFC scanner: scanning → detected → timeout/error
    ├── log_dose_modal.dart        # Manual dose confirm bottom sheet
    ├── device_detail_modal.dart   # Full device detail (full-screen page)
    └── enroll/
        ├── enroll_modal.dart      # 4-step wizard orchestrator
        ├── step_type_method.dart  # Step 1: pen/vial + NFC/manual
        ├── step_nfc_scan.dart     # Step 2: auto-scan with 10s countdown + duplicate check
        ├── step_compound_details.dart
        └── step_dosing_config.dart
```

## Key design decisions & rules

### NFC approach
- We READ the tag's hardware UID only — no writing. Works with any NFC tag (stickers, cards, key fobs).
- NFC uniqueness: a tag UID can only be registered to ONE active non-depleted container at a time.
- `getConflictingDeviceByNfcTagId()` checks `active = 1 AND remaining_doses > 0` during enrollment.
- `getDeviceByNfcTagId()` (for dose logging) checks `active = 1` only.
- Tags can be reused once their container is depleted.

### Depleted containers
- `remainingDoses <= 0` = depleted.
- Depleted containers: "Log" button shows as grayed "Empty", detail page shows Close + Archive buttons.
- Due Today chips exclude depleted devices.
- NFC manual fallback list (timeout state) excludes depleted devices.

### Dose formula
```dart
doseVolumeIu = (desiredDoseMcg / (peptideMg * 1000)) * reconVolumeMl * 100
totalDoses   = floor((reconVolumeMl * 100) / doseVolumeIu)
```

### State management
- All business logic in `AppNotifier extends Notifier<AppState>` in `providers/app_state.dart`
- Selectors: `appProvider`, `devicesProvider`, `activeDevicesProvider`, `doseLogsProvider`, `toastProvider`
- Never use `StateNotifier` or `StateNotifierProvider` — removed in Riverpod 2.5

### Layout rules (avoid overflow)
- Never use `GridView.count` with `childAspectRatio` for cards containing two lines of text — use explicit `Row`/`Column` with `Expanded` instead.
- Wrap large value text in `FittedBox(fit: BoxFit.scaleDown)` when inside constrained spaces.
- All `Column` widgets inside fixed-height parents must use `mainAxisSize: MainAxisSize.min`.
- Always set `maxLines: 1, overflow: TextOverflow.ellipsis` on text that can be long.

### Theme & colors (from AppColors in app_theme.dart)
```dart
teal        = Color(0xFF1D9E75)   // primary brand, success
tealLight   = Color(0xFFE1F5EE)   // teal backgrounds
amber       = Color(0xFFBA7517)   // warning
amberLight  = Color(0xFFFAEEDA)
red         = Color(0xFFE24B4A)   // danger/error
redLight    = Color(0xFFFCEBEB)
purple      = Color(0xFF534AB7)   // pen type
purpleLight = Color(0xFFEEEDFE)
blue        = Color(0xFF185FA5)   // NFC indicator
blueLight   = Color(0xFFE6F1FB)
```
- `doseColor(remaining, total)` returns teal/amber/red based on % remaining (>50% / >20% / ≤20%)
- Depleted UI uses `AppColors.border` (gray) background with `AppColors.textTertiary` text

### Android build config
- `minSdk 26` (required by flutter_nfc_kit)
- `compileSdk` uses `flutter.compileSdkVersion`
- Gradle 8.7, AGP 8.6.0, Kotlin 2.1.0
- `coreLibraryDesugaringEnabled true` with `desugar_jdk_libs:2.0.4`

### Flutter 3.41 API notes
- Use `CardThemeData` not `CardTheme` in ThemeData
- Use `Color.withValues(alpha: x)` not `Color.withOpacity(x)`
- `flutter_local_notifications` v17: `zonedSchedule()` still requires `uiLocalNotificationDateInterpretation:` named param
- All icons use `Icons.*_rounded` variants for consistency

## Current app screens

### Dashboard
- Header: date + title + "+" enroll button
- "Scan NFC to Log" green button (only shown if NFC supported AND active NFC devices exist)
- Low stock amber banner (when any device below alertThresholdPct)
- "Due Today" horizontal chips (filtered: active + non-depleted + isDueToday())
- Device cards (DeviceCard widget)

### Inventory
- Filter chips: All / Active / Depleted / Pen / Vial
- Device list rows with progress bar + NFC badge

### History
- Summary cards: total doses / adherence % / streak days
- Grouped by date (Today, Yesterday, MMM d)

### Analytics
- 4 KPI cards: adherence / total doses / streak / missed
- Line chart: daily doses per compound (last 14 days) via fl_chart
- Stacked bar chart: used vs remaining per container
- Per-compound breakdown with progress bars

### Settings
- Notification toggles (local only, no backend)
- NFC scanning toggles
- Inventory threshold display
- Export CSV / Export PDF (via native share sheet)
- Clear all data (with confirmation dialog)

## Enroll flow (4 steps for NFC, 3 for manual)
1. `StepTypeMethod` — choose pen/vial + NFC/manual
2. `StepNfcScan` — auto-starts 10s countdown, reads UID, checks uniqueness
   - `_Phase.duplicate` if tag already registered to active non-depleted device
   - Shows amber conflict card with device name, ring, doses remaining, reuse instructions
3. `StepCompoundDetails` — name, vendor, batch, COA URL, recon date
4. `StepDosingConfig` — peptide mg, recon mL, dose mcg → live IU/total calc, schedule, alert %

## NFC scan modal (dose logging)
- Auto-starts when opened, 10s countdown arc (teal → amber → red)
- Pulsing rings animation while scanning
- On detect: shows device card + Confirm button (or depleted message)
- On timeout: shows Try Again + manual fallback list (non-depleted NFC devices only)

## Running the app
```powershell
cd C:\dev\Flutter\peptidetrack_flutter
flutter pub get
flutter run          # deploys to connected Android device (Pixel 8 Pro)
flutter run -d chrome  # web (NFC/SQLite disabled but UI visible)
```

## Known issues resolved
- `CardTheme` → `CardThemeData` (Flutter 3.41)
- `withOpacity()` → `withValues(alpha:)` (Flutter 3.41)
- `StateNotifier` → `Notifier` (Riverpod 2.5)
- `flutter_local_notifications` v17 still requires `uiLocalNotificationDateInterpretation`
- `minSdk` must be 26 for flutter_nfc_kit
- NFC writes removed — read-only UID approach used instead
- All GridView fixed aspect ratio layouts replaced with Row/Column to prevent overflow
