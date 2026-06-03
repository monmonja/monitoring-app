# AdMob Integration — Remaining Steps

## 1. Create an AdMob Account
- Go to https://admob.google.com and sign up
- Add your app (Android package name: `com.example.app`)

## 2. Replace Test Ad Unit IDs
Currently configured with Google's test IDs. Before publishing, replace them:

**Files to update:**
- `lib/core/ad_banner.dart` — default test IDs (optional: make the ad unit ID configurable via environment/settings)
- `lib/screens/dashboard_tab.dart:456` — banner ad unit ID
- `lib/screens/watch_detail_screen.dart:160` — banner ad unit ID
- `android/app/src/main/AndroidManifest.xml:7` — app ID

Replace:
- Test app ID: `ca-app-pub-3940256099942544~3347511713` → Your real app ID
- Test banner ID: `ca-app-pub-3940256099942544/6300978111` → Your real ad unit ID

## 3. iOS Setup (if deploying to iOS)
- Add `google_mobile_ads` to your Podfile
- Add AdMob app ID to `ios/Runner/Info.plist`:
  ```xml
  <key>GADApplicationIdentifier</key>
  <string>ca-app-pub-################~##########</string>
  ```

## 4. Privacy & Consent
- For GDPR/European users, integrate a consent management platform (e.g., `user_messaging_platform`)
- Add a privacy policy link to your app

## 5. Test Before Publishing
- Run on a real device with test IDs (already configured)
- Verify banners render correctly on both Dashboard and Watch Detail screens
- Switch to real ad units only during final release testing
