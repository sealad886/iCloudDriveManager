#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
bash -n script/build_and_run.sh script/check.sh script/export_icon.sh
plutil -lint Resources/Info.plist Resources/App.entitlements Resources/CompiledIcon/icon-info.plist \
    Sources/ICloudStatusService/Info.plist Sources/ICloudStatusService/Service.entitlements
plutil -lint iCloudDriveManager.xcodeproj/project.pbxproj
swift format lint --strict --recursive Sources Tests Package.swift
xcodebuild \
    -project "$ROOT_DIR/iCloudDriveManager.xcodeproj" \
    -scheme iCloudDriveManager \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$ROOT_DIR/.build/Xcode" \
    -clonedSourcePackagesDirPath "$ROOT_DIR/.build/SourcePackages" \
    -parallel-testing-enabled NO \
    test
