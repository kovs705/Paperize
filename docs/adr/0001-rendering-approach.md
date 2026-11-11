# ADR-0001: How Paperize renders the "paper" look

**Status:** Accepted, updated 2026-11-11
**Date:** 2026-11-10
**Deciders:** Paperize maintainers

## Context

Paperize should make any iOS app look like it's on an e-ink display (Kindle, reMarkable,
Daylight-style screens) with one switch:

1. **Dimmed paper**: white turns into an off-white paper tone, and the screen loses some
   brightness.
2. **Grayscale**: no color at all.
3. **Gentle refresh**: screen changes may fade a snapshot of the previous screen.

Constraints:

- It has to work for **UIKit and SwiftUI** apps, and apps that mix the two, **without
  changing how they draw their views**. A host app should only have to call `Paperize.enable()`.
- It must not break touches, accessibility, text selection, or scrolling performance.
- Only public or widely used iOS APIs. No private frameworks.
- The app's own windows (alerts, sheets, and modals are inside them) should be covered.
  The status bar, the system keyboard, and other out-of-process UI can't be reached from
  inside an app, so they're out of scope.

## Decision

**Put a non-interactive overlay view on top of every app window. The overlay is a stack of
Core Animation *compositing filters* (blend modes) that recolor whatever is drawn below it
in the window.** A SwiftUI-native variant uses the matching SwiftUI modifiers
(`grayscale`, `blendMode`) for single views and previews.

The overlay stack, bottom to top:

| Layer | Blend mode | Effect |
|---|---|---|
| Grayscale | `saturationBlendMode`, black fill | removes all chroma and keeps luminance |
| Ink | `lightenBlendMode`, ink-gray fill | lifts pure black to "ink" gray (e-ink contrast is low) |
| Paper | `multiplyBlendMode`, paper-color fill | white becomes paper and everything else is tinted to match |
| Dim | normal, black at `dimming` alpha | unlit e-reader brightness |
| Grain | `multiplyBlendMode`, tiled noise | paper texture |
| Ghost | normal (low alpha) | snapshot of the previous screen, for e-ink ghosting. It was captured *with* the overlay, so it sits above the stack to avoid being processed twice |

The overlay uses `CATransformLayer` as its backing layer so its children blend with the
window content instead of being flattened into an opaque surface.

The overlay has a very large `layer.zPosition`, so it renders above every sibling subview,
including modal presentation containers added later. That way we don't have to swizzle
`addSubview` or re-order views. `hitTest` returns `nil` and the overlay is hidden from
accessibility.

**E-ink refresh** is a small, pure *waveform* model (a list of timed steps) played back by
the overlay. Refreshes come from an explicit API (`Paperize.refresh()`), a SwiftUI
`.paperizeRefresh(on:)` modifier, or, if the app opts in to automatic mode, from
`viewWillAppear`/`viewDidAppear` swizzling. `viewWillAppear` takes a cheap
`snapshotView(afterScreenUpdates: false)` of the outgoing screen to use as the ghost.
Every Nth refresh uses a longer ghost fade. No refresh replaces, inverts, or darkens the
current screen. Reduce Motion disables ghost animation when accessibility settings are respected.

## Options considered

### Option A: Compositing-filter overlay (chosen)
| Dimension | Assessment |
|---|---|
| Complexity | Low to medium: a few views, no rendering pipeline |
| Cost (runtime) | GPU blending on the render server; no CPU readback; scrolling stays at 60/120 fps |
| Coverage | All app windows, UIKit and SwiftUI, video, maps, and web views alike |
| Integration | One call, no changes to app views |

**Pros:** works with any content, including content we don't own (WKWebView, AVPlayer,
MapKit). Real-time and cheap. Touches pass straight through.
**Cons:** `compositingFilter` blend strings aren't formally documented for iOS. They are
widely used and back SwiftUI's own `blendMode`, but behavior could change. Out-of-process UI
(keyboard, status bar) isn't affected.

### Option B: Capture and re-render (snapshot → Core Image → display)
| Dimension | Assessment |
|---|---|
| Complexity | High: frame capture loop, CIContext, a display-link-driven mirror view |
| Cost (runtime) | `drawHierarchy`/`render(in:)` every frame is CPU-heavy; drops frames and drains battery |
| Coverage | Misses video, Metal, and secure content; mirrors lag behind input |

**Pros:** complete control over the image (real dithering and quantization are possible).
**Cons:** too slow for a live UI and it adds input latency. Rejected.

### Option C: SwiftUI modifiers only (`.grayscale`, `.colorMultiply`, `.blendMode`)
| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Coverage | Only the SwiftUI subtree the modifier wraps; no UIKit, no sheets or alerts presented elsewhere |

**Pros:** public, documented API; works in Xcode Previews.
**Cons:** not app-wide. **Kept as a complementary API** (`.paperize()`) for previews and
for scoping the effect to one screen.

### Option D: Core Animation `filters` / `backgroundFilters` with CIFilters
**Cons:** `CALayer.filters`/`backgroundFilters` are ignored on iOS. Not viable.

## Trade-off analysis

Only Option A gives app-wide coverage at native frame rates. Its risk is reliance on blend
filter names that aren't formally documented. We mitigate that by:
- keeping each effect in its own layer so a single failing filter degrades gracefully
  (for example, it becomes a flat tint instead of breaking the app);
- giving Option C as a fully public-API fallback for SwiftUI;
- isolating filter names in one place (`BlendMode`) so they're easy to change.

Swizzling `viewWillAppear`/`viewDidAppear` is opinionated, so it only happens when the
host app picks `RefreshConfiguration.Mode.automatic`. Manual and SwiftUI triggers need no
swizzling.

## Consequences

- **Easier:** one-line adoption; works on existing apps, including third-party SDK screens.
- **Easier:** the waveform model is pure and unit-testable without a device.
- **Harder:** we can't paperize the keyboard or status bar. This is documented as a limitation.
- **Simpler:** all refreshes are ghost fades. There is no brightness-pulse or inversion path,
  including when accessibility preferences are opted out of.
- **Revisit:** if a future iOS stops honoring blend filter strings, move to the
  `SwiftUI.Layer`/Metal shader route for SwiftUI, and to per-window `CAMetalLayer`
  post-processing for UIKit.

## Action items
1. [x] `PaperOverlayView` with the blend-layer stack
2. [x] Window tracking across scenes (`UIWindow.didBecomeVisibleNotification`)
3. [x] Waveform model + overlay playback, partial/full scheduling
4. [x] Opt-in automatic refresh via view-controller appearance hooks
5. [x] SwiftUI `.paperize()` and `.paperizeRefresh(on:)`
6. [ ] Verify on device across iOS 17 through the latest release; record any blend-mode differences
7. [ ] Explore ordered dithering (Metal `layerEffect`, iOS 17+) as an optional "16-level gray" mode
