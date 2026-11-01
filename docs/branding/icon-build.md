# Building the Tidal app icon

The editable source is `Resources/Branding/Tidal/AppIcon.icon`, authored and reviewed in Apple Icon Composer. The foreground is the selected original Tidal mark; the document keeps its material, scale, shadow, and background settings editable.

Run from the project root on a Mac with full Xcode and Icon Composer installed:

```sh
./script/export_icon.sh
```

The script uses Apple's installed `actool` and Icon Composer's documented `ictool --export-image` command. It generates these files under `.build/icon-assets/`:

| File | Purpose |
|---|---|
| `Assets.car` | Compiled layered app icon and appearance data |
| `AppIcon.icns` | Conventional app icon fallback compiled for macOS 15.0 |
| `icon-info.plist` | Generated bundle metadata |
| `AppIcon-preview.png` | 1024 × 1024 default-appearance reference render |

For an alternate source or output directory:

```sh
./script/export_icon.sh path/to/AppIcon.icon .build/icon-test/output
```

The app bundle must contain `Assets.car` and `AppIcon.icns` in `Contents/Resources/`. Apply the generated `CFBundleIconFile` and `CFBundleIconName` values from `icon-info.plist` to the app's `Contents/Info.plist`; both are `AppIcon` for this source. These resource files must be staged before app signing.

The compiler is explicitly passed `--platform macosx --minimum-deployment-target 15.0`. A modern SDK compiles the layered catalog while generating the older icon representation from the same source. This does not establish runtime appearance on every supported macOS version; macOS 15, 26, and 27 visual acceptance remains a separate platform check.

The development tool sandbox in this task could not open Icon Composer documents for rendering. Running the same Apple tools outside that tool sandbox succeeded. This is a tool execution limitation, not an instruction to weaken the app's App Sandbox.
