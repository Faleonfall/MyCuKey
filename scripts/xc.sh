#!/usr/bin/env bash
#
# Deterministic command-line build/test for MyCuKey.
#
# Why this exists:
#   The default `xcodebuild` invocation drifts from the open Xcode session
#   because automatic code signing, an unpinned simulator destination, and a
#   shared DerivedData folder all resolve differently outside the IDE. This
#   script removes those three sources of nondeterminism:
#     1. Simulator builds need no real signing -> signing disabled entirely.
#     2. One pinned simulator (by name) -> same destination every run.
#     3. Isolated DerivedData (./.build-cli) -> never fights the Xcode session.
#
# Usage:
#   scripts/xc.sh build        # build the app for the pinned simulator
#   scripts/xc.sh test         # run the MyCuKeyTests unit suite
#   scripts/xc.sh format       # swift-format all sources in place
#   scripts/xc.sh format-check # fail if any source is unformatted (CI gate)
#   scripts/xc.sh boot         # boot the pinned simulator
#   scripts/xc.sh clean        # remove the isolated DerivedData
#   scripts/xc.sh which        # print the resolved simulator + paths
#
set -euo pipefail

PROJECT="MyCuKey.xcodeproj"
APP_SCHEME="MyCuKey"
TEST_SCHEME="MyCuKeyTests"
UITEST_SCHEME="MyCuKeyUITests"
KEYBOARD_EXT_ID="com.kvolodymyr.MyCuKey.KeyboardExtension"

# Pinned simulator. Change DEVICE_NAME here to repin; resolution is by name so
# it stays stable across machines even when the runtime gets a patch update.
DEVICE_NAME="${MYCUKEY_SIM:-iPhone 17}"

# Isolated build output, kept out of git (see .gitignore: .build-cli/).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="$ROOT/.build-cli/DerivedData"

# Signing off + no Xcode-session contention. Applied to every xcodebuild call.
# Destination is appended per-command using the resolved UDID (name matching is
# ambiguous when the runtime exposes arm64 and x86_64 entries for one device).
COMMON_ARGS=(
  -project "$PROJECT"
  -derivedDataPath "$DERIVED"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=""
  CODE_SIGN_STYLE=Manual
)

resolve_udid() {
  xcrun simctl list devices available \
    | grep -F "$DEVICE_NAME (" \
    | head -1 \
    | grep -oE '[0-9A-F-]{36}'
}

ensure_booted() {
  local udid; udid="$(resolve_udid)"
  if [ -z "$udid" ]; then
    echo "error: simulator '$DEVICE_NAME' not found. Set MYCUKEY_SIM or create it." >&2
    exit 1
  fi
  if ! xcrun simctl list devices | grep "$udid" | grep -q "(Booted)"; then
    xcrun simctl boot "$udid" 2>/dev/null || true
  fi
  echo "$udid"
}

# Run xcodebuild quietly: full output goes to a log file, the terminal shows
# only failures plus a final summary. Returns xcodebuild's real exit code (not
# the formatter's) so callers / CI fail correctly. This replaces the raw
# firehose that buffered/truncated and produced a wrong pass count.
LOG_DIR="$ROOT/.build-cli/logs"
run_xcodebuild() {
  local label="$1"; shift
  mkdir -p "$LOG_DIR"
  local log="$LOG_DIR/$label.log"

  local start=$SECONDS
  set +e
  xcodebuild "$@" > "$log" 2>&1
  local rc=$?
  set -e
  local elapsed=$((SECONDS - start))

  # Show only test failures and build errors inline; full log stays on disk.
  grep -iE "(Test Case .* failed |error:|BUILD FAILED|Testing failed)" "$log" | sed 's/^/  /' || true

  # grep -c prints a count and exits 1 on zero matches; the `|| true` keeps the
  # count without appending a spurious second value under `set -e`. Case-
  # insensitive to match both unit ("Test case '..' passed on 'Clone..'") and
  # UI-test ("Test Case '..' passed (1.2 seconds)") log formats.
  local passed failed
  passed=$(grep -ciE "Test Case .* passed " "$log" || true)
  failed=$(grep -ciE "Test Case .* failed " "$log" || true)

  # Sum the per-test runtimes the log already reports, e.g. "(1.475 seconds)".
  local testtime
  testtime=$(grep -oE '\([0-9]+\.[0-9]+ seconds\)' "$log" \
    | grep -oE '[0-9]+\.[0-9]+' \
    | awk '{ s += $1 } END { printf "%.2f", s+0 }')

  echo "------------------------------------------------------------"
  if [ "$rc" -eq 0 ]; then
    printf "RESULT  ok   %s passed, %s failed\n" "$passed" "$failed"
  else
    printf "RESULT  FAIL %s passed, %s failed  (exit %s)\n" "$passed" "$failed" "$rc"
  fi
  printf "TIME    %dm%02ds wall   %ss in tests\n" $((elapsed / 60)) $((elapsed % 60)) "$testtime"
  echo "log     $log"
  return $rc
}

