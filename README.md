# PeptideTrack — Flutter

Native iOS & Android peptide dosing tracker with NFC auto-logging.

---

## Tech Stack

| Layer | Library |
|---|---|
| Framework | Flutter 3.x / Dart 3.3+ |
| State | flutter_riverpod |
| Navigation | Built-in Navigator (push/pop) + IndexedStack tabs |
| Database | sqflite (SQLite, local-first) |
| NFC | Custom native — Swift CoreNFC (iOS) + Kotlin NfcAdapter (Android), via `MethodChannel('com.adam.dosevault/nfc')` |
| Notifications | flutter_local_notifications |
| Charts | fl_chart |
| PDF | pdf + printing |
| Export / Share | share_plus |
| IDs | uuid |

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | ≥ 3.19 | https://flutter.dev/docs/get-started/install |
| Dart SDK | ≥ 3.3 (bundled with Flutter) | — |
| Android Studio | latest | For Android emulator + build tools |
| Xcode | ≥ 15 (macOS only) | For iOS builds |
| CocoaPods | latest (macOS only) | `sudo gem install cocoapods` |

---

## Getting Started

### 1. Clone / extract project

```bash
cd peptidetrack_flutter
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure bundle identifiers

**Android** — edit `android/app/build.gradle`:
```gradle
defaultConfig {
    applicationId "com.yourcompany.peptidetrack"
    ...
}
```

**iOS** — in Xcode, open `ios/Runner.xcworkspace` and set:
- Bundle Identifier: `com.yourcompany.peptidetrack`
- Team: your Apple Developer account

### 4. Run on device

```bash
# List available devices
flutter devices

# Run on Android (connects via USB or emulator)
flutter run -d <device-id>

# Run on iOS (requires macOS + Xcode)
flutter run -d <device-id>
```

> NFC cannot be tested on Android emulator or iOS Simulator.
> You need a physical device for NFC features.

### 5. Build for release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
```

---

## iOS NFC Setup (required)

1. Log in to [developer.apple.com](https://developer.apple.com)
2. Go to Certificates, IDs & Profiles → Identifiers
3. Select your App ID and enable **Near Field Communication Tag Reading**
4. Regenerate your provisioning profile
5. In Xcode → Signing & Capabilities → add **Near Field Communication Tag Reading**

The `Info.plist` and entitlement declaration are already in the project.

---

## NFC Tags

Use **NTAG213** or **NTAG215** stickers (25mm round, ~$0.50 each on Amazon).
These support NDEF write with enough capacity for a UUID.
One sticker per container — attach it to the side of the pen or vial.

---

## Project Structure

```
lib/
├── main.dart               # Entry point — boots services, launches app
├── app.dart                # MaterialApp + Riverpod init
├── theme/
│   └── app_theme.dart      # Colors, typography, button/input themes
├── models/
│   ├── device.dart         # Device, ContainerType, DoseSchedule
│   └── dose_log.dart       # DoseLog, LogMethod
├── utils/
│   └── calculations.dart   # Dose math, adherence, streak, date helpers
├── services/
│   ├── database_service.dart     # SQLite CRUD (sqflite)
│   ├── nfc_service.dart          # MethodChannel bridge to native NFC readers
│   ├── notification_service.dart # Local push scheduling
│   └── export_service.dart       # CSV + PDF via share sheet
├── providers/
│   └── app_state.dart      # Riverpod StateNotifier — all business logic
├── widgets/
│   ├── dose_ring.dart       # CustomPainter SVG progress ring
│   ├── badge_chip.dart      # Colored label chip
│   ├── device_card.dart     # Dashboard device card
│   ├── empty_state.dart     # Zero-state placeholder
│   └── toast_overlay.dart   # Animated bottom toast
├── screens/
│   ├── main_scaffold.dart   # Bottom nav shell + IndexedStack
│   ├── dashboard_screen.dart
│   ├── inventory_screen.dart
│   ├── history_screen.dart
│   ├── analytics_screen.dart
│   └── settings_screen.dart
└── modals/
    ├── nfc_scan_modal.dart       # 3-state NFC scanner with countdown
    ├── log_dose_modal.dart       # Manual dose confirm bottom sheet
    ├── device_detail_modal.dart  # Full device detail page
    └── enroll/
        ├── enroll_modal.dart         # Wizard orchestrator
        ├── step_type_method.dart     # Step 1: container + tracking type
        ├── step_nfc_scan.dart        # Step 2: write NFC tag (if NFC flow)
        ├── step_compound_details.dart # Step 3: name, vendor, batch, COA
        └── step_dosing_config.dart   # Step 4: mg/mL/mcg + live IU calc
```

---

## Dose Formula

```
doseVolumeIU = (desiredDoseMcg / (peptideMg × 1000)) × reconVolumeMl × 100
totalDoses   = floor((reconVolumeMl × 100) / doseVolumeIU)
```

## NFC Flow

**Enrollment:** App generates a UUID → writes it as an NDEF text record to a blank sticker.

**Logging:** User taps "Scan NFC to Log" → 10-second countdown starts → tag is read → UUID is matched against enrolled devices → confirmation shown → dose recorded.

**Timeout:** If no tag in 10s → timeout state shows retry + manual fallback list.

---

## Troubleshooting

**`flutter pub get` fails** — run `flutter doctor` to verify your SDK is set up correctly.

**NFC read returns null on Android** — ensure the tag has a valid NDEF text record. Tags formatted with other apps may return hardware UID instead.

**iOS build fails with NFC entitlement error** — verify NFC capability is enabled in your Apple Developer App ID and your provisioning profile is regenerated.

**Notifications not firing on iOS** — make sure permissions were granted at first launch. Check Settings → Notifications → PeptideTrack.

**`sqflite` crash** — unlike `expo-sqlite`, sqflite compiles into every Flutter build automatically. No special build step needed.
