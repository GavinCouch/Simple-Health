# Simple Health

Simple Health is an Android food journal. Log calories by meal, adjust servings,
set a daily goal, and go back to edit earlier days. Foods you use often appear
in Quick add. The journal moves to the next day at midnight, even while open.

Sign-in is already part of the app. Create a username and password on your
device to get started. Accounts and journals live on that device, with a
separate journal for each account. There is no server, email recovery, or cloud
sync. Clearing app storage or uninstalling can remove your data.

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

Each run checks formatting, analysis, tests, and the website JavaScript, then
builds and launches the APK in an Android emulator. Pushes to `main` and manual runs produce a signed release APK and
Android App Bundle. Pull requests produce a debug APK without signing secrets.

Open a successful run and download `simple-health-android-<commit>` under
**Artifacts**. Extract the ZIP and install `simple-health.apk` on your phone.
Android may ask you to allow installation from your browser or file manager.
The `.aab` is for store uploads and cannot be installed directly. Downloads
include SHA-256 checksums and stay available for 30 days.
An `android-smoke-<commit>` artifact contains the launch screenshot, device logs,
and signing certificate details.

Release builds use the same signing key and an increasing build number, so
future downloads can update an existing release installation. Older debug
APKs have a different certificate and cannot be updated with a release APK.
Keep any data you need before replacing an old debug installation.

Pushing a version tag such as `v1.0.0-beta.1` runs the same checks and attaches
the signed files to a GitHub pre-release. Tags without a suffix create a normal
release. Nothing is automatically submitted to Google Play.

### Signing

The repository's Actions secrets hold `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD`. The key alias is `simple-health`. The private key
and password must stay out of git; keep a backup for future app updates.

For a fork, add your own PKCS12 keystore with that alias and the same key/store
password to those secrets. For a local release build, set
`ANDROID_KEYSTORE_PATH` and `ANDROID_KEYSTORE_PASSWORD`, then run
`flutter build apk --release`. A release build fails if signing is missing.

## Local checks and build

```sh
cd simple_health
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Tests cover account isolation, sign-in, database reopening and upgrades,
editing/removal, failed saves, quick-add suggestions, and daily rollover.
Upgrades from the original account-free database keep its unowned records in
`legacy_entries` and `legacy_settings` for recovery instead of deleting them
or assigning them to an arbitrary account. Data deleted by an earlier version
cannot be restored by this update.

## Website

`website/` contains the separate browser version of the tracker. Serve that
folder with a static HTTP server. The website saves entries in browser storage;
it does not use the mobile SQLite database. The Android workflow does not deploy
the website.
