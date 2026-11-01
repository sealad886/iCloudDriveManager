# Tidal

Status: **selected by the user; production assets, Icon Composer work, and app integration in progress**.

## Identity

Two interlocking curved lanes form a compact, continuous mark. Their shared negative space suggests movement between cloud and Mac without reproducing the iCloud cloud outline. Keep the silhouette balanced, with two clear paths and enough separation to survive small sizes. The effect is fluid and composed rather than a spinning progress indicator.

The wordmark is **iCloud Drive Manager**, set in the native system typeface at semibold weight, with the rounded system design used for identity text. Pair it with the mark horizontally when space permits; use a two-line wordmark in the sidebar. The selected supporting line is “Clarity in every transfer.” The onboarding headline is “Your files, in focus.”

## Palette

| Token | Color | Use |
|---|---|---|
| Primary | `#087F8C` | Mark, primary button fill, accent details |
| Ice | `#E7F5F4` | Brand-board background and restrained onboarding tint |
| Ink | `#132B35` | Wordmark and static brand text on ice |
| Small text accent | `#066C77` | Small accent text on ice |
| Dark accent | `#7DE5D1` | Mark and primary accent on dark native appearances |
| Dark text accent | `#C8F3EE` | Identity text on dark native appearances |

Calculated sRGB contrast: white on primary **4.75:1**; ink on ice **13.17:1**; small text accent on ice **5.49:1**; selected dark accent on ink **9.83:1**; selected dark text accent on ink **12.29:1**. Primary teal on ice is only **4.24:1**, so do not use that pairing for small body text. These are solid-color pairings, not proof of the contrast of translucent native surfaces. The dark values reflect the implemented adaptive `BrandTheme`, rather than the earlier proposal.

## Logo rules

- Clear space: at least one quarter of the mark height on every side.
- Minimum mark: 16 pixels in the simplified monochrome version; 24 pixels for the two-color detail version.
- Primary lockup: 200 pixels wide or larger. At narrower widths, use a two-line wordmark or the mark alone with an accessible full product label.
- Light version: deep-teal mark and ink wordmark on an appropriate light surface.
- Dark version: pale-teal mark with the native primary text color. Do not put ink lettering on a dark native surface.
- Do not rotate lanes into a loading animation, add arrows inside their gaps, or reduce their separation below one rendered pixel.

## Native application

The implemented sidebar uses a 36-point mark frame with a 16-point two-line wordmark; onboarding uses a 78-point mark frame. Keep app surfaces native. Header 26–28 points semibold; body 13–15 points regular; supporting labels 11–12 points. Respect system accessibility settings and preserve table text legibility.

Use teal for the app's primary action identity, while errors remain system red and warnings system orange. A colored brand mark must not stand in for a sync-state indicator.

## Icon Composer direction

Use a deep-teal background with separately imported lane foreground shapes. Keep the lanes flat and original in the artwork; let Icon Composer supply material and lighting. Preserve the central negative space and inspect whether glass highlights merge the two lanes. The dark appearance uses a restrained ink background and pale-teal foreground. The tinted appearance must remain identifiable by silhouette alone.

The 16–32-pixel fallback reduces reflections and uses a single bold silhouette. The `.icns` fallback is a designed export of the selected identity; it is not a screenshot of the review board. Keep the editable `.icon` document and original layer assets together.
