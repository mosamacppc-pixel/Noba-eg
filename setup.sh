#!/usr/bin/env bash
# Run once, from this folder, with Flutter installed.
set -e
flutter create --org com.nobaeg --project-name noba_app --platforms android,ios .
M=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' $M || sed -i 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent></queries>\n    <application|' $M
flutter pub get
flutter analyze || true
echo "Done. Run: flutter run"
