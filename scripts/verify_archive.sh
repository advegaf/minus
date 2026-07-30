#!/bin/bash
# Asserts an archive is actually signed for the App Store before it is uploaded.
#
# Why this exists: 1.18.0 build 17 archived with an Apple DEVELOPMENT identity
# (no Apple Distribution certificate existed in the keychain), so every binary
# carried get-task-allow and the development variant of the Family Controls
# entitlement. xcodebuild said EXPORT SUCCEEDED, the upload succeeded, and
# TestFlight processed it. App Review rejected it a cycle later: "the app uses
# one or more Screen Time APIs but has not been submitted with the Family
# Controls entitlement." Nothing in the pipeline noticed. This does.
#
# Check the .ipa, not the .xcarchive. With automatic signing the archive is
# ALWAYS development-signed and -exportArchive re-signs it for distribution, so
# the archive's identity proves nothing either way. The IPA is what Apple gets.
#
# Usage: scripts/verify_archive.sh <path-to-.ipa | path-to-.xcarchive>
set -uo pipefail

TARGET_IN="${1:-}"
[ -z "$TARGET_IN" ] && { echo "usage: $0 <path-to-.ipa or .xcarchive>" >&2; exit 2; }

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

case "$TARGET_IN" in
  *.ipa)
    WORK=$(mktemp -d)
    ( cd "$WORK" && unzip -q "$TARGET_IN" ) || { echo "could not unzip $TARGET_IN" >&2; exit 2; }
    APP="$WORK/Payload/Minus.app"
    echo "note: checking the IPA, which is what Apple receives."
    ;;
  *)
    APP="$TARGET_IN/Products/Applications/Minus.app"
    echo "note: checking an ARCHIVE. With automatic signing this is normally"
    echo "      development-signed and says nothing about the submission."
    echo "      Export first and check the .ipa instead."
    ;;
esac
[ -d "$APP" ] || { echo "no Minus.app inside $TARGET_IN" >&2; exit 2; }

FAIL=0
note() { printf '  %-24s %s\n' "$1" "$2"; }
bad() { FAIL=1; printf '  %-24s FAIL  %s\n' "$1" "$2"; }

ents() { codesign -d --entitlements :- "$1" 2>/dev/null; }
has() { ents "$1" | grep -q "$2"; }

echo "verifying $(basename "$TARGET_IN")"

# 1. The signing identity. Apple Development here is the whole bug.
AUTH=$(codesign -dvv "$APP" 2>&1 | grep -m1 "^Authority=" | sed 's/Authority=//')
case "$AUTH" in
  *"Apple Distribution"*) note "authority" "$AUTH" ;;
  *) bad "authority" "$AUTH (needs Apple Distribution; create one in Xcode > Settings > Accounts > Manage Certificates)" ;;
esac

# 2. get-task-allow is the tell, but only when it is TRUE. A distribution
#    signature may carry the key set to false; a development one sets it true.
#    Checking presence alone reports a correct build as broken.
for target in "$APP" "$APP/PlugIns/MinusMonitor.appex" "$APP/PlugIns/MinusWidget.appex" "$APP/Extensions/MinusReport.appex"; do
  [ -d "$target" ] || { bad "$(basename "$target")" "missing from the bundle"; continue; }
  if ents "$target" | grep -q "get-task-allow</key><true/>"; then
    bad "$(basename "$target")" "get-task-allow is TRUE, so this is a development signature"
  else
    note "$(basename "$target")" "get-task-allow not true"
  fi
done

# 3. Screen Time entitlement where Screen Time APIs are actually used. The
#    widget calls none, so it must NOT be required to carry it.
for target in "$APP" "$APP/PlugIns/MinusMonitor.appex" "$APP/Extensions/MinusReport.appex"; do
  if has "$target" "com.apple.developer.family-controls"; then
    note "$(basename "$target")" "family-controls present"
  else
    bad "$(basename "$target")" "family-controls MISSING (this is what App Review rejects)"
  fi
done

# 4. The app group, which the widget and monitor read the snapshot through.
for target in "$APP" "$APP/PlugIns/MinusMonitor.appex" "$APP/PlugIns/MinusWidget.appex"; do
  if has "$target" "application-groups"; then
    note "$(basename "$target")" "app group present"
  else
    bad "$(basename "$target")" "app group MISSING"
  fi
done

# 5. The version actually baked in, since a reused build number is rejected.
plutil -p "$APP/Info.plist" 2>/dev/null | grep -iE "CFBundleShortVersionString|CFBundleVersion" | sed 's/^/  /'

echo
if [ "$FAIL" -eq 0 ]; then
  echo "OK — safe to upload."
else
  echo "NOT SAFE TO UPLOAD. Fix the failures above; uploading anyway spends a review cycle."
fi
exit "$FAIL"
