# AdaptiveShowcase

An iOS spotlight tutorial library for UIKit and SwiftUI, with a dimmed background,
target highlight, connector, and content-sized popup.

Requires iOS 15+ and Swift tools 5.9+. No third-party dependencies.
Initial releases are pre-1.0; the API may change between minor versions.

## Installation

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/sathamkhussain/AdaptiveShowcase.git
```

Select version `0.1.0` or add this dependency to your package:

```swift
.package(
    url: "https://github.com/sathamkhussain/AdaptiveShowcase.git",
    from: "0.1.0"
)
```

Add `"AdaptiveShowcase"` to your target's dependencies.

## UIKit

Keep a reference to the overlay while it is being presented. Use it on the main
thread after the screen has appeared.

```swift
import UIKit
import AdaptiveShowcase

final class ExampleViewController: UIViewController {
    private let detailsButton = UIButton(type: .system)
    private var guide: ShowcaseOverlayView?

    func showGuide() {
        guard guide == nil, view.window != nil else { return }

        let overlay = ShowcaseOverlayView(
            configuration: .init(
                title: "Details",
                message: "Find more information here.",
                nextTitle: "Done",
                skipTitle: "Skip",
                highlightShape: .roundedRectangle
            ),
            targetRect: { [weak self] overlay in
                guard let button = self?.detailsButton,
                      button.window === overlay.window,
                      !button.isHidden, !button.bounds.isEmpty else {
                    return nil
                }
                return button.convert(button.bounds, to: overlay)
            },
            completion: { [weak self] reason in
                self?.guide = nil
                // Advance or save tutorial completion in your app.
            }
        )
        guide = overlay
        overlay.show(in: view, parent: self)
    }
}
```

Add and lay out `detailsButton` in your screen before calling `showGuide()`.
The target closure returns a rectangle in **overlay coordinates** and is
reevaluated during layout. Scroll off-screen targets into view before showing
their step. For a group, return the union of the views' converted bounds.

To cancel an active guide, call `guide?.dismiss(.cancelled)`. Each overlay is
single-use. Create a new one for the next step or replay.

### Tab items and system containers

Use circular tab highlights without guessing tab positions:

```swift
let configuration = ShowcaseOverlayView.Configuration(
    title: "Vehicles",
    message: "Manage your vehicles here.",
    highlightShape: .circle,
    rippleEnabled: true
)

// Use this in your overlay's targetRect closure:
ShowcaseOverlayView.tabItemRect(
    in: tabController.tabBar,
    at: 2,
    convertedTo: overlay
)
```

If you pass a tab or navigation controller as `parent`, the library presents a
transparent full-screen host above it instead of adding managed tab/navigation
entries. The presenting controller must be visible and not already presenting
another controller.

If your screen cancels its guide in `viewWillDisappear`, exclude the library's
own presentation:

```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    let presented = tabBarController?.presentedViewController
        ?? navigationController?.presentedViewController
        ?? presentedViewController
    if guide?.ownsPresentation(presented) == true { return }
    guide?.dismiss(.cancelled)
}
```

Avoid restarting a tutorial in `viewDidAppear` while an existing guide is active.

### Configuration and completion

UIKit configuration supports title/message fonts, button labels, highlight
shape/padding, optional ripple, progress (`step` is one-based), and
`layoutDirection`. Supply localized strings from your app. For Arabic UIKit
screens, pass `layoutDirection: .rightToLeft`.

The popup currently uses a fixed blue palette. The legacy `color` parameter is
retained for compatibility but does not change the modern popup palette.

Completion reasons:

| Reason | Meaning |
|---|---|
| `.next` | Next/Done or a background tap |
| `.skipped` | Skip or accessibility escape |
| `.cancelled` | Explicit cancellation or external host dismissal |
| `.unavailable` | Target cannot be resolved or system-container presentation is unavailable |

The app owns tutorial order, first-use persistence, and replay behaviour.

## SwiftUI

Mark each target with a unique ID and attach the tutorial modifier to a common
ancestor covering the screen:

```swift
import SwiftUI
import AdaptiveShowcase

struct ExampleScreen: View {
    @State private var showGuide = false

    var body: some View {
        VStack(spacing: 32) {
            Button("Details") {}
                .showcaseTarget("details")
            Button("Settings") {}
                .showcaseTarget("settings")
            Button("Show guide") { showGuide = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .showcase(isPresented: $showGuide, steps: [
            ShowcaseStep(
                target: "details",
                title: "Details",
                message: "Find more information here."
            ),
            ShowcaseStep(
                target: "settings",
                title: "Settings",
                message: "Manage your preferences.",
                nextTitle: "Done",
                highlightShape: .circle
            )
        ])
    }
}
```

Next advances the array; Done and Skip set the binding to `false`. Setting the
binding to `false` cancels presentation. SwiftUI inherits environment layout
direction; use `.environment(\.layoutDirection, .rightToLeft)` for RTL previews.

A step waits for its target to become visible. The app must scroll lazy/off-screen
targets into view. Attach the modifier inside the appropriate sheet or navigation
screen; targets do not cross presentation/window boundaries. Updating the steps
array restarts the sequence. The SwiftUI step API currently exposes text, labels
and shape, not all UIKit styling options.

## Adaptive layout and accessibility

Geometry uses container bounds and actual target positions, not physical screen
size estimates. The popup respects the host's safe area, reduces padding and gaps
when space is limited, and scrolls text when required. Dynamic Type, Reduce Motion,
and accessibility escape are supported. Extremely small placement regions may
not accommodate a usable panel; avoid targeting an entire screen-sized region.

## Testing

Open `Package.swift` in Xcode, select the AdaptiveShowcase scheme and a specific
iOS simulator, then choose **Product > Test** (`Command-U`).

From Terminal:

```bash
xcodebuild -scheme AdaptiveShowcase \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' test
```

Tests require an iOS simulator; `swift test` on macOS cannot build UIKit.
Validate custom app targets visually on compact/wide layouts and RTL as well.
The hostless package runner has no window scene: modal lifecycle unit tests drive
appearance transitions with a test presenter. They do not replace app-hosted
verification of UIKit presentation/dismissal or navigation interruptions.

## Licence

MIT. See [LICENSE](LICENSE).
