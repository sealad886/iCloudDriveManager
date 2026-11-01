import DriveCore
import SwiftUI

struct SystemActivityView: View {
    let snapshot: SystemActivitySnapshot?
    let isReading: Bool
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("System iCloud activity", systemImage: "icloud")
                    .font(.system(size: 13, weight: .semibold))
                Text("Whole account")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                Spacer()
                if isReading { ProgressView().controlSize(.mini) }
                if let observedAt = snapshot?.observedAt {
                    Text(observedAt, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if let snapshot {
                HStack(spacing: 30) {
                    activity(
                        title: "Waiting to upload", count: snapshot.pendingUploadCount,
                        bytes: snapshot.pendingUploadBytes, symbol: "arrow.up.circle", tint: .orange
                    )
                    activity(
                        title: "Downloading records", count: snapshot.downloadingCount,
                        bytes: snapshot.downloadingBytes, symbol: "arrow.down.circle", tint: .blue
                    )
                    Spacer(minLength: 0)
                }
            } else {
                Text(isReading ? "Reading Apple's local iCloud status…" : "System activity unavailable")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                if snapshot != nil {
                    Text("Showing the last successful observation. Current totals are unavailable.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Text(
                "Read-only Apple diagnostics across iCloud containers, including outside the selected folder. Record sizes are logical file sizes, not bytes remaining. Transfer speed and queue order are unavailable."
            )
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(BrandTheme.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(BrandTheme.accent.opacity(0.15)) }
        .accessibilityElement(children: .contain)
    }

    private func activity(title: String, count: Int?, bytes: Int64?, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(count.map { $0.formatted() } ?? "Unavailable")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                if let bytes {
                    Text(DriveFormatting.bytes(bytes))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
