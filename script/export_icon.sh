#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_SOURCE="${1:-$ROOT_DIR/Resources/Branding/Tidal/AppIcon.icon}"
OUTPUT_DIR="${2:-$ROOT_DIR/.build/icon-assets}"

if [[ "$ICON_SOURCE" != /* ]]; then ICON_SOURCE="$PWD/$ICON_SOURCE"; fi
if [[ "$OUTPUT_DIR" != /* ]]; then OUTPUT_DIR="$PWD/$OUTPUT_DIR"; fi
if [[ ! -f "$ICON_SOURCE/icon.json" ]]; then
    echo "Icon Composer document not found: $ICON_SOURCE" >&2
    exit 1
fi

# Prefer the installed Composer, while supporting the copy bundled with Xcode.
ICON_RENDERER="${ICON_RENDERER:-/Applications/Icon Composer.app/Contents/Executables/ictool}"
if [[ ! -x "$ICON_RENDERER" ]]; then
    XCODE_DEVELOPER_DIR="$(xcode-select -p)"
    ICON_RENDERER="${XCODE_DEVELOPER_DIR%/Developer}/Applications/Icon Composer.app/Contents/Executables/ictool"
fi
if [[ ! -x "$ICON_RENDERER" ]]; then
    echo "Apple Icon Composer's ictool is required. Install Icon Composer or select a full Xcode installation." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Apple's compiler generates a layered catalog and an ICNS fallback from the
# same editable source. Keeping the deployment target at 15.0 is deliberate.
xcrun actool "$ICON_SOURCE" \
    --compile "$OUTPUT_DIR" \
    --platform macosx \
    --minimum-deployment-target 15.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$OUTPUT_DIR/icon-info.plist" \
    --output-format human-readable-text

"$ICON_RENDERER" "$ICON_SOURCE" \
    --export-image \
    --output-file "$OUTPUT_DIR/AppIcon-preview.png" \
    --platform macOS \
    --rendition Default \
    --width 1024 --height 1024 --scale 1 \
    --design-generation 27

for artifact in AppIcon.icns Assets.car icon-info.plist AppIcon-preview.png; do
    if [[ ! -s "$OUTPUT_DIR/$artifact" ]]; then
        echo "Icon export did not produce $artifact." >&2
        exit 1
    fi
done
plutil -lint "$OUTPUT_DIR/icon-info.plist"
echo "Exported layered Assets.car, macOS 15 ICNS fallback, and 1024px preview to $OUTPUT_DIR"
