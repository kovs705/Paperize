import Paperize
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: PaperSettings

    var body: some View {
        Form {
            Section {
                Toggle("Paper mode", isOn: $settings.isOn)
            }

            Section("Look") {
                Picker("Preset", selection: $settings.preset) {
                    ForEach(PaperSettings.Preset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Dimming \(Int(settings.dimming * 100))%")
                    Slider(value: $settings.dimming, in: 0...0.8)
                }
                VStack(alignment: .leading) {
                    Text("Grain \(Int(settings.grain * 100))%")
                    Slider(value: $settings.grain, in: 0...1)
                }
            }

            Section {
                Picker("Refresh", selection: $settings.refreshMode) {
                    Text("Off").tag(RefreshConfiguration.Mode.off)
                    Text("Manual").tag(RefreshConfiguration.Mode.manual)
                    Text("Automatic").tag(RefreshConfiguration.Mode.automatic)
                }
                Button("Refresh") { Paperize.refresh(.full) }
            } header: {
                Text("E-ink refresh")
            } footer: {
                Text("Automatic mode gently fades the previous screen whenever a screen appears. Reduce Motion disables these animations.")
            }

            Section("Preview (scoped, SwiftUI-only)") {
                // `.paperize()` affects only this view. It works even while app-wide mode is off.
                HStack {
                    ForEach([Color.red, .green, .blue, .orange], id: \.self) { color in
                        RoundedRectangle(cornerRadius: 8).fill(color).frame(height: 44)
                    }
                }
                .paperize(configuration: .newsprint)
            }
        }
        .navigationTitle("Paper")
    }
}
