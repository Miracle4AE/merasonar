# Android / production release checklist

Use this before Play Store upload or handing APKs outside your dev LAN.

## Signing

1. Create a dedicated keystore (`keytool` or Android Studio wizard).
2. Point `signingConfigs` in `android/app/build.gradle.kts` release to that keystore.
3. Remove the temporary `signingConfig = signingConfigs.getByName("debug")` hack from the release block.

## Android package & identity

4. Replace `applicationId` / namespace `com.example.deniz_app` with your bundle id.
5. Set `versionCode` / `versionName` deliberately (currently driven by Flutter `pubspec.yaml`).

## Launcher & branding

6. Replace `android/app/src/main/res/mipmap-*/ic_launcher.png` placeholders with production artwork.

## Network / security

7. Prefer **HTTPS** for any non-LAN backend. When TLS is enforced, tighten
   `android/app/src/main/res/xml/network_security_config.xml` (`cleartextTrafficPermitted` false on base-config).
8. LAN-only HTTP during development stays documented in `android/RELEASE_ANDROID_NOTES.txt`.

## Store policy

9. Declare location + photo/storage usage honestly in Play Console (matching in-app disclosures).
10. Re-run `./gradlew` / `flutter build appbundle --release` after each manifest change.

## QA

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
# or: flutter build appbundle --release
```
