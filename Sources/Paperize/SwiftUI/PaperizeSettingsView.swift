import SwiftUI

/// A reusable editor with immediate, per-app saving. Present it in a sheet or a hosting controller.
/// The editor temporarily exempts its window from the effect so its controls stay readable.
@MainActor
public struct PaperizeSettingsView: View {
    @Bindable private var settings: PaperizeSettings
    @Environment(\.dismiss) private var dismiss

    public init(settings: PaperizeSettings) {
        self.settings = settings
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    PaperizeSettingsPreview(configuration: settings.configuration)
                        .listRowInsets(EdgeInsets())
                }
                if !PaperizeAppearance(configuration: settings.configuration).preservesVisibility {
                    Section {
                        Label("This configuration hides content. The app keeps its original appearance until you adjust it or reset.",
                              systemImage: "eye.slash")
                            .accessibilityIdentifier("paperize-visibility-recovery")
                    }
                }
                presetSection
                appearanceSection
                ghostingSection
                Section {
                    Button("Reset to App Default", role: .destructive) { settings.reset() }
                        .accessibilityIdentifier("paperize-reset")
                } footer: {
                    Text("Changes are saved automatically for this app. The preview shows your paper appearance.")
                }
            }
            .navigationTitle("Paper Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("paperize-done")
                }
            }
        }
        .background(PaperizeEditorWindow().allowsHitTesting(false))
    }

    private var presetSection: some View {
        Section("Preset") {
            Picker("Preset", selection: presetBinding) {
                if PaperizePreset.matching(settings.configuration) == nil {
                    Text("Custom").tag(nil as PaperizePreset?)
                }
                ForEach(PaperizePreset.allCases) { preset in
                    Text(preset.title).tag(Optional(preset))
                }
            }
            .accessibilityIdentifier("paperize-preset")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            ColorPicker("Paper color", selection: colorBinding(\.paperColor), supportsOpacity: true)
                .accessibilityIdentifier("paperize-paper-color")
            ColorPicker("Ink color", selection: colorBinding(\.inkColor), supportsOpacity: true)
                .accessibilityIdentifier("paperize-ink-color")
            percentageSlider("Dimming", value: $settings.configuration.dimming, identifier: "paperize-dimming")
            percentageSlider("Grain", value: $settings.configuration.grain, identifier: "paperize-grain")
            Toggle("Grayscale", isOn: $settings.configuration.isGrayscale)
                .accessibilityIdentifier("paperize-grayscale")
            Toggle("Prefer light appearance", isOn: $settings.configuration.prefersLightAppearance)
        }
    }

    private var ghostingSection: some View {
        Section {
            Picker("Refresh", selection: $settings.configuration.refresh.mode) {
                Text("Off").tag(RefreshConfiguration.Mode.off)
                Text("Manual").tag(RefreshConfiguration.Mode.manual)
                Text("Automatic").tag(RefreshConfiguration.Mode.automatic)
            }
            .accessibilityIdentifier("paperize-refresh-mode")
            Group {
                Toggle("Ghosting", isOn: $settings.configuration.refresh.showsGhosting)
                Group {
                    percentageSlider("Ghost intensity", value: $settings.configuration.refresh.ghostingIntensity,
                                     identifier: "paperize-ghost-intensity")
                    VStack(alignment: .leading) {
                        LabeledContent("Fade speed", value: settings.configuration.refresh.speed,
                                       format: .number.precision(.fractionLength(1)))
                        Slider(value: $settings.configuration.refresh.speed, in: 0.1...5, step: 0.1)
                            .accessibilityLabel("Fade speed")
                            .accessibilityIdentifier("paperize-speed")
                    }
                    Stepper(value: $settings.configuration.refresh.fullRefreshInterval, in: 0...100) {
                        LabeledContent("Longer fade every", value: settings.configuration.refresh.fullRefreshInterval == 0
                                       ? "Never" : "\(settings.configuration.refresh.fullRefreshInterval) refreshes")
                    }
                }
                .disabled(!settings.configuration.refresh.showsGhosting)
                Toggle("Respect Reduce Motion", isOn: $settings.configuration.refresh.respectsAccessibilitySettings)
            }
            .disabled(settings.configuration.refresh.mode == .off)
        } header: {
            Text("Ghosting")
        } footer: {
            Text("Refreshes gently fade the previous screen. No flashing or screen inversion.")
        }
    }

    private var presetBinding: Binding<PaperizePreset?> {
        Binding(
            get: { PaperizePreset.matching(settings.configuration) },
            set: { if let preset = $0 { settings.configuration = preset.configuration } }
        )
    }

    private func colorBinding(_ keyPath: WritableKeyPath<PaperizeConfiguration, UIColor>) -> Binding<Color> {
        Binding(
            get: { Color(uiColor: settings.configuration[keyPath: keyPath]) },
            set: { settings.configuration[keyPath: keyPath] = UIColor($0) }
        )
    }

    private func percentageSlider(_ title: LocalizedStringKey, value: Binding<CGFloat>, identifier: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(Double(value.wrappedValue), format: .percent.precision(.fractionLength(0)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...1, step: 0.01)
                .accessibilityLabel(title)
                .accessibilityValue(Text(Double(value.wrappedValue), format: .percent))
                .accessibilityIdentifier(identifier)
        }
    }
}
