# NOBA App (Flutter)

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. In this folder run `./setup.sh` (creates android/ios, adds INTERNET permission, runs analyze).
3. Plug in a phone or start an emulator, then `flutter run`.
4. Edit `lib/config.dart` for the store domain, token, WhatsApp number and gift end date.

Release: `flutter build appbundle` (Google Play) and `flutter build ipa` (App Store, needs a Mac).

## Cloud build (Bitrise)
1. Push this folder to a GitHub repo.
2. On bitrise.io: Add new app, pick the repo, choose the existing `bitrise.yml`.
3. Run workflow `android-apk`. The APK appears under Artifacts; download and install it on an Android phone.
iOS and store-signed builds need your Apple/Google signing files (added later in Bitrise Code Signing).
