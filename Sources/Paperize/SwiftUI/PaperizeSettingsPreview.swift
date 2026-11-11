import SwiftUI

/// Explicitly renders a small sample, so previewing settings never changes the app's enabled state.
struct PaperizeSettingsPreview: View {
    let configuration: PaperizeConfiguration
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { !configuration.prefersLightAppearance && colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.plaintext")
                Text("A moment on paper").font(.headline)
            }
            Text("Keep the things worth remembering.")
                .font(.subheadline)
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(previewColor([.systemRed, .systemGreen, .systemBlue, .systemOrange][index]))
                        .frame(height: 24)
                }
            }
        }
        .foregroundStyle(previewColor(isDark ? .white : .black))
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(previewColor(isDark ? .black : .white))
        .overlay {
            Image(uiImage: GrainTexture.image)
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(configuration.grain)
                .allowsHitTesting(false)
        }
        .compositingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paper appearance preview")
    }

    private func previewColor(_ color: UIColor) -> Color {
        Color(uiColor: PaperizeAppearance(configuration: configuration).color(
            color, sourceAppearance: isDark ? .dark : .light
        ))
    }
}
