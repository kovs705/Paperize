import UIKit

/// Shared appearance math for the sample and the last-resort readability check.
struct PaperizeAppearance {
    let configuration: PaperizeConfiguration

    /// Nearly uniform output would hide all app controls. Keep the saved values, but
    /// leave windows undecorated until the user chooses a readable configuration.
    var preservesVisibility: Bool {
        guard let dark = RGBAColor(color(.black)), let light = RGBAColor(color(.white)) else { return false }
        return max(abs(light.red - dark.red), abs(light.green - dark.green), abs(light.blue - dark.blue)) >= 0.05
    }

    func color(_ color: UIColor, sourceAppearance: UIUserInterfaceStyle = .light) -> UIColor {
        guard var source = RGBAColor(color, appearance: sourceAppearance),
              let ink = RGBAColor(configuration.inkColor),
              let paper = RGBAColor(configuration.paperColor) else { return color }
        if configuration.isGrayscale {
            let luminance = source.red * 0.2126 + source.green * 0.7152 + source.blue * 0.0722
            source.red = luminance
            source.green = luminance
            source.blue = luminance
        }
        func channel(_ value: CGFloat, inkValue: CGFloat, paperValue: CGFloat) -> CGFloat {
            let lifted = value + (max(value, inkValue) - value) * ink.alpha
            return lifted * (1 - paper.alpha + paperValue * paper.alpha) * (1 - configuration.dimming)
        }
        return UIColor(
            red: channel(source.red, inkValue: ink.red, paperValue: paper.red),
            green: channel(source.green, inkValue: ink.green, paperValue: paper.green),
            blue: channel(source.blue, inkValue: ink.blue, paperValue: paper.blue),
            alpha: source.alpha
        )
    }
}
