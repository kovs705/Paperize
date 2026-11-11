# Paperize

**Make any iOS app look like it's on an e-ink display, with one line of code.**

Paperize puts a touch-transparent layer over your app that turns it into paper:

- **Grayscale**: every color is removed. Luminance is kept, so hierarchy still reads.
- **Dimmed paper**: whites become an off-white paper tone, blacks lift to soft "ink", and
  you can add dimming and paper grain.
- **E-ink refresh**: page changes play e-paper waveforms. Partial refreshes leave a fading
  ghost of the previous screen, and every few refreshes a full *invert → black → paper*
  flash clears it.

It works for **UIKit, SwiftUI, and mixed apps**, including sheets, alerts, web views, maps, and
video, without touching your views.

```swift
import Paperize

Paperize.enable()
```

## Requirements

- iOS 15+
- Swift 5.9+ / Xcode 15+

## Installation

Swift Package Manager: in Xcode, choose **File ▸ Add Package Dependencies…** and enter the
repository URL. Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/kovs705/Paperize.git", branch: "main")
```

## Quick start

### UIKit

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    // ... set up your window ...
    Paperize.enable()               // or Paperize.enable(.newsprint)
}
```

### SwiftUI app

```swift
@main
struct MyApp: App {
    @AppStorage("paperMode") private var paperMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .paperizeApp(paperMode, configuration: .ereader)
        }
    }
}
```

`paperizeApp` keeps the **app-wide** effect in sync with a value, so it covers UIKit screens,
sheets, and alerts too.

## Presets

| Preset | Look |
|---|---|
| `.default` | Soft gray paper, slightly lifted blacks, a little grain |
| `.ereader` | Bright, crisp, slightly warm paper, like a front-lit e-reader |
| `.newsprint` | Warm, grainy, low-contrast newsprint |
| `.unlit` | Dim panel with no front light. Nice at night |
| `.tintedPaper` | Keeps colors but puts them on textured paper. No refresh effects |

## Configuration

Every property can be changed live:

```swift
var config = PaperizeConfiguration.newsprint
config.dimming = 0.25                       // 0...1 extra darkness
config.grain = 0.3                          // 0...1 paper texture
config.paperColor = UIColor(white: 0.92, alpha: 1)
config.inkColor = UIColor(white: 0.15, alpha: 1)
config.isGrayscale = true
config.prefersLightAppearance = true        // forces light mode while enabled (e-paper is reflective)
Paperize.enable(config)

Paperize.configuration.dimming = 0.4        // later: applies immediately
Paperize.disable()                          // restores everything, including the windows' interface style
```

### E-ink refresh

```swift
config.refresh = RefreshConfiguration(
    mode: .automatic,          // .off, .manual, or .automatic
    fullRefreshInterval: 6,    // every 6th automatic refresh is a full flash (0 = never)
    showsGhosting: true,
    ghostingIntensity: 0.22,
    speed: 1,
    respectsAccessibilitySettings: true
)
```

| Mode | What triggers a refresh |
|---|---|
| `.off` | Nothing. Changes appear instantly, like an LCD |
| `.manual` | Your calls to `Paperize.refresh(_:)` / `performWithRefresh`, and `.paperizeRefresh(on:)` |
| `.automatic` | All of the above, plus every view controller appearance (push, pop, present, tab switch) |

`.automatic` hooks `UIViewController.viewWillAppear(_:)`/`viewDidAppear(_:)`. Paperize only installs
the hooks when you opt in to this mode.

Trigger a refresh yourself:

```swift
Paperize.refresh(.full)          // invert → black → paper flash
Paperize.refresh(.partial)       // subtle update
Paperize.refresh()               // .automatic: partial, with full every N times

// Snapshot the screen first so the old content ghosts out:
Paperize.performWithRefresh {
    reader.page += 1
}
```

In SwiftUI, refresh when a value changes:

```swift
PageView(page: page)
    .paperizeRefresh(on: page)
```

> **Accessibility:** a full refresh is a black/white flash. With `respectsAccessibilitySettings`
> on (the default), Paperize replaces flashes with a gentle ghost fade when **Reduce Motion** or
> **Dim Flashing Lights** is enabled. Please keep this on.

### Scoped effect and Xcode Previews

`.paperize()` applies the look to a single SwiftUI view with pure SwiftUI modifiers, so it works
in Previews:

```swift
#Preview {
    ContentView()
        .paperize(configuration: .newsprint)
}
```

### Excluding a window

```swift
debugWindow.isPaperizeExcluded = true   // stays in full color
```

## Demo app

`Examples/PaperizeDemo.swiftpm` is a small habit-journal app with a settings tab for presets,
dimming, grain, and refresh modes. Open it in Xcode and run it on a simulator or device.
It refers to this repository by its folder name, so keep the clone in a folder named `Paperize`.

## How it works

Each app window gets a `PaperOverlayView` at the very top (by `zPosition`, so modals added later
stay below it). It ignores touches and accessibility. It's a stack of Core Animation compositing
filters, and each one blends with everything drawn beneath it:

```
flash      difference / solid   refresh waveform
ghost      normal, low α        previous screen (already paperized), fading
grain      multiply             paper texture
dim        normal, black α      front light off
paper      multiply             white → paper tone
ink        lighten              black → soft ink
grayscale  saturation           remove chroma
──────────────────────────────  your app
```

Everything is composited on the GPU. Paperize doesn't capture frames per screen update or read
pixels back to the CPU, so scrolling stays at full frame rate. The full reasoning and the
rejected alternatives are in [ADR-0001](docs/adr/0001-rendering-approach.md).

## Limitations

- **The keyboard and status bar stay in color.** iOS draws them outside your app's process.
- The effect is visual only. Screenshots and screen recordings show it, but accessibility
  APIs still report the original colors.
- Blend-mode compositing filters (`multiplyBlendMode`, etc.) aren't formally documented for
  iOS, although SwiftUI's own `blendMode` relies on them. If a future iOS changes them, the
  effect degrades to a flat tint and your app keeps working.
- UIKit's private helper windows (text effects, remote keyboard) are skipped on purpose.

## Development

```bash
xcodebuild test -scheme Paperize -destination 'platform=iOS Simulator,name=iPhone 16'
```

Unit tests cover the refresh waveform model, full/partial scheduling, configuration clamping, the
overlay's blend stack, and window attach/detach.
