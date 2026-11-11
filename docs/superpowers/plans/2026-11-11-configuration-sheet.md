# Saved Configuration Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Ship the approved reusable editor with per-app saved configuration and integrate it in the demo and SquidNote.

**Architecture:** A main-actor observable settings object persists a versioned, normalized value through UserDefaults. A native SwiftUI sheet edits that object; existing root modifiers observe its configuration. SquidNote routes presentation through its settings action boundary.

**Tech Stack:** Swift 5.9+, iOS 17+, SwiftUI, Observation, Foundation, UIKit; no new dependencies.

**Spec:** docs/superpowers/specs/2026-11-11-configuration-sheet-design.md

## Global Constraints

- Opening/editing does not enable Paper mode. Existing enable/disable APIs remain compatible.
- Changes apply and save immediately; Done and swipe retain them. Reset restores the app's initial configuration.
- Persist all configuration including resolved light-appearance RGBA colors and refresh options.
- Flashing remains removed. Transparent HUD windows stay excluded.
- Preserve existing unrelated SquidNote working-tree changes. Deliver changes locally without pushing.

## Review Focus

- Invalid saved schema, unknown refresh mode, and malformed color components restore the initial configuration.
- NaN/infinite or out-of-range inputs never reach the rendering/playback pipeline.
- Separate defaults suites and storage keys remain independent.
- Preset selection, manual edits, and reset remain consistent after restoration.
- Opening/dismissing and disabling Paper mode never discard edits or turn the effect on.

### Task 1: Saved configuration

**Files:** Create Sources/Paperize/PaperizeSettings.swift, Sources/Paperize/Internal/SavedPaperizeConfiguration.swift, Tests/PaperizeTests/SettingsTests.swift.

**Interfaces:** Produce `@MainActor @Observable public final class PaperizeSettings` with `init(defaultConfiguration: PaperizeConfiguration = .default, defaults: UserDefaults = .standard, storageKey: String = "Paperize.configuration")`, mutable `configuration`, read-only `defaultConfiguration`, and `reset()`.

- [x] Write round-trip, per-suite/key isolation, reset, corrupt-schema, unknown-mode, invalid-color and normalization tests using real UserDefaults suites.
- [x] Run simulator tests and observe failure for missing settings type.
- [x] Implement versioned private Codable storage and normalized observable updates; bound dimming/grain/ghost alpha to 0...1, speed to 0.1...5, refresh interval to 0...100. Invalid finite values clamp; non-finite values use initial values.
- [x] Run full library tests in the existing temporary application-hosted harness, expecting all pass and no rendering skip.

### Task 2: Reusable editor

**Files:** Create Sources/Paperize/PaperizePreset.swift, Sources/Paperize/SwiftUI/PaperizeSettingsView.swift, Sources/Paperize/SwiftUI/PaperizeSettingsPreview.swift; modify View+Paperize.swift, demo app/settings, README; test SettingsTests.swift/AppModifierTests.swift.

**Interfaces:** Consume Task 1 settings. Produce `PaperizeSettingsView(settings:)` and `.paperizeSettingsSheet(isPresented: Binding<Bool>, settings: PaperizeSettings)`. Preset matching compares normalized colors/numeric values, exposing Custom after edits.

- [x] Add tests for persisted settings driving a hosted root, preset selection/custom detection/reset, and editor rendering without enabling Paperize.
- [x] Run the new tests and observe missing editor/preset behavior.
- [x] Implement native Form controls, preview, Done and Reset; use original color chips with deterministic preview rendering so scoped compositing cannot hide the sample.
- [x] Replace demo custom configuration controls with the editor and shared settings; document SwiftUI and UIKit embedding.
- [x] Run full tests and lint. Build/run demo, inspect native sheet and live changes, dismiss and restore settings.

### Task 3: SquidNote integration

**Files:** Modify SquidNoteApp.swift, SettingsView.swift, SettingsView+Integration.swift, SettingsPresentationModifier.swift, SettingsSheet.swift, SettingsView+Preview.swift; SettingsFeature Models/SettingsAction.swift, SettingsScreen.swift, Screens/SettingsAppearanceScreen.swift; local dependency wiring if necessary to build against unpublished library changes.

**Interfaces:** Add `.paperize` SettingsAction/SettingsSheet. Root owns one PaperizeSettings(defaultConfiguration: .ereader), injected through environment. SettingsPresentationModifier presents PaperizeSettingsView for that shared instance. Keep existing AppStorage paperMode toggle.

- [x] Add Configure action in appearance card and wire native sheet presentation through existing routing.
- [x] Pass saved configuration into existing root .paperizeApp modifier; provide preview environment without writing standard defaults.
- [x] Use a reversible local package reference to verify unpublished code; document it for the user.
- [x] Build/run SquidNote and verify opening, live editing, Done, swipe dismissal and restore after relaunch; retain transparent HUD exclusion.
- [x] Run relevant settings package checks where supported, lint changed Swift files, and inspect final diffs.

### Completion

- [x] Request one independent review of the full feature and integrations; address significant findings with regression tests.
- [x] Confirm full library suite, visual verification, persistence across restart, lint and clean diff formatting.
- [x] Report changed APIs, integrations, validation and any remaining dependency publication requirement.

## Verification record

- Hosted simulator suite: 43 passed, 0 failed, 0 skipped.
- Demo and SquidNote built and ran on iPhone 18 Pro, iOS 27.2.
- Native preset/custom editing, manual interval, reset, Done, swipe dismissal and saved restoration verified.
- Independent review findings addressed with regressions; library lint and diff checks clean.
- SquidNote uses a relative local Paperize dependency until the new API is published.
- Editor temporarily exempts its window; unreadable saved output preserves the original app appearance until fixed.
- Existing unrelated SquidNote changes and app warnings preserved. Focused local commits created at the user's request; no pushes.
