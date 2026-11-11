import Paperize
import SwiftUI

struct SettingsView: View {
    @Environment(PaperizeSettings.self) private var settings
    @AppStorage("paperize.isEnabled") private var isEnabled = true
    @State private var showsSettings = false

    var body: some View {
        Form {
            Section {
                Toggle("Paper mode", isOn: $isEnabled)
                    .accessibilityIdentifier("demo-paper-mode")
            }
            Section("Appearance") {
                LabeledContent("Current look", value: PaperizePreset.matching(settings.configuration)?.title ?? "Custom")
                Button("Configure Paperize") { showsSettings = true }
                    .accessibilityIdentifier("demo-configure-paperize")
            }
            Section {
                Button("Refresh") { Paperize.refresh(.full) }
                    .disabled(!isEnabled || settings.configuration.refresh.mode == .off)
            } footer: {
                Text("The reusable editor saves this app's appearance automatically. Refreshes only fade previous content.")
            }
        }
        .navigationTitle("Paper")
        .paperizeSettingsSheet(isPresented: $showsSettings, settings: settings)
    }
}