cmd="${1:-build}"
case "$cmd" in
  build)
    udid="$(ensure_booted)"
    echo ">> build $APP_SCHEME on $DEVICE_NAME ($udid)"
    run_xcodebuild build "${COMMON_ARGS[@]}" -destination "platform=iOS Simulator,id=$udid" -scheme "$APP_SCHEME" build
    ;;
  test)
    udid="$(ensure_booted)"
    echo ">> test $TEST_SCHEME on $DEVICE_NAME ($udid)"
    run_xcodebuild test "${COMMON_ARGS[@]}" -destination "platform=iOS Simulator,id=$udid" -scheme "$TEST_SCHEME" test
    ;;
  format)
    echo ">> swift-format all sources in place"
    find "$ROOT/KeyboardExtension" "$ROOT/MyCuKey" "$ROOT/MyCuKeyTests" "$ROOT/MyCuKeyUITests" \
      -name '*.swift' -print0 \
      | xargs -0 xcrun swift-format format --in-place --
    echo "formatted"
    ;;
  format-check)
    echo ">> swift-format lint (strict)"
    find "$ROOT/KeyboardExtension" "$ROOT/MyCuKey" "$ROOT/MyCuKeyTests" "$ROOT/MyCuKeyUITests" \
      -name '*.swift' -print0 \
      | xargs -0 xcrun swift-format lint --strict --
    echo "clean"
    ;;
  uitest)
    # End-to-end test of the live keyboard extension. Make MyCuKey the only
    # software keyboard so focusing a field presents it directly (no globe
    # picker), then drive it through XCUITest.
    udid="$(ensure_booted)"
    echo ">> seed keyboard on $DEVICE_NAME ($udid)"
    xcrun simctl spawn "$udid" defaults write .GlobalPreferences AppleKeyboards \
      -array "$KEYBOARD_EXT_ID" "emoji@sw=Emoji" >/dev/null 2>&1
    xcrun simctl spawn "$udid" launchctl stop com.apple.SpringBoard >/dev/null 2>&1 || true
    # Let SpringBoard come back and settle before the test launches the app, so
    # the keyboard extension is registered and ready to present on first focus.
    xcrun simctl bootstatus "$udid" >/dev/null 2>&1 || true
    sleep 5
    echo ">> uitest $UITEST_SCHEME on $DEVICE_NAME ($udid)"
    run_xcodebuild uitest "${COMMON_ARGS[@]}" -destination "platform=iOS Simulator,id=$udid" -scheme "$UITEST_SCHEME" test
    ;;
  boot)
    udid="$(ensure_booted)"
    echo "booted: $DEVICE_NAME ($udid)"
    ;;
  clean)
    rm -rf "$ROOT/.build-cli"
    echo "removed .build-cli"
    ;;
  which)
    echo "device:  $DEVICE_NAME ($(resolve_udid))"
    echo "derived: $DERIVED"
    echo "project: $ROOT/$PROJECT"
    ;;
  *)
    echo "usage: scripts/xc.sh {build|test|format|format-check|boot|clean|which}" >&2
    exit 2
    ;;
esac
