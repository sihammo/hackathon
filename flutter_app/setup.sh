#!/usr/bin/env bash
# SolveX Alert — one-time project setup (macOS / Linux).
# Run from the project folder:   bash setup.sh
set -e
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed. Install it first: https://docs.flutter.dev/get-started/install"
  exit 1
fi

echo "==> 1/4  Generating Android & iOS platform files (existing files are kept)"
flutter create . --org com.solvex --project-name solvex_alert --platforms android,ios

echo "==> 2/4  Android: minSdk 23 (required by Firebase)"
for f in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$f" ]; then
    perl -pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 23/; s/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion 23/' "$f"
  fi
done

echo "==> 3/4  iOS: permission texts and minimum version"
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && [ -x /usr/libexec/PlistBuddy ]; then
  setkey() {
    /usr/libexec/PlistBuddy -c "Delete :$1" "$PLIST" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST"
  }
  setkey NSBluetoothAlwaysUsageDescription "SolveX Alert se connecte à votre boîtier SolveX en Bluetooth pour détecter les accidents."
  setkey NSLocationWhenInUseUsageDescription "Votre position est envoyée aux secours en cas d'accident."
  setkey NSLocationAlwaysAndWhenInUseUsageDescription "Votre position est envoyée aux secours en cas d'accident."
fi
if [ -f ios/Podfile ]; then
  perl -pi -e "s/^#?\s*platform :ios, '.*'/platform :ios, '15.0'/" ios/Podfile
fi

echo "==> 4/4  Downloading packages"
if ! flutter pub get; then
  echo
  echo "Package versions could not be resolved with your Flutter version."
  echo "Try:  flutter pub upgrade --major-versions   (keep flutter_blue_plus on 1.x)"
  exit 1
fi

echo
echo "Done. Next steps:"
echo "  1. dart pub global activate flutterfire_cli"
echo "  2. flutterfire configure --platforms=android,ios"
echo "  3. flutter run   (on an Android phone with USB debugging)"
echo "See README.md for the Firebase console steps and how to create the admin account."
