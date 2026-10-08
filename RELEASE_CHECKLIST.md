# DreamLife House — Release Candidate Checklist

## Product
- [x] Original DreamLife House identity and original NPC/content names
- [x] Core house, character, dress-up, cooking, pet, garden, daily-life and friendship loops
- [x] Onboarding and family-friendly purchase confirmation setting
- [x] Reduced-motion and VoiceOver-oriented labels/hints on onboarding
- [x] Save backup recovery and persisted-data sanitization

## Privacy
- [x] Privacy manifest included (`PrivacyInfo.xcprivacy`)
- [x] Tracking disabled in manifest
- [x] No collected-data types declared by the current offline build
- [x] UserDefaults required-reason API declaration included

## Verification completed in this environment
- [x] Swift parser check for all Swift sources
- [x] plist syntax checks
- [x] ZIP integrity check
- [ ] `xcodebuild` compile (requires macOS/Xcode)
- [ ] XCTest execution (requires macOS/Xcode)
- [ ] iOS Simulator smoke test (requires macOS/Xcode)
- [ ] Physical iPhone/iPad test

## Before App Store submission
- [x] App icon (1024×1024, opaque) and launch screen assets added (v2.56)
- [x] iPad orientations + export-compliance key in Info.plist (v2.56)
- [ ] Replace `com.example.dreamlifehouse` with the production bundle identifier and set `DEVELOPMENT_TEAM`.
- [ ] Build with Xcode 26 / iOS 26 SDK (required for uploads since 28 April 2026).
- [ ] Take App Store screenshots (6.9" iPhone and 13" iPad) and add localized metadata.
- [ ] Privacy policy URL and "Data Not Collected" privacy answers in App Store Connect.
- Run archive/signing validation with the intended Apple Developer team.
- Re-check the privacy manifest whenever analytics, ads, networking SDKs, or new required-reason APIs are added.
