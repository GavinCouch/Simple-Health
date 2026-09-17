#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/smoke
trap 'adb logcat -d > build/smoke/logcat.txt || true' EXIT
apk=build/downloads/simple-health.apk
if [[ ! -f "$apk" ]]; then
  apk=build/downloads/simple-health-debug.apk
fi
apksigner=$(find "$ANDROID_HOME/build-tools" -name apksigner -type f | sort -V | tail -n 1)
"$apksigner" verify --verbose --print-certs "$apk" > build/smoke/signature.txt
adb install -r "$apk"
adb logcat -c
adb shell am start -W -n com.example.simple_health/.MainActivity
sleep 8
adb shell pidof com.example.simple_health
adb exec-out screencap -p > build/smoke/launch.png
adb logcat -d > build/smoke/logcat.txt
if grep -E 'FATAL EXCEPTION|E/flutter.*Unhandled Exception' build/smoke/logcat.txt; then
  exit 1
fi
