import SwiftUI

struct ActionModeBadge: View {
    let isDryRun: Bool

    var body: some View {
        Label(isDryRun ? "DRY RUN" : "LIVE ACTIONS", systemImage: isDryRun ? "shield.lefthalf.filled" : "bolt.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(isDryRun ? Color.blue : Color.orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background((isDryRun ? Color.blue : Color.orange).opacity(0.12), in: Capsule())
            .overlay {
                Capsule().strokeBorder((isDryRun ? Color.blue : Color.orange).opacity(0.25))
            }
            .accessibilityLabel(
                isDryRun ? "Dry run active. Live actions inactive." : "Live actions active. Dry run inactive.")
    }
}

struct ActionModeBanner: View {
    let isDryRun: Bool
    var showsSettingsLink = true

    var body: some View {
        HStack(spacing: 12) {
            ActionModeBadge(isDryRun: isDryRun)
            VStack(alignment: .leading, spacing: 2) {
                Text(isDryRun ? "Live actions inactive" : "Live actions active · Dry run inactive")
                    .font(.system(size: 12, weight: .semibold))
                Text(
                    isDryRun ? "Downloads are planned; no requests are sent." : "Downloads can be requested from macOS."
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if showsSettingsLink {
                SettingsLink {
                    Label("Action settings", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
                .help("Choose dry run or live actions")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isDryRun ? Color.blue : Color.orange).opacity(0.07))
        .overlay(alignment: .bottom) { Divider() }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }
}
