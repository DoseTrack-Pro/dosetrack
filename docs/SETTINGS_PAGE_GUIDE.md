# Settings Page Guide (End-User)

This guide explains what each option on the `Settings` page controls, in plain language, so you know exactly what to expect.

## Appearance

### Theme
- **System**: App follows your phone's light/dark setting.
- **Light**: App always uses light mode.
- **Dark**: App always uses dark mode.

## Notifications

### Dose reminders
- Controls scheduled "dose due" notifications.
- If turned **off**, dose reminder schedules are cleared.
- If turned **on**, reminders are scheduled again based on each compound's schedule.

### Low inventory
- Controls alerts when a compound goes below its low-stock threshold.
- Threshold is set per compound (not globally).

### Missed dose
- Controls "missed yesterday" alerts.
- These alerts are checked when you next open the app (not as a real-time background job).

## Privacy Lock

### Require unlock
- Locks app content behind PIN/biometric.
- First time enabling it, you must create a 4-digit PIN.

### Use biometrics
- If your device supports it, allows fingerprint/Face Unlock instead of entering PIN each time.
- If biometrics are unavailable, this option is shown but effectively disabled.

### Inactivity lock timer
- Defines how long app can stay in background before locking.
- Options:
  - **Now**: lock immediately when app backgrounds.
  - **1m / 5m / 15m**: lock after that idle background duration.

### Change PIN
- Updates your existing 4-digit app lock PIN.

### Lock now
- Immediately locks app content right away.

## NFC Scanning

### Auto-log on scan
- If enabled, app can log dose immediately after tag is detected.
- In practice, this is controlled together with **Confirm before logging** below.

### Confirm before logging
- If enabled, app always shows confirmation before saving a dose.
- If disabled and Auto-log is enabled, scan can save without extra confirmation.

### How Auto-log + Confirm interact
- **Auto-log ON + Confirm OFF** -> fastest flow (auto-save possible).
- **Auto-log ON + Confirm ON** -> still asks for confirmation.
- **Auto-log OFF** -> confirmation flow/manual confirmation behavior is used.

### Scan timeout
- How long the NFC dose-logging scan waits before timing out.
- Options: **10s / 20s / 30s**.

## Data & Export

### Export as CSV
- Creates a spreadsheet-friendly export of your data.

### Export as PDF
- Creates a formatted report file.

### Backup data (JSON)
- Creates a `.json` backup file via share/save flow.

### Restore from backup
- Lets you select a `.json` backup and replace current app data with it.
- Restore asks for confirmation first.

### Backup includes
- Compounds
- Dose logs
- Protocols
- Protocol-to-device links

### Backup does NOT include
- App settings (theme, NFC, alert toggles, etc.)
- App lock PIN
- OS-level permissions

## Danger Zone

### Clear all data
- Permanently deletes all compounds and logs.
- Cannot be undone.

## Legal

### Disclaimer
- Opens a read-only copy of the app disclaimer text.
- This section is informational only; it does not change your stored acceptance state.

## Version label
- Bottom text (e.g. `Pep Tracker Pro v1.0.0`) shows current app version string.

