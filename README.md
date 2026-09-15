# Simple Health

An offline Flutter calorie tracker with food logging by meal, fractional
servings, daily goals, entry editing/removal, and date history. The interface
keeps the controls and calorie totals without branding or motivational copy.

## Run the mobile app

Use Flutter **3.47.4** (Dart 3.13.3) with the Android or iOS development tools.

```sh
cd simple_health
flutter pub get
flutter run
```

Food entries and goals are stored in an on-device SQLite database. They do not
sync between devices or import automatically from the website. The mobile app
targets Android and iOS; iOS builds require macOS and Xcode.

## Automated Android builds

[Android build workflow](https://github.com/GavinCouch/Simple-Health/actions/workflows/android.yml)
runs on pushes, pull requests, and manual **Run workflow** requests.

Each run checks Dart formatting, runs static analysis and tests, checks the
website JavaScript, builds a development APK, and uploads it as an artifact.
Open a successful workflow run, then download `simple-health-android-<commit>`
from **Artifacts**. Extract the ZIP to get `app-debug.apk`. Artifacts are kept
for 14 days. No signing secrets are needed for this development build.

This APK uses development signing. Store distribution requires configuring
release signing; this workflow does not publish to Google Play or the App Store.

## Local checks and build

```sh
cd simple_health
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Website

`website/` contains the separate browser version of the tracker. Serve that
folder with a static HTTP server. The website saves entries in browser storage;
it does not use the mobile SQLite database. The Android workflow does not deploy
the website.
