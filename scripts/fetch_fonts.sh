#!/bin/bash
# Downloads every approved typeface (Fontshare, ITF Free Font License — app
# embedding permitted, public redistribution not) into Minus/Resources/Fonts.
#
# The fonts are committed while this repo is private, so this is a repair
# path: run it to restore a deleted file, or after adding a family to the
# approved list in Minus/DesignSystem/Typeface.swift. FontRegistrationTests
# fails the suite if any approved face is missing.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="Minus/Resources/Fonts"
mkdir -p "$DEST"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# slug|file-prefix. The slug is the Fontshare download path; the prefix is
# how that family names its static weights inside the zip.
FAMILIES="general-sans|GeneralSans satoshi|Satoshi switzer|Switzer cabinet-grotesk|CabinetGrotesk chillax|Chillax"

for entry in $FAMILIES; do
  slug="${entry%%|*}"
  prefix="${entry##*|}"
  echo "fetching $slug"

  curl -fsSL "https://api.fontshare.com/v2/fonts/download/$slug" -o "$TMP/$slug.zip"
  unzip -oq "$TMP/$slug.zip" -d "$TMP/$slug"

  for weight in Regular Bold; do
    # Prefer OTF; fall back to TTF for families shipping no OTF statics.
    f=$(find "$TMP/$slug" -name "$prefix-$weight.otf" | head -1)
    [ -z "$f" ] && f=$(find "$TMP/$slug" -name "$prefix-$weight.ttf" | head -1)
    if [ -z "$f" ]; then
      echo "ERROR: $prefix-$weight not found in the $slug zip. It contains:" >&2
      find "$TMP/$slug" \( -name "*.otf" -o -name "*.ttf" \) >&2
      exit 1
    fi
    cp "$f" "$DEST/"
  done
done

ls -la "$DEST"
