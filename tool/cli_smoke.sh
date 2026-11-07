#!/usr/bin/env bash
# CLI end-to-end smoke test on a running Android emulator.
#
#   tool/cli_smoke.sh <tag> [--define-file ai_secrets.json] [label|@swipe ...]
#
# Launches the app with `flutter run` in the background so Dart-side output
# (framework errors, RenderFlex overflows) is captured from the first frame --
# on this Flutter version that output does NOT reach `adb logcat`. Then it
# screenshots the first screen, taps each label (matched against the
# accessibility tree's content-desc/text), screenshots after each tap, and
# fails on any Flutter error. A label of "@swipe" scrolls the screen up.
# Output: output/emulator-ux/<tag>-*.png and <tag>-flutter.log (gitignored).
set -uo pipefail
export MSYS_NO_PATHCONV=1

ADB="${ADB:-$HOME/AppData/Local/Android/sdk/platform-tools/adb.exe}"
PKG=com.example.diet_app2
DEVICE="${DEVICE:-emulator-5554}"
OUT=output/emulator-ux
TAG="${1:?usage: cli_smoke.sh <tag> [--define-file f] [label ...]}"
shift
DEFINE=()
LABELS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --define-file) DEFINE+=(--dart-define-from-file="$2"); shift ;;
    --build) ;; # kept for compatibility: `flutter run` always builds
    # --apk: reuse build/app/outputs/flutter-apk/app-debug.apk instead of
    # running Gradle. Build first, then `gradlew --stop`: on a low-RAM host,
    # Gradle and the emulator together crashed the emulator.
    --apk) DEFINE+=(--use-application-binary=build/app/outputs/flutter-apk/app-debug.apk) ;;
    *) LABELS+=("$1") ;;
  esac
  shift
done

cd "$(dirname "$0")/.."
mkdir -p "$OUT"
LOG="$OUT/$TAG-flutter.log"

"$ADB" -s "$DEVICE" get-state >/dev/null 2>&1 || { echo "FAIL: no emulator/device"; exit 1; }
"$ADB" -s "$DEVICE" shell am force-stop "$PKG"

flutter run -d "$DEVICE" --debug "${DEFINE[@]}" > "$LOG" 2>&1 &
RUN_PID=$!
finish() {
  "$ADB" -s "$DEVICE" shell am force-stop "$PKG" >/dev/null 2>&1
  sleep 2
  kill "$RUN_PID" >/dev/null 2>&1 || true
}
trap finish EXIT

# Wait (up to 6 min) for the app to be running under `flutter run`.
for _ in $(seq 1 180); do
  grep -q "Flutter run key commands" "$LOG" && break
  if ! kill -0 "$RUN_PID" 2>/dev/null; then
    echo "FAIL: flutter run exited"; tail -20 "$LOG"; exit 1
  fi
  sleep 2
done
grep -q "Flutter run key commands" "$LOG" || { echo "FAIL: app did not start"; tail -20 "$LOG"; exit 1; }
sleep 6

shot() { "$ADB" -s "$DEVICE" exec-out screencap -p > "$OUT/$TAG-$1.png"; echo "shot $OUT/$TAG-$1.png"; }

# Prints "x y" for the center of the first node whose content-desc or text
# contains $1, or nothing. A "last:" prefix picks the last match in document
# order -- use it for bottom-nav tabs whose label also appears in page
# content (e.g. "last:التمارين").
find_center() {
  local pick="head -1" needle="$1"
  case "$needle" in last:*) pick="tail -1"; needle="${needle#last:}" ;; esac
  # Remove the previous dump first: a failed dump would otherwise leave a
  # stale file and the tap would land on an old screen's coordinates.
  "$ADB" -s "$DEVICE" shell rm -f /sdcard/ui.xml >/dev/null 2>&1
  "$ADB" -s "$DEVICE" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  "$ADB" -s "$DEVICE" shell cat /sdcard/ui.xml 2>/dev/null | tr '>' '\n' \
    | grep -F -- "$needle" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | $pick \
    | sed -E 's/bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' \
    | awk '{ printf "%d %d\n", ($1+$3)/2, ($2+$4)/2 }'
}

# Wait (up to ~2 min) until the home shell is on screen: a JIT debug build is
# slow to draw its first frame and the native splash has no labels.
READY_LABEL="${READY_LABEL:-اليوم}"
for _ in $(seq 1 60); do
  [ -n "$(find_center "$READY_LABEL" || true)" ] && break
  sleep 2
done
# The shell's labels appear while the splash->home route transition is still
# running, and Flutter ignores touches during transitions; let it settle.
sleep 8

shot 00-launch
i=1
for label in "${LABELS[@]}"; do
  # "@tab:N" taps bottom-nav slot N (1 = Today ... 5 = Me). Five equal slots
  # laid out right-to-left on a 1080px-wide screen, bar centered at y=2100.
  # Label matching is unreliable for tabs: the same words appear in content.
  if [[ "$label" == @tab:* ]]; then
    n="${label#@tab:}"
    x=$(( 1080 - (2 * n - 1) * 108 ))
    # Tapping a tab twice is harmless and survives a dropped first touch.
    "$ADB" -s "$DEVICE" shell input tap "$x" 2100
    sleep 1
    "$ADB" -s "$DEVICE" shell input tap "$x" 2100
    sleep 3
    shot "$(printf %02d $i)-tab$n"
    i=$((i + 1))
    continue
  fi
  # "@text:VALUE" types ASCII into the focused field ("%s" = space).
  if [[ "$label" == @text:* ]]; then
    "$ADB" -s "$DEVICE" shell input text "${label#@text:}"
    sleep 1
    shot "$(printf %02d $i)-text"
    i=$((i + 1))
    continue
  fi
  # "@tap:X,Y" taps raw device pixels (for controls whose label also
  # appears in other text on the same screen).
  if [[ "$label" == @tap:* ]]; then
    xy="${label#@tap:}"
    "$ADB" -s "$DEVICE" shell input tap "${xy%,*}" "${xy#*,}"
    sleep 2
    shot "$(printf %02d $i)-tapxy"
    i=$((i + 1))
    continue
  fi
  # "@key:CODE" sends an Android keyevent (4 = back, hides the keyboard).
  if [[ "$label" == @key:* ]]; then
    "$ADB" -s "$DEVICE" shell input keyevent "${label#@key:}"
    sleep 2
    continue
  fi
  if [ "$label" = "@swipe" ]; then
    "$ADB" -s "$DEVICE" shell input swipe 540 1700 540 700 400
    sleep 2
    shot "$(printf %02d $i)-swipe"
    i=$((i + 1))
    continue
  fi
  # Poll up to ~60s: first frames on the emulator can be slow.
  xy=""
  for _ in $(seq 1 30); do
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
  "$ADB" -s "$DEVICE" shell input tap $xy
  sleep 2
  shot "$(printf %02d $i)-tap"
  i=$((i + 1))
done
sleep 2

errors="$(grep -nE 'EXCEPTION CAUGHT|RenderFlex overflowed|overflowed by|Another exception was thrown|Unhandled Exception|\[ERROR' "$LOG" || true)"
if [ -n "$errors" ]; then
  echo "FAIL: Flutter errors (full log: $LOG):"
  echo "$errors" | head -20
  exit 1
fi
echo "PASS: $TAG (${#LABELS[@]} steps, no Flutter errors; log $LOG)"
