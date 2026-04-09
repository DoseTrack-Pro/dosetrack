# iOS TestFlight CI Setup (GitHub Actions)

This project includes `.github/workflows/ios-testflight.yml` to build iOS and upload to TestFlight from GitHub Actions macOS runners.

## 1) Prerequisites

- Apple Developer Program membership (active)
- App Store Connect app created for this bundle ID
- iOS Bundle ID configured in Xcode project

Current bundle ID in this repo:

- `com.yourcompany.peptidetrack`

## 2) Required GitHub Secrets

Set these in **GitHub repo -> Settings -> Secrets and variables -> Actions**:

- `IOS_BUNDLE_ID`
  - Example: `com.yourcompany.peptidetrack`
- `APP_STORE_CONNECT_ISSUER_ID`
  - From App Store Connect API key page
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
  - API key ID (e.g., `ABC123XYZ`)
- `APP_STORE_CONNECT_PRIVATE_KEY`
  - Contents of the `.p8` key file (full text, including BEGIN/END lines)

## 3) App Store Connect API Key

In App Store Connect:

1. Users and Access -> Integrations -> App Store Connect API
2. Create key (Admin role recommended for CI upload/signing)
3. Save:
   - Issuer ID
   - Key ID
   - `.p8` private key file (download once)

## 4) Running Builds

- Manual run:
  - GitHub -> Actions -> **iOS TestFlight** -> Run workflow
- Scheduled run:
  - Every Monday at 12:00 UTC (configured in workflow)

## 5) Troubleshooting

- Signing errors:
  - Verify `IOS_BUNDLE_ID` matches App Store Connect app/bundle ID exactly
  - Confirm API key values are correct and private key has full content
- Upload errors:
  - Ensure app record exists in App Store Connect
  - Ensure build/version numbers are incrementing as needed

