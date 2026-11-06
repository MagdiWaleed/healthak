#!/usr/bin/env bash
# CLI end-to-end smoke test on a running Android emulator.
#
#   tool/cli_smoke.sh <tag> [--build] [--define-file ai_secrets.json] [label ...]
#
# Builds (optional), installs, cold-launches the app, screenshots the first
# screen, then taps each given label (matched against the accessibility tree's
# content-desc/text) and screenshots after each tap. Fails if logcat shows a
# Flutter/Dart exception. Screenshots land in output/emulator-ux/<tag>-*.png
# (gitignored).
set -euo pipefail
export MSYS_NO_PATHCONV=1

ADB="${ADB:-$HOME/AppData/Local/Android/sdk/platform-tools/adb.exe}"
PKG=com.example.diet_app2
OUT=output/emulator-ux
TAG="${1:?usage: cli_smoke.sh <tag> [--build] [--define-file f] [label ...]}"
shift
BUILD=0
DEFINE=()
LABELS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --build) BUILD=1 ;;
    --define-file) DEFINE=(--dart-define-from-file="$2"); shift ;;
    *) LABELS+=("$1") ;;
  esac
  shift
done

cd "$(dirname "$0")/.."
mkdir -p "$OUT"

"$ADB" get-state >/dev/null 2>&1 || { echo "FAIL: no emulator/device"; exit 1; }

if [ "$BUILD" = 1 ]; then
  flutter build apk --debug "${DEFINE[@]}" | tail -1
fi
"$ADB" install -r build/app/outputs/flutter-apk/app-debug.apk | tail -1

"$ADB" logcat -c
"$ADB" shell am force-stop "$PKG"
"$ADB" shell am start -n "$PKG/.MainActivity" >/dev/null
sleep 10

shot() { "$ADB" exec-out screencap -p > "$OUT/$TAG-$1.png"; echo "shot $OUT/$TAG-$1.png"; }

# Prints "x y" for the center of the first node whose content-desc or text
# contains $1, or nothing.
find_center() {
  "$ADB" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
  "$ADB" shell cat /sdcard/ui.xml | tr '>' '\n' \
    | grep -F -- "$1" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1 \
    | sed -E 's/bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' \
    | awk '{ printf "%d %d\n", ($1+$3)/2, ($2+$4)/2 }'
}

shot 00-launch
i=1
for label in "${LABELS[@]}"; do
  # Poll up to ~20s: the first screen may still be loading/animating.
  xy=""
  for _ in $(seq 1 10); do
    xy="$(find_center "$label" || true)"
    [ -n "$xy" ] && break
    sleep 2
  done
  sleep 1
  if [ -z "$xy" ]; then
    echo "FAIL: label not found: $label"
    shot "$(printf %02d $i)-missing"
    exit 1
  fi
  # shellcheck disable=SC2086
  "$ADB" shell input tap $xy
  sleep 2
  shot "$(printf %02d $i)-tap"
  i=$((i + 1))
done

# Only our process: launcher/system noise is not an app failure. Also catch
# Flutter framework errors, which log under the "flutter" tag at info level.
pid="$("$ADB" shell pidof "$PKG" | tr -d '' || true)"
if [ -z "$pid" ]; then
  echo "FAIL: app process died"
  exit 1
fi
errors="$( { "$ADB" logcat -d --pid="$pid" '*:E'; "$ADB" logcat -d --pid="$pid" -s flutter:I; }   | grep -iE 'exception|error|overflow|RenderFlex|Unhandled' || true)"
if [ -n "$errors" ]; then
  echo "FAIL: errors in logcat:"
  echo "$errors" | head -20
  exit 1
fi
echo "PASS: $TAG (${#LABELS[@]} taps, no Flutter errors)"
