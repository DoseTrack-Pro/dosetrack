# PeptideTrack Codebase Guide

This guide explains how the app works and what each major file is for, in plain English.

## 1) What this app does

PeptideTrack is a local-first Flutter app for:
- enrolling peptide containers (pen/vial),
- tracking planned dosing schedules,
- logging doses manually or by NFC tag scan,
- showing adherence/inventory analytics,
- exporting and backing up data.

Data is stored locally in SQLite (`sqflite`), state is managed with Riverpod (`Notifier`), and reminders use local notifications.

## 2) How the app runs (high-level)

1. `lib/main.dart` boots core services (database, notifications, NFC, settings).
2. `lib/app.dart` builds `MaterialApp`, chooses light/dark theme, and runs app initialization.
3. First-run gates in order: required legal disclaimer, then onboarding (if not completed).
4. `lib/providers/app_state.dart` loads DB data into app state and exposes all business actions.
5. Screens read provider state and call notifier methods to mutate data.
6. Services handle platform and persistence work (SQLite, notifications, NFC, export, settings).

## 3) Data and control flow

- **Single source of truth**: `AppState` in `lib/providers/app_state.dart`.
- **Write flow**: UI action -> `AppNotifier` method -> service/database call -> updated `AppState` -> UI rebuild.
- **Core entities**:
  - `Device`: enrolled container and dosing config.
  - `DoseLog`: one logged dose event.
  - `Protocol`: named stack/cycle with start/end dates, and a device mapping.
- **Native bridge**: Dart NFC service talks to Android/iOS via MethodChannel `com.adam.dosevault/nfc`.
- **NovoPen flow**: full native NovoPen decode/import path is currently Android-first; iOS currently supports standard tag UID scanning.

## 4) File-by-file map (Flutter app code)

### Root app files

- `lib/main.dart`: app entry point; initializes services and starts Riverpod.
- `lib/app.dart`: `MaterialApp` setup, theme mode wiring, legal disclaimer gate, onboarding gate, app lock gate.

### Theme

- `lib/theme/app_theme.dart`: color tokens, theme builders (light/dark), and color helpers used across widgets.

### Models

- `lib/models/device.dart`: `Device` model, container/schedule enums, blend component model, serialization helpers.
- `lib/models/dose_log.dart`: `DoseLog` model and log method enum (`nfc` vs `manual`).
- `lib/models/protocol.dart`: `Protocol` model with computed protocol-day helpers.

### State management

- `lib/providers/app_state.dart`: app state shape, `AppNotifier` business logic (enroll/log/edit/archive/protocols/undo/refresh reminders), and all Riverpod providers/selectors.

### Services

- `lib/services/database_service.dart`: SQLite schema, migrations, and all CRUD for devices/logs/protocols/protocol-device links.
- `lib/services/notification_service.dart`: local notification initialization, reminder scheduling, low-stock/depletion/missed-dose alerts.
- `lib/services/nfc_service.dart`: Dart-side NFC API; checks availability, reads tag UIDs, and (Android-first) handles NovoPen reads and enrollment auto-detect.
- `lib/services/export_service.dart`: CSV/PDF export and JSON backup/restore helpers.
- `lib/services/settings_service.dart`: persisted app preferences (theme, reminders, NFC toggles, disclaimer/onboarding flags, NovoPen import cursors, etc.).
- `lib/services/app_lock_service.dart`: app PIN lock state/validation utilities.

### Screens (top-level tabs/pages)

- `lib/screens/main_scaffold.dart`: bottom tab scaffold and tab routing.
- `lib/screens/dashboard_screen.dart`: main dashboard (today progress, banners, due chips, protocol sections, device cards, NFC quick-scan).
- `lib/screens/inventory_screen.dart`: filterable container list (active/depleted/archived/pen/vial).
- `lib/screens/history_screen.dart`: dose history timeline, summary stats, filters/grouping.
- `lib/screens/settings_screen.dart`: app settings UI (appearance, notification toggles, NFC behavior, exports, backup/restore, app lock, clear data).
- `lib/screens/onboarding_screen.dart`: first-run onboarding flow shown before main app.
- `lib/screens/disclaimer_screen.dart`: required first-run legal acknowledgement gate.
- `lib/screens/analytics_screen.dart`: action-first analytics layout (action needed, KPI summary, consistency calendar, scorecards, inventory outlook, site insight).

### Shared constants

- `lib/constants/legal_text.dart`: single source of truth for user-facing legal disclaimer copy used in first-run disclaimer + Settings.

### Modals / detail pages

