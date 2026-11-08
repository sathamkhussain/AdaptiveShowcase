import XCTest
import SwiftUI
import AdaptiveShowcase

// Swift Package's hostless iOS runner has no window scene to drive modal transitions.
// Drive appearance explicitly here; real system presentation also needs app-hosted validation.
private final class PresentationTestTabController: UITabBarController {
    private var presentation: UIViewController?

    override var presentedViewController: UIViewController? { presentation }

    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        presentation = controller
        controller.loadViewIfNeeded()
        controller.view.frame = view.bounds
        view.window?.addSubview(controller.view)
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        completion?()
    }

    override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        let controller = presentation
        controller?.beginAppearanceTransition(false, animated: false)
        controller?.view.removeFromSuperview()
        controller?.endAppearanceTransition()
        presentation = nil
        completion?()
    }
}

private struct NativeTabGuideScreen: View {
    @State private var showingGuide = true

    var body: some View {
        Color.white
            .showcase(isPresented: $showingGuide, steps: [
                ShowcaseStep(tabIndex: 1, title: "Projects", message: "Your projects live here.")
            ])
    }
}

final class AdaptiveShowcaseTests: XCTestCase {
    @MainActor func testSwiftUINativeTabStepUsesActualFrameWithoutSelectingTab() async {
        let tabController = PresentationTestTabController()
        let home = UIHostingController(rootView: NativeTabGuideScreen())
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        let projects = UIViewController()
        projects.tabBarItem = UITabBarItem(title: "Projects", image: UIImage(systemName: "folder"), tag: 1)
        tabController.viewControllers = [home, projects]
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 844))
        window.rootViewController = tabController
        window.isHidden = false
        defer {
            tabController.dismiss(animated: false)
            window.isHidden = true
        }
        func findOverlay(in view: UIView) -> ShowcaseOverlayView? {
            if let overlay = view as? ShowcaseOverlayView { return overlay }
            return view.subviews.lazy.compactMap { findOverlay(in: $0) }.first
        }
        for _ in 0..<100 {
            tabController.view.layoutIfNeeded()
            home.view.layoutIfNeeded()
            if findOverlay(in: window) != nil { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard let overlay = findOverlay(in: window),
              let target = ShowcaseOverlayView.tabItemRect(in: tabController.tabBar, at: 1,
                                                          convertedTo: overlay) else {
            XCTFail("Native SwiftUI tab step did not resolve")
            return
        }
        defer { overlay.dismiss(.cancelled) }
        overlay.layoutIfNeeded()
        let shade = overlay.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first
        XCTAssertEqual(shade?.path?.contains(CGPoint(x: target.midX, y: target.midY), using: .evenOdd), false)
        let radius = max(target.width, target.height) / 2 + 20
        let outsideHighlight = CGPoint(x: target.midX, y: target.midY - radius >= 0
                                       ? target.midY - radius : target.midY + radius)
        XCTAssertEqual(shade?.path?.contains(outsideHighlight, using: .evenOdd), true)
        XCTAssertEqual(tabController.selectedIndex, 0)
        XCTAssertNotNil(tabController.presentedViewController)
        XCTAssertEqual(tabController.viewControllers?.count, 2)
    }

    @MainActor func testShortAdsDescriptionFitsWithoutScrollingAfterFoldResize() async {
        await checkShortAdsDescription(direction: .leftToRight)
        await checkShortAdsDescription(direction: .rightToLeft)
    }

    @MainActor private func checkShortAdsDescription(direction: LayoutDirection) async {
        let parent = UIViewController()
        parent.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        window.rootViewController = parent
        window.isHidden = false
        defer { window.isHidden = true }
        func scrollViews(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        let overlay = ShowcaseOverlayView(
            configuration: .init(title: direction == .rightToLeft ? "الإعلانات والعروض" : "Ads and promos",
                                 message: direction == .rightToLeft
                                     ? "تابع هذه المساحة، سنعرض لك هنا العروض المميزة."
                                     : "Always watch this space, we'll show you the sweet stuff here.",
                                 titleFont: .systemFont(ofSize: 20), messageFont: .systemFont(ofSize: 14),
                                 nextTitle: "Done", step: 7, totalSteps: 7, layoutDirection: direction),
            targetRect: { view in
                CGRect(x: 0, y: 135, width: view.bounds.width - 84, height: 258)
            }, completion: { _ in }
        )
        overlay.show(in: parent.view, parent: parent)
        defer { overlay.dismiss(.cancelled) }
        for size in [CGSize(width: 951, height: 669), CGSize(width: 466, height: 678)] {
            window.frame.size = size
            parent.view.frame = window.bounds
            for _ in 0..<20 {
                parent.view.layoutIfNeeded()
                overlay.setNeedsLayout()
                overlay.layoutIfNeeded()
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            let scroll = scrollViews(in: overlay).first
            XCTAssertNotNil(scroll)
            if let scroll = scroll {
                XCTAssertLessThanOrEqual(scroll.contentSize.height, scroll.bounds.height + 1)
            }
        }
    }

    @MainActor func testConstrainedPanelKeepsFullTextInScrollableContent() async {
        let parent = UIViewController()
        parent.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 900, height: 678))
        window.rootViewController = parent
        window.isHidden = false
        defer { window.isHidden = true }
        func scrollViews(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let message = direction == .rightToLeft
                ? String(repeating: "اطّلع على العروض الترويجية والإعلانات المتاحة لك. ", count: 30)
                : String(repeating: "Always watch this space for offers and promotions. ", count: 30)
            let overlay = ShowcaseOverlayView(
                configuration: .init(title: "Ads and promos", message: message,
                                     layoutDirection: direction),
                targetRect: { _ in CGRect(x: 0, y: 140, width: 800, height: 250) },
                completion: { _ in }
            )
            overlay.show(in: parent.view, parent: parent)
            for _ in 0..<20 {
                parent.view.layoutIfNeeded()
                overlay.layoutIfNeeded()
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            let scroll = scrollViews(in: overlay).first
            XCTAssertNotNil(scroll)
            if let scroll = scroll {
                XCTAssertGreaterThan(scroll.bounds.height, 0)
                XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
                XCTAssertGreaterThan(scroll.contentSize.height, 300)
            }
            if #available(iOS 16.4, *) {
                for child in parent.children {
                    if let hosting = child as? UIHostingController<AnyView> {
                        XCTAssertTrue(hosting.safeAreaRegions.isEmpty)
                    }
                }
            }
            overlay.dismiss(.cancelled)
        }
    }

    @MainActor func testExternalDismissalCancelsOnceAndReleasesPresentation() async {
        let tabs = PresentationTestTabController()
        tabs.viewControllers = [UIViewController()]
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try? await Task.sleep(nanoseconds: 100_000_000)
        var dismissals: [ShowcaseOverlayView.Dismissal] = []
        var overlay: ShowcaseOverlayView? = ShowcaseOverlayView(
            configuration: .init(title: "Guide", message: "Details."),
            targetRect: { _ in CGRect(x: 100, y: 100, width: 60, height: 60) },
            completion: { dismissals.append($0) }
        )
        weak var releasedOverlay = overlay
        overlay?.show(in: tabs.view, parent: tabs)
        for _ in 0..<100 {
            if overlay?.superview != nil { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard overlay?.superview != nil else {
            XCTFail("Showcase presentation did not finish")
            overlay?.dismiss(.cancelled)
            return
        }
        weak var releasedHost = tabs.presentedViewController
        XCTAssertNotNil(releasedHost)
        let dismissed = expectation(description: "External presentation dismissal completes")
        tabs.dismiss(animated: false) { dismissed.fulfill() }
        await fulfillment(of: [dismissed], timeout: 5)
        XCTAssertEqual(dismissals, [.cancelled])
        XCTAssertNil(overlay?.superview)
        XCTAssertTrue(releasedHost?.children.isEmpty ?? true)
        overlay?.dismiss(.cancelled)
        XCTAssertEqual(dismissals, [.cancelled])
        overlay = nil
        for _ in 0..<100 {
            if releasedHost == nil && releasedOverlay == nil { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNil(releasedHost)
        XCTAssertNil(releasedOverlay)
    }

    @MainActor func testPresentationDoesNotAddTabOrNavigationEntries() async {
        let content = UIViewController()
        let navigation = UINavigationController(rootViewController: content)
        let tabs = PresentationTestTabController()
        let other = UIViewController()
        tabs.viewControllers = [navigation, other]
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 678, height: 466))
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try? await Task.sleep(nanoseconds: 100_000_000)
        tabs.view.layoutIfNeeded()
        let originalChildren = tabs.children
        let originalItems = tabs.tabBar.items ?? []
        let overlay = ShowcaseOverlayView(
            configuration: .init(title: "Parking", message: "Choose a category."),
            targetRect: { _ in CGRect(x: 200, y: 40, width: 200, height: 80) },
            completion: { _ in }
        )
        overlay.show(in: tabs.view, parent: tabs)
        for _ in 0..<100 {
            if overlay.superview != nil { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(tabs.children, originalChildren)
        XCTAssertEqual(tabs.tabBar.items ?? [], originalItems)
        XCTAssertEqual(navigation.viewControllers, [content])
        XCTAssertTrue(content.children.isEmpty)
        let presentation = tabs.presentedViewController
        XCTAssertNotNil(presentation)
        XCTAssertTrue(overlay.ownsPresentation(presentation))
        XCTAssertEqual(presentation?.children.count, 2)
        XCTAssertTrue(overlay.superview === presentation?.view)
        let dismissed = expectation(description: "Owned presentation dismissal completes")
        tabs.dismiss(animated: false) { dismissed.fulfill() }
        await fulfillment(of: [dismissed], timeout: 5)
        for _ in 0..<100 {
            if tabs.presentedViewController == nil { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNil(tabs.presentedViewController)
        XCTAssertTrue(presentation?.children.isEmpty == true)
        XCTAssertTrue(content.children.isEmpty)
        XCTAssertEqual(tabs.children, originalChildren)
    }

    @MainActor func testPublicOverlayTracksTargetAndCleansUpOnCancellation() {
        let parent = UIViewController()
        parent.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let target = UIView(frame: CGRect(x: 100, y: 100, width: 60, height: 60))
        parent.view.addSubview(target)
        var dismissals: [ShowcaseOverlayView.Dismissal] = []
        var resolvedRect: CGRect?
        let overlay = ShowcaseOverlayView(
            configuration: .init(title: "Details", message: "View more information.",
                                 layoutDirection: .rightToLeft),
            targetRect: { view in
                let rect = target.convert(target.bounds, to: view)
                resolvedRect = rect
                return rect
            },
            completion: { dismissals.append($0) }
        )
        overlay.show(in: parent.view, parent: parent)
        for width: CGFloat in [390, 678] {
            parent.view.frame.size.width = width
            target.frame.origin.x = width - 100
            parent.view.layoutIfNeeded()
            overlay.setNeedsLayout()
            overlay.layoutIfNeeded()
            XCTAssertEqual(resolvedRect, target.frame)
            XCTAssertEqual(overlay.bounds.width, width)
        }
        overlay.dismiss(.cancelled)
        overlay.dismiss(.skipped)
        XCTAssertEqual(dismissals, [.cancelled])
        XCTAssertNil(overlay.superview)
        XCTAssertTrue(parent.children.isEmpty)
    }

    @MainActor func testPublicTabResolverRejectsUnavailableItems() {
        let tabBar = UITabBar()
        XCTAssertNil(ShowcaseOverlayView.tabItemRect(in: tabBar, at: 0, convertedTo: UIView()))
    }
}

private struct PublicShowcaseExample: View {
    @State private var isPresented = false

    var body: some View {
        Button("Show details") { isPresented = true }
            .showcaseTarget("details")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .showcase(isPresented: $isPresented, steps: [
                ShowcaseStep(target: "details", title: "Details",
                             message: "View more information.", nextTitle: "Done")
            ])
    }
}
