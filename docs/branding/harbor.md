# Harbor

Status: **proposed; awaiting generated-board review and user selection**.

## Identity

A geometric sheltering arch combines a folder-like opening with a soft cloud cue. The mark should feel like an organized place for files, with one open aperture and a stable base. Keep it clearly original: do not trace Apple's cloud or use the familiar iCloud outline as a container.

The wordmark remains **iCloud Drive Manager**, set in the native system typeface at semibold weight. A candidate supporting line is “A clearer place for your files.” The direction is warm and reassuring, while the interface continues to state uncertainty and report errors plainly.

## Palette

| Token | Color | Use |
|---|---|---|
| Primary | `#28594B` | Mark, primary button fill, accent details |
| Mint | `#B5DBC7` | Dark-appearance mark and secondary brand accent |
| Cream | `#F5F2E9` | Brand-board field and restrained onboarding tint |
| Dark ink | `#162822` | Wordmark and dark brand background |

Calculated sRGB contrast: white on primary **8.01:1**; primary on cream **7.16:1**; dark ink on cream **13.79:1**; mint on dark ink **10.23:1**. Mint is not small text on cream. Actual native surfaces and translucent materials still need appearance testing.

## Logo rules

- Clear space: at least one quarter of the mark height on every side.
- Minimum mark: 16 pixels in a simplified solid silhouette; 24 pixels for the complete aperture detail.
- Primary lockup: 200 pixels wide or larger. Narrow app headers use a two-line wordmark or a mark with an accessible full product label.
- Light version: forest mark and dark-ink wordmark on cream or a suitable native light surface.
- Dark version: mint mark with native primary text. Do not reuse cream as an opaque app-wide background in dark appearance.
- Never add a lock or shield to imply encryption, backup guarantees, or file safety the utility does not provide.

## Native application

Use a 28-point mark in the sidebar and 64–88 points in onboarding. The cream tone belongs in brand boards and restrained accents; the working app keeps standard native materials. Forest is the primary-action accent, while sync errors and warnings retain semantic system colors.

Use system typography: 26–28-point semibold headers, 13–15-point body copy, and 11–12-point supporting labels. Slightly rounded headline treatment may be explored in onboarding, but controls and data tables keep the standard system design.

## Icon Composer direction

Use a forest background with an independent mint or light sheltering arch. Place the aperture on its own shape layer only if it remains a clean opening in all appearances; avoid a deep scene or a tiny folder illustration. Let Icon Composer add restrained depth. The dark appearance uses dark ink and mint; the tinted appearance relies on the open arch and stable base.

Reduce the small-size export to one bold silhouette with an unmistakable opening. The menu-bar variant is monochrome and uses template rendering. Preserve the editable `.icon` document, source layers, and a macOS 15-compatible `.icns` fallback.
