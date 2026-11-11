# Saved configuration sheet

## Intent

Give apps using Paperize a reusable native settings sheet. Users can adjust the paper
appearance, see changes live, and keep their configuration after restarting that app.
The user selected built-in saved settings over an editor that leaves saving to each app.

## Approach

- **Selected: library-provided persistence and editor.** Paperize owns encoding, loading,
  saving, and the native editor. Each app owns one settings instance and supplies its
  initial preset. This keeps integrations small and settings consistent.
- **Alternative: binding-only editor.** More flexible for custom persistence, but every
  app would have to implement storage and restoration. Not selected.

## Public API and ownership

- Add a main-actor observable `PaperizeSettings` with a mutable `configuration`.
- Its initializer accepts `defaultConfiguration` (default `.default`), `UserDefaults`
  (default `.standard`), and a storage key (default `Paperize.configuration`).
- The app creates one instance and shares it between its root and its settings sheet.
- Add `PaperizeSettingsView(settings:)`, usable in SwiftUI or a UIKit hosting controller.
- Add `.paperizeSettingsSheet(isPresented:settings:)` as a SwiftUI presentation shortcut.
- Keep existing enable/disable and configuration APIs. Apps keep control of their
  existing Paper mode toggle; opening or editing the sheet does not enable the effect.

Example:

```swift
@State private var paperize = PaperizeSettings(defaultConfiguration: .ereader)
@State private var showsPaperSettings = false

ContentView()
    .paperizeApp(paperMode, configuration: paperize.configuration)
    .paperizeSettingsSheet(isPresented: $showsPaperSettings, settings: paperize)
```

## Sheet behavior

Use a native navigation sheet and Form with:

- Presets: Default, E-reader, Newsprint, Unlit, Tinted; show Custom after individual edits.
- Appearance: paper and ink color pickers, dimming and grain sliders, grayscale, and
  preferred light appearance.
- Ghosting: refresh mode, ghosting toggle/intensity, speed, longer-fade interval, and
  respect accessibility settings. Controls disable when their option is inactive.
- A small preview, Reset to the app's initial configuration, and Done to dismiss.

Changes apply and save immediately. Done and swipe dismissal both retain edits.
When Paper mode is off, the editor remains usable and the preview reflects changes.
Flashing remains removed. The editor temporarily exempts its hosting window so its
controls remain readable; its preview displays edits. Temporary exemptions must not
overwrite the host's window policy. If app-wide output would be nearly uniform and hide
all content, retain the saved values but leave the app in its original appearance until
readable edits restore the effect. Explain this fallback in the editor.

## Persistence

Persist a versioned configuration payload in the supplied defaults domain. The default
domain is app-specific, so different apps do not share settings. Encode colors as explicit
RGBA components resolved in light appearance; persist all refresh options as well.
Unknown, malformed, non-finite, or unsupported saved values fall back safely to the app's
initial configuration. Normalize editable numeric values before applying or saving.
Reset restores and persists that initial configuration. Do not persist runtime window,
playback, or snapshot state.

## Integrations

- Replace the demo's custom configuration controls with the reusable sheet.
- Add a Configure button beside SquidNote's existing Paper mode setting. Share a settings
  instance initialized with `.ereader` with the app root, replacing its hard-coded preset.
- Keep SquidNote's transparent HUD window excluded from Paperize.
- Route sheet presentation through SquidNote's existing settings action boundary so its
  cross-platform SettingsFeature does not acquire an iOS-only Paperize dependency.

## Verification

Test persistence round trips including colors and refresh options, app/storage-key
isolation, corrupt data fallback, numeric normalization, reset, and live configuration
propagation. Build the library and demo, inspect the sheet in the simulator, and verify
SquidNote can open it, change a setting, dismiss, and restore it after relaunch.