- `lib/modals/log_dose_modal.dart`: manual log confirmation/edit modal with optional dose overrides.
- `lib/modals/nfc_scan_modal.dart`: active NFC scan modal with timeout, detection state, retry/manual fallback.
- `lib/modals/device_detail_modal.dart`: full device detail page with metadata and actions.
- `lib/modals/edit_device_modal.dart`: edit enrolled device settings and schedule details.
- `lib/modals/dose_detail_modal.dart`: view/edit/delete an individual logged dose.
- `lib/modals/recon_calculator_modal.dart`: reconstitution calculator (draw mode + water mode).
- `lib/modals/create_protocol_modal.dart`: create/edit protocol and assign devices.

### Enroll wizard

- `lib/modals/enroll/enroll_modal.dart`: multi-step enroll flow container/orchestrator.
- `lib/modals/enroll/step_type_method.dart`: step 1, choose container type and enrollment method.
- `lib/modals/enroll/step_nfc_scan.dart`: NFC enrollment scan step, duplicate detection, timeout handling.
- `lib/modals/enroll/step_compound_details.dart`: compound metadata input step.
- `lib/modals/enroll/step_dosing_config.dart`: dosing/schedule step, derived dose calculations, day picker/validation.

### Reusable widgets

- `lib/widgets/device_card.dart`: main dashboard/inventory card for a device (progress, status, log CTA).
- `lib/widgets/dose_ring.dart`: circular remaining-dose painter widget.
- `lib/widgets/empty_state.dart`: generic empty state message/icon component.
- `lib/widgets/toast_overlay.dart`: app-level toast banner wired to provider state.
- `lib/widgets/badge_chip.dart`: compact chip/badge UI helper.
- `lib/widgets/animated_progress_bar.dart`: slim animated horizontal progress bar.
- `lib/widgets/pressable_scale.dart`: reusable touch feedback wrapper with press-scale animation.
- `lib/widgets/app_lock_gate.dart`: app lock gate that blocks UI until PIN unlock when enabled.
- `lib/widgets/body_site_picker.dart`: body injection site picker UI used during log editing.

### Utility math and date helpers

- `lib/utils/calculations.dart`: dose math, schedule-day evaluation, adherence calculations, and related helper functions.

## 5) Native platform files

### Android

- `android/app/src/main/kotlin/com/yourcompany/peptidetrack/MainActivity.kt`: registers native NFC handler with Flutter engine.
- `android/app/src/main/kotlin/com/yourcompany/peptidetrack/NfcReader.kt`: Android NFC reader-mode implementation; exposes availability/poll/finish plus NovoPen read and enrollment auto-detect methods.

### iOS

- `ios/Runner/AppDelegate.swift`: app startup plus native NFC channel registration.
- `ios/Runner/NfcReader.swift`: iOS CoreNFC implementation for availability/poll/finish and tag UID/type extraction (NovoPen-native path pending parity work).
- `ios/Runner/SceneDelegate.swift`: standard Flutter scene delegate for iOS app lifecycle.

## 6) CI / automation files

- `.github/workflows/ios-testflight.yml`: scheduled/manual iOS release build and TestFlight upload workflow.
- `.github/workflows/nightly-bug-scan.yml`: scheduled/manual nightly agent-based bug scan that creates a GitHub issue report.

## 7) Common “where should I look?” cheat sheet

- **A screen looks wrong** -> `lib/screens/...` and shared widgets in `lib/widgets/...`
- **Business rule seems wrong** -> `lib/providers/app_state.dart` and `lib/utils/calculations.dart`
- **DB bug or migration issue** -> `lib/services/database_service.dart`
- **Reminder/notification issue** -> `lib/services/notification_service.dart`
- **NFC problem** -> `lib/services/nfc_service.dart` + native `NfcReader` files
- **Theme/color inconsistency** -> `lib/theme/app_theme.dart`
- **Enroll flow bug** -> `lib/modals/enroll/...`
- **Analytics UX/copy** -> `lib/screens/analytics_screen.dart` + `docs/ANALYTICS_ONE_PAGE_GUIDE.md`

## 8) User documentation

- `docs/SETTINGS_PAGE_GUIDE.md`: full end-user Settings explanation.
- `docs/SETTINGS_QUICK_REFERENCE.md`: short one-page Settings cheat sheet.
- `docs/ANALYTICS_ONE_PAGE_GUIDE.md`: one-page user guide for the redesigned Analytics screen.

## 9) Suggested reading order (fast onboarding)

1. `lib/main.dart`
2. `lib/app.dart`
3. `lib/providers/app_state.dart`
4. `lib/models/device.dart`, `lib/models/dose_log.dart`, `lib/models/protocol.dart`
5. `lib/services/database_service.dart`, `lib/services/notification_service.dart`, `lib/services/nfc_service.dart`
6. `lib/screens/main_scaffold.dart` and `lib/screens/dashboard_screen.dart`

