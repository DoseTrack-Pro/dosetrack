# PeptideTrack — Claude Code Project Memory

## What this app is
A native iOS & Android Flutter app for tracking peptide dosing. Users enroll injectable pens and vials, log doses manually or via NFC tag scan, and view adherence analytics. Built for public App Store / Play Store distribution.

## Tech stack
- **Framework**: Flutter 3.41 / Dart 3.3+
- **State**: flutter_riverpod 2.x — use `Notifier<T>` + `NotifierProvider` (NOT the deprecated `StateNotifier`)
- **Database**: sqflite (SQLite, local-first) — current schema version **5**
- **NFC**: flutter_nfc_kit — read-only UID approach (we read the tag's hardware UID, never write to it)
- **Notifications**: flutter_local_notifications v17 — `zonedSchedule()` requires `uiLocalNotificationDateInterpretation` parameter
- **Charts**: fl_chart
- **PDF/CSV export**: pdf + printing + share_plus
- **File picker**: file_picker ^8.0.7 (backup restore)
- **IDs**: uuid package

## Project structure
```
lib/
├── main.dart                  # Entry: boots DatabaseService, NotificationService, NfcService
├── app.dart                   # MaterialApp + _AppLoader (initialises state once via initState)
├── theme/app_theme.dart       # AppColors, buildAppTheme(), doseColor(), doseBgColor()
├── models/
│   ├── device.dart            # Device, ContainerType, DoseSchedule + extensions
│   ├── dose_log.dart          # DoseLog, LogMethod
│   └── protocol.dart          # Protocol (id, name, startDate, endDate?, notes)
├── utils/calculations.dart    # calcDoseIu(), calcTotalDoses(), isDueToday(), calcAdherence(),
│                              # isScheduledOnDate(), effectiveScheduleDays(), calcReconVolume()
├── services/
│   ├── database_service.dart  # sqflite CRUD singleton — DatabaseService.instance
│   ├── nfc_service.dart       # NfcService.instance — readTagId() only (no writes)
│   ├── notification_service.dart
│   └── export_service.dart    # exportCsv() + exportPdf() via share sheet
├── providers/app_state.dart   # AppNotifier extends Notifier<AppState> — single source of truth
├── widgets/
│   ├── dose_ring.dart         # CustomPainter progress ring
│   ├── device_card.dart       # Dashboard card — accepts borderRadius + showBorder for protocol grouping
│   ├── badge_chip.dart
│   ├── empty_state.dart
│   └── toast_overlay.dart
├── screens/
│   ├── main_scaffold.dart     # Bottom nav (IndexedStack, 5 tabs)
│   ├── dashboard_screen.dart  # Protocol groups + calculator button + today's progress bar
│   ├── inventory_screen.dart
│   ├── history_screen.dart
│   ├── analytics_screen.dart
│   └── settings_screen.dart
└── modals/
    ├── nfc_scan_modal.dart           # 3-state NFC scanner: scanning → detected → timeout/error
    ├── log_dose_modal.dart           # Manual dose confirm — editable dose mcg/IU fields
    ├── device_detail_modal.dart      # Full device detail (full-screen page)
    ├── edit_device_modal.dart        # Edit compound — includes day picker for weekly schedules
    ├── recon_calculator_modal.dart   # Standalone reconstitution calculator (two modes)
    ├── create_protocol_modal.dart    # Create/edit protocol bottom sheet
    └── enroll/
        ├── enroll_modal.dart         # 4-step wizard orchestrator
        ├── step_type_method.dart     # Step 1: pen/vial + NFC/manual
        ├── step_nfc_scan.dart        # Step 2: auto-scan with 20s countdown + duplicate check
        ├── step_compound_details.dart
        └── step_dosing_config.dart   # Step 4: dosing config + day picker for weekly/custom schedules
```

## Key design decisions & rules

### NFC approach
- We READ the tag's hardware UID only — no writing. Works with any NFC tag (stickers, cards, key fobs).
- NFC uniqueness: a tag UID can only be registered to ONE active non-depleted container at a time.
- `getConflictingDeviceByNfcTagId()` checks `active = 1 AND remaining_doses > 0` during enrollment.
- `getDeviceByNfcTagId()` (for dose logging) checks `active = 1` only.
- Tags can be reused once their container is depleted.
- NFC enrollment scan timeout: **20 seconds** (was 10s).

### Depleted / archived compounds
- `remainingDoses <= 0` = depleted.
- Depleted compounds: "Log" button shows as grayed "Empty", detail page shows Close + Archive buttons.
- Archive sets `active = 0` AND `remaining_doses = 0` (both DB and in-memory).
- Already-archived compounds cannot be archived again (button hidden).
- Due Today chips exclude depleted devices.
- NFC manual fallback list (timeout state) excludes depleted devices.

### Dose formula
```dart
doseVolumeIu = (desiredDoseMcg / (peptideMg * 1000)) * reconVolumeMl * 100
totalDoses   = floor((reconVolumeMl * 100) / doseVolumeIu)
// Reverse (used in calculator):
reconVolumeMl = (targetDoses * doseIuAt1mL) / 100
```

### Variable dose logging
- `logDose()` accepts optional `overrideDoseMcg` and `overrideDoseIu`.
- Each log always decrements `remainingDoses` by 1 regardless of dose override.
- Log modal: dose fields start in read-only "configured" mode; tap badge to enable "custom" editing.
- mcg ↔ IU auto-sync via `calcDoseIu()` / `calcDoseMcg()`.

### Flexible scheduling (scheduleDays)
- `Device.scheduleDays: List<int>?` — weekday ints 1=Mon through 7=Sun.
- Stored in DB as comma-separated string: `"1,4"`, `"3"`, `"1,3,5"`.
- Defaults if null: twiceWeekly=[1,4], onceWeekly=[1], custom=[].
- **Custom schedule WITH days selected = fully tracked** (adherence, Due Today, reminders).
- `effectiveScheduleDays(device)` — returns the active day list respecting defaults.
- `isScheduledOnDate(device, date)` — replaces inline switch logic everywhere.
- `isDueToday(device, logs)` — now delegates to `isScheduledOnDate`.
- Day picker UI shown in `step_dosing_config.dart` and `edit_device_modal.dart` for twiceWeekly/onceWeekly/custom.
- Validation: twiceWeekly requires exactly 2 days; onceWeekly requires exactly 1.

### Protocols / stacks
- `Protocol` model: id, name, startDate, endDate?, notes. Computed: `dayNumber`, `totalDays`, `isActive`.
- DB tables: `protocols` + `protocol_devices` (junction, device can be in ONE protocol at a time).
- `AppState` carries `protocols: List<Protocol>` and `deviceProtocols: Map<String, String>` (deviceId → protocolId).
- Providers: `protocolsProvider`, `deviceProtocolsProvider`.
- Dashboard groups device cards under protocol headers showing "Day X / Y".
- Ungrouped devices shown under "OTHER" label when protocols exist.
- Compounds already in another protocol are shown as disabled in the create/edit picker.

### Reconstitution calculator
- `ReconCalculatorModal` — bottom sheet modal, two modes:
  - **Draw**: peptide mg + BAC water mL + dose mcg → IU to draw + total doses.
  - **Water**: peptide mg + dose mcg + desired doses → BAC water mL + IU per dose.
- Opened via calculator icon in dashboard header (next to + enroll button).

### Database schema (version 5)
```sql
devices          -- includes schedule_days TEXT, expiry_days INTEGER NOT NULL DEFAULT 28
dose_logs        -- includes injection_site TEXT
protocols        -- id, name, start_date, end_date, notes
protocol_devices -- protocol_id, device_id (junction, PRIMARY KEY both)
```
Migration chain: v1→v2 adds injection_site; v2→v3 adds schedule_days; v3→v4 adds protocol tables; v4→v5 adds expiry_days.

### Backup / restore
- **Backup**: `Share.share(json)` — user saves to Files app, Drive, etc.
- **Restore**: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'])` then `File(path).readAsString()`. Confirmation dialog before overwriting.

### State management
- All business logic in `AppNotifier extends Notifier<AppState>` in `providers/app_state.dart`.
- Selectors: `appProvider`, `devicesProvider`, `activeDevicesProvider`, `doseLogsProvider`, `toastProvider`, `protocolsProvider`, `deviceProtocolsProvider`.
- Never use `StateNotifier` or `StateNotifierProvider` — removed in Riverpod 2.5.

### Layout rules (avoid overflow)
- Never use `GridView.count` with `childAspectRatio` for cards containing two lines of text — use explicit `Row`/`Column` with `Expanded` instead.
- Wrap large value text in `FittedBox(fit: BoxFit.scaleDown)` when inside constrained spaces.
- All `Column` widgets inside fixed-height parents must use `mainAxisSize: MainAxisSize.min`.
- Always set `maxLines: 1, overflow: TextOverflow.ellipsis` on text that can be long.

### Theme & colors (from AppColors in app_theme.dart)
```dart
teal        = Color(0xFF1D9E75)   // primary brand, success
tealLight   = Color(0xFFE1F5EE)   // teal backgrounds
tealMid     = Color(0xFF9FE1CB)   // chart "remaining" bars
tealDark    = Color(0xFF085041)
tealDeep    = Color(0xFF0F6E56)
amber       = Color(0xFFBA7517)   // warning
amberLight  = Color(0xFFFAEEDA)
red         = Color(0xFFE24B4A)   // danger/error
redLight    = Color(0xFFFCEBEB)
purple      = Color(0xFF534AB7)   // pen type
purpleLight = Color(0xFFEEEDFE)
blue        = Color(0xFF185FA5)   // NFC indicator
blueLight   = Color(0xFFE6F1FB)
blueMid     = Color(0xFFB5D4F4)
```
- `doseColor(remaining, total)` returns teal/amber/red based on % remaining (>50% / >20% / ≤20%).
- Depleted UI uses `AppColors.border` (gray) background with `AppColors.textTertiary` text.
- All neutral surfaces use `context.clrX` dark-mode-aware extensions, NOT static `AppColors.*`.
- Analytics bar chart: Remaining = `AppColors.teal`, Used = `Color(0xFF94A3B8)` (slate-gray).

### Android build config
- `minSdk 26` (required by flutter_nfc_kit)
- `compileSdk` uses `flutter.compileSdkVersion`
- Gradle 8.11.1, AGP 8.9.1, Kotlin 2.1.0
- `coreLibraryDesugaringEnabled true` with `desugar_jdk_libs:2.0.4`

### Flutter 3.41 API notes
- Use `CardThemeData` not `CardTheme` in ThemeData.
- Use `Color.withValues(alpha: x)` not `Color.withOpacity(x)`.
- `flutter_local_notifications` v17: `zonedSchedule()` still requires `uiLocalNotificationDateInterpretation:` named param.
- All icons use `Icons.*_rounded` variants for consistency.

## Current app screens

### Dashboard
- Header: date + title + calculator icon + "+" enroll button.
- Today's progress bar (dosed/scheduled count for the day).
- "Scan NFC to Log" green button (only shown if NFC supported AND active NFC devices exist).
- Expiry banner (red if expired, amber if ≤7 days remaining, window = per-compound `expiryDays`).
- Low stock amber banner (when any device below alertThresholdPct).
- "Due Today" horizontal chips (active + non-depleted + isDueToday()).
- **Protocol sections** — teal header showing protocol name + "Day X / Y", grouped DeviceCards beneath.
- Ungrouped devices (shown under "OTHER" label when protocols exist).
- "Organise into a protocol" nudge button when 2+ active compounds.

### Inventory
- Filter chips: All / Active / Depleted / Pen / Vial
- Device list rows with progress bar + NFC badge

### History
- Summary cards: total doses / adherence % / streak days
- Grouped by date (Today, Yesterday, MMM d)
- Dose values displayed to 1 decimal place (e.g. 2.5 IU)

### Analytics
- 4 KPI cards: adherence / total doses / streak / missed
- Line chart: daily doses per compound (last 14, 30, or 90 days) via fl_chart
- Stacked bar chart: Remaining (teal, bottom) vs Used (slate-gray, top) per compound
- Per-compound breakdown with progress bars
- Adherence by compound (with color: teal ≥80%, amber ≥50%, red <50%)
- Projected depletion dates

### Settings
- Appearance: system/light/dark theme toggle
- Notification toggles (dose reminders, low inventory, missed dose)
- NFC: auto-log toggle, confirm toggle, scan timeout (10/20/30s)
- Export CSV / PDF (via native share sheet)
- Backup JSON (via share sheet) / Restore from backup (file picker)
- Clear all data (with confirmation dialog)

## Enroll flow (4 steps for NFC, 3 for manual)
1. `StepTypeMethod` — choose pen/vial + NFC/manual; "Copy previous" shortcut copies dosing config.
2. `StepNfcScan` — auto-starts **20s** countdown, reads UID, checks uniqueness.
   - `_Phase.duplicate` if tag already registered to active non-depleted device.
   - Shows amber conflict card with device name, ring, doses remaining, reuse instructions.
3. `StepCompoundDetails` — name, vendor, batch, COA URL, recon date.
4. `StepDosingConfig` — peptide mg, recon mL, dose mcg → live IU/total calc; schedule + **day picker** (for twiceWeekly/onceWeekly/custom); alert %.

## NFC scan modal (dose logging)
- Auto-starts when opened, countdown arc (teal → amber → red).
- Pulsing rings animation while scanning.
- On detect: shows device card + Confirm button (or depleted message). Duplicate-today warning dialog.
- On timeout: shows Try Again + manual fallback list (non-depleted NFC devices only).
- Auto-log mode: if `nfcAutoLog=true && nfcConfirmLog=false`, logs immediately on tag detect.

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
- AGP upgraded to 8.9.1 / Gradle 8.11.1 (required by url_launcher_android 6.3.x → androidx.browser 1.9.0)
- Archive now zeros `remaining_doses` in both DB and in-memory state
- Backup restore previously parsed logs but didn't insert them — fixed with `insertDoseLog` loop + re-initialize
