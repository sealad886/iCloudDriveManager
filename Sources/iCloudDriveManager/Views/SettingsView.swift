import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: DriveViewModel

    var body: some View {
        VStack(spacing: 0) {
            ActionModeBanner(isDryRun: model.isDryRun, showsSettingsLink: false)
            Form {
                Section {
                    Toggle(
                        "Dry run",
                        isOn: Binding(
                            get: { model.isDryRun },
                            set: { model.setDryRun($0) }
                        )
                    )
                    .toggleStyle(.switch)
                    Text(
                        "Dry run reads your real folder metadata and records what an action would do. Download requests are not sent to macOS."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    Text("Dry run is active at every launch. Turn it off here to enable live actions for this session.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Action mode")
                }

                Section {
                    Toggle("Ask each time", isOn: $model.askEachTime)
                    Text(
                        "Before a live action, show a Yes / No confirmation. You can also change this preference using the Ask each time checkbox in that confirmation."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Live action confirmation")
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 0, maxHeight: .infinity)
        }
        .tint(BrandTheme.accent)
        .frame(width: 540, height: 400)
    }
}
