#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="iCloudDriveManager"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
MODE="run"
UNIVERSAL=0
for argument in "$@"; do
    case "$argument" in
        --build-only) MODE="build" ;;
        --verify) MODE="verify" ;;
        --universal) UNIVERSAL=1 ;;
        --debug) MODE="debug" ;;
        --logs) MODE="logs" ;;
        --telemetry) MODE="telemetry" ;;
        *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry] [--universal]" >&2; exit 2 ;;
    esac
done

BUILD_ARGS=(
    -project "$ROOT_DIR/iCloudDriveManager.xcodeproj"
    -scheme iCloudDriveManager
    -configuration Debug
    -destination 'platform=macOS'
    -derivedDataPath "$ROOT_DIR/.build/Xcode"
    -clonedSourcePackagesDirPath "$ROOT_DIR/.build/SourcePackages"
)
if [[ "$UNIVERSAL" == 1 ]]; then
    BUILD_ARGS+=("ARCHS=arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
fi
xcodebuild "${BUILD_ARGS[@]}" build
BUILD_APP="$ROOT_DIR/.build/Xcode/Build/Products/Debug/$APP_NAME.app"

# Stop only a process launched from this project's generated bundle before relaunching it.
if [[ "$MODE" != "build" ]]; then
    while IFS= read -r process_id; do
        [[ -z "$process_id" ]] && continue
        process_path="$(ps -p "$process_id" -o comm=)"
        if [[ "$process_path" == "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]]; then
            kill "$process_id"
        fi
    done < <(pgrep -x "$APP_NAME" || true)
fi

# Stage the complete Xcode product, preserving its Debug signing and debugger entitlement.
# The previous generated bundle is retained in the staging directory for recovery.
STAGING_DIR="$(mktemp -d "$ROOT_DIR/.build/app-staging.XXXXXX")"
ditto "$BUILD_APP" "$STAGING_DIR/$APP_NAME.app"
mkdir -p "$ROOT_DIR/dist"
if [[ -e "$APP_BUNDLE" ]]; then
    mv "$APP_BUNDLE" "$STAGING_DIR/previous.app"
fi
mv "$STAGING_DIR/$APP_NAME.app" "$APP_BUNDLE"
STATUS_SERVICE="$APP_BUNDLE/Contents/XPCServices/ICloudStatusService.xpc"
if [[ ! -x "$STATUS_SERVICE/Contents/MacOS/ICloudStatusService" ]]; then
    echo "The native build is missing its read-only iCloud status service." >&2
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
echo "Built $APP_BUNDLE"
if [[ "$MODE" == "build" ]]; then exit 0; fi

if [[ "$MODE" == "debug" ]]; then
    exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
    verify)
        for attempt in 1 2 3 4 5; do
            while IFS= read -r process_id; do
                [[ -z "$process_id" ]] && continue
                process_path="$(ps -p "$process_id" -o comm=)"
                if [[ "$process_path" == "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]]; then
                    echo "Launch verified: $APP_BUNDLE is running."
                    exit 0
                fi
            done < <(pgrep -x "$APP_NAME" || true)
            sleep 1
        done
        echo "App process was not found after launch." >&2
        exit 1
        ;;
    logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "iCloudDriveManager"' ;;
    telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.local.iCloudDriveManager"' ;;
esac
