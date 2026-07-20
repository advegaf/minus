#!/bin/bash
# Downloads General Sans (Fontshare, ITF Free Font License — app embedding
# permitted, public redistribution not) into Minus/Resources/Fonts.
# Run once after clone; FontRegistrationTests fails the suite if fonts are missing.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="Minus/Resources/Fonts"
mkdir -p "$DEST"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "https://api.fontshare.com/v2/fonts/download/general-sans" -o "$TMP/gs.zip"
unzip -oq "$TMP/gs.zip" -d "$TMP/gs"

for weight in Regular Bold; do
  f=$(find "$TMP/gs" -name "GeneralSans-$weight.otf" | head -1)
  if [ -z "$f" ]; then
    echo "ERROR: GeneralSans-$weight.otf not found in Fontshare zip. Contents:" >&2
    find "$TMP/gs" -name "*.otf" -o -name "*.ttf" >&2
    exit 1
  fi
  cp "$f" "$DEST/"
done

ls -la "$DEST"
