# Branding review kit

Status: **Tidal selected; icon source and exports complete; final app visual/runtime checks in progress**. Prepared 31 October 2026.

The product name remains **iCloud Drive Manager**. Tidal, Signal, and Harbor name visual directions, not replacement product names. The application is an independent macOS utility whose purpose is to make reported synchronization state understandable and let people request local copies of their files.

## Foundation

- **Purpose:** give people a clear, honest view of their selected iCloud Drive folder.
- **Promise:** show what macOS reports, preserve user control, and state uncertainty plainly.
- **Values:** clarity, discretion, and care for the user's files.
- **Personality:** calm, precise, useful. Avoid alarmist dashboards and implied control over Apple's global queue.
- **Audience:** Mac users who need to understand pending transfers, local availability, conflicts, and errors without technical diagnostics.

## Proposed directions

| Direction | Identity | Core palette | Guidance |
|---|---|---|---|
| [Tidal](tidal.md) | Two curved lanes form a continuous, balanced mark | Deep teal, ice, ink | Fluid and calm |
| [Signal](signal.md) | A folded file meets a diagonal synchronization path | Cobalt, periwinkle, graphite | Precise and focused |
| [Harbor](harbor.md) | A sheltered arch combines cloud and folder cues | Forest, mint, cream | Warm and reassuring |

Three independent review boards were generated. The user selected the first displayed board, Tidal. These boards are concept evidence, not final production logos or completed Icon Composer documents. Asset filenames record the saved concepts; future review-option numbers must still follow the images' actual displayed order.

- [Selected Tidal board](../../Resources/Branding/Concepts/01-tidal-board.png)
- [Signal board](../../Resources/Branding/Concepts/02-signal-board.png)
- [Harbor board](../../Resources/Branding/Concepts/03-harbor-board.png)

The Tidal board's product-screen illustration includes controls and figures such as “Sync Now” and storage totals. They are illustrative design content and do not authorize or define app functionality. The implemented app must retain its real metadata coverage, bounded download requests, and honest scheduling limits.

## Shared implementation rules

1. Preserve native macOS sidebars, materials, focus indicators, table density, and semantic colors. Palette swatches are not instructions to repaint the whole window.
2. Apply the selected mark to onboarding and the sidebar. Use the selected accent for primary actions. Keep warning, error, selection, and disabled states semantically distinct.
3. Keep the exact product wordmark. The full name may wrap over two lines in narrow native surfaces; do not compress or distort letterforms to fit.
4. Use the system font through SwiftUI and AppKit. Do not bundle a separate copy of SF Pro. Data values use monospaced digits, not a separate display font.
5. Use a single-color template silhouette for the menu bar. Glass, color, shading, and text belong in larger app-icon presentations.
6. Build the selected app icon in Apple Icon Composer, with separate background and foreground elements. Inspect all appearances and export a macOS 15-compatible `.icns` fallback as well as preserving the editable source.
7. Do not use Apple's logo or copy the iCloud glyph as the brand mark. Describe iCloud functionality accurately and retain independent-app identification in About/help.

## Deliverables and acceptance

[tokens.json](tokens.json) records the selected direction and the shared identity rules. [asset-manifest.json](asset-manifest.json) records actual artifacts and their individual verification status.

After selection, the production kit must include:

- Primary mark and light/dark or monochrome variants with transparent backgrounds.
- Wordmark lockup and a separate mark-only asset.
- Original editable artwork and an editable Icon Composer document.
- App icon exports and a fallback that works on macOS 15.
- A native template menu-bar mark.
- App screenshots showing the selected identity in onboarding, sidebar, and Dock.

The primary transparent artwork is [TidalMark.png](../../Resources/Branding/Tidal/TidalMark.png), verified as a 1254×1254 PNG with an alpha channel. The native sidebar/onboarding lockups use the system font, and the native monochrome/template treatment reuses that mark's silhouette rather than a separate approximation. The editable [AppIcon.icon](../../Resources/Branding/Tidal/AppIcon.icon) document contains the imported foreground and independently editable background/material settings.

The selected icon was constructed in Apple Icon Composer and inspected in its Default, Dark, and Mono appearances. Apple's toolchain generated [AppIcon.icns](../../Resources/CompiledIcon/AppIcon.icns), [Assets.car](../../Resources/CompiledIcon/Assets.car), and a [1024px preview](../../Resources/CompiledIcon/AppIcon-preview.png) from the same source. `icon-info.plist` supplies `CFBundleIconFile` and `CFBundleIconName`, both `AppIcon`.

Regenerate after editing the source with a full Xcode 27 toolchain and Apple Icon Composer:

```sh
./script/export_icon.sh Resources/Branding/Tidal/AppIcon.icon Resources/CompiledIcon
```

Normal builds copy the precompiled icon resources and SwiftPM resource bundle into the app before signing. They do not require Icon Composer to be installed. Final app screenshots, compiled-bundle launch, and appearance limits are recorded in the [Product Design audit](../product-design-audit.md) and [verification matrix](../verification.md).

Validate mark legibility at 16, 32, 64, 128, 256, 512, and 1024 pixels. Inspect light, dark, tinted, increased-contrast, and reduced-transparency appearances where supported. Small-icon variants may simplify fine detail while preserving the same recognizable silhouette. Do not claim completed appearance or accessibility validation before inspecting the rendered results.

## Voice and consistency

Use direct, bounded language: “Request download,” “Submitted to macOS,” and “No reported issues.” Avoid “Force sync,” “All files safe,” or “Fully synchronized” when metadata cannot support those statements. The brand must reinforce accurate state communication.

Keep one selected token set and one canonical asset family. Before distribution, compare the final mark against the concept the user selected, check originality and independent-app presentation, and audit screenshots for stale logos, palette drift, stretched assets, or claims that overstate synchronization control. This is a design review process, not a legal clearance or certification.
