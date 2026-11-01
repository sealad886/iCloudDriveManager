import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var model: DriveViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 18) {
                    BrandMark(size: 78)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(BrandTheme.productName)
                            .font(.system(size: 23, weight: .semibold, design: .rounded))
                            .foregroundStyle(BrandTheme.textAccent)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(BrandTheme.tagline)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 28)

                Text("Your files,\nin focus.")
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                Text("See what’s syncing, what’s waiting, and what needs your attention in iCloud Drive.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 410, alignment: .leading)
                    .padding(.bottom, 28)

                Button(action: model.chooseFolder) {
                    Label("Choose iCloud Drive folder", systemImage: "folder.badge.plus")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("choose-folder")

                VStack(alignment: .leading, spacing: 16) {
                    welcomeFeature(
                        "Folder sync states", symbol: "arrow.triangle.2.circlepath",
                        text: "View the sync metadata reported by macOS.")
                    welcomeFeature(
                        "Plan before acting", symbol: "checklist",
                        text: "Dry run records planned downloads without sending requests.")
                    welcomeFeature(
                        "Local and private", symbol: "lock", text: "No extra account, analytics, or file uploads.")
                }
                .padding(.top, 38)

                Text(
                    "Choose iCloud Drive, or a folder inside it, in the macOS folder picker. Files stay where they are."
                )
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420, alignment: .leading)
                .padding(.top, 28)
            }
            .frame(maxWidth: 540, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 50)
            .padding(.vertical, 45)
        }
    }

    private func welcomeFeature(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(BrandTheme.accent)
                .frame(width: 22, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}
