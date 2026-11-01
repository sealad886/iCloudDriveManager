import AppKit
import SwiftUI

enum BrandTheme {
    static let productName = "iCloud Drive Manager"
    static let tagline = "Clarity in every transfer."

    /// Tidal teal remains distinct on light surfaces; mint stays legible on dark materials.
    static let accent = Color(
        nsColor: NSColor(name: NSColor.Name("TidalAccent")) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(srgbRed: 125 / 255, green: 229 / 255, blue: 209 / 255, alpha: 1)
            }
            return NSColor(srgbRed: 8 / 255, green: 127 / 255, blue: 140 / 255, alpha: 1)
        })

    /// The darker teal is reserved for readable identity text on light surfaces.
    static let textAccent = Color(
        nsColor: NSColor(name: NSColor.Name("TidalTextAccent")) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(srgbRed: 200 / 255, green: 243 / 255, blue: 238 / 255, alpha: 1)
            }
            return NSColor(srgbRed: 6 / 255, green: 108 / 255, blue: 119 / 255, alpha: 1)
        })

    /// Load the packaged PNG directly: name-based SwiftUI lookup can omit loose bundle images.
    static let nativeMark: NSImage = {
        #if SWIFT_PACKAGE
            let resources = Bundle.module
        #else
            let resources = Bundle.main
        #endif
        guard let url = resources.url(forResource: "TidalMark", withExtension: "png") else {
            preconditionFailure("The app bundle is missing its required TidalMark.png resource.")
        }
        guard let image = NSImage(contentsOf: url), image.isValid else {
            preconditionFailure("The app bundle's required TidalMark.png resource could not be decoded.")
        }
        image.isTemplate = true
        return image
    }()

    static var markImage: Image { Image(nsImage: nativeMark) }
}

struct BrandMark: View {
    var size: CGFloat = 36

    var body: some View {
        BrandTheme.markImage
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(BrandTheme.accent)
            .accessibilityHidden(true)
    }
}
