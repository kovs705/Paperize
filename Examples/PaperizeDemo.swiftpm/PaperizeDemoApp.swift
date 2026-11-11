import Paperize
import SwiftUI

@main
struct PaperizeDemoApp: App {
    @State private var settings = PaperizeSettings()
    @AppStorage("paperize.isEnabled") private var isEnabled = true

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .paperizeApp(isEnabled, configuration: settings.configuration)
        }
    }
}
