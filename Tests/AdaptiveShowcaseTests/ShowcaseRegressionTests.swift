import XCTest
import UIKit
import SwiftUI
@testable import AdaptiveShowcase

private final class ShowcaseExampleState: ObservableObject {
    @Published var isPresented = true
    @Published var showsSecondTarget = true
}

private struct ShowcaseTestScreen: View {
    @ObservedObject var state: ShowcaseExampleState

    var body: some View {
        VStack(spacing: 40) {
            Button("First") {}
                .frame(width: 100, height: 50)
                .showcaseTarget("first")
            if state.showsSecondTarget {
                Button("Second") {}
                    .frame(width: 100, height: 50)
                    .showcaseTarget("second")
            }
            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .showcase(isPresented: $state.isPresented, steps: [
            ShowcaseStep(target: "first", title: "First", message: "First target."),
            ShowcaseStep(target: "second", title: "Second", message: "Second target.", nextTitle: "Done")
        ])
    }
}

final class ShowcaseRegressionTests: XCTestCase {

    @MainActor func testSwiftUIShadeCoversSafeAreaWhilePanelStaysInsideIt() async {
        for insets in [
            UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84),
            UIEdgeInsets(top: 0, left: 84, bottom: 34, right: 0),
            UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)
        ] {
            let state = ShowcaseExampleState()
            let controller = UIHostingController(rootView: ShowcaseTestScreen(state: state))
            controller.additionalSafeAreaInsets = insets
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 844))
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true }

            func findOverlay(in view: UIView) -> ShowcaseOverlayView? {
                if let overlay = view as? ShowcaseOverlayView { return overlay }
                return view.subviews.lazy.compactMap { findOverlay(in: $0) }.first
            }
            for _ in 0..<100 {
                controller.view.layoutIfNeeded()
                if findOverlay(in: controller.view) != nil { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            guard let overlay = findOverlay(in: controller.view) else {
                XCTFail("Missing SwiftUI overlay")
                continue
            }
            overlay.layoutIfNeeded()
            XCTAssertEqual(overlay.convert(overlay.bounds, to: controller.view), controller.view.bounds)
            let shade = overlay.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first
            XCTAssertEqual(shade?.path?.boundingBoxOfPath, overlay.bounds)
            for point in [CGPoint(x: controller.view.bounds.midX, y: 3),
                          CGPoint(x: controller.view.bounds.maxX - 3, y: 400),
                          CGPoint(x: 3, y: controller.view.bounds.maxY - 10)] {
                let local = overlay.convert(point, from: controller.view)
                XCTAssertEqual(shade?.path?.contains(local, using: .evenOdd), true,
                               "Point \(local), mask \(String(describing: shade?.path))")
            }
            let panels = overlay.subviews.filter { !$0.isHidden && !$0.bounds.isEmpty && !($0 is UIButton) }
            XCTAssertFalse(panels.isEmpty)
            for panel in panels {
                XCTAssertTrue(controller.view.safeAreaLayoutGuide.layoutFrame.contains(
                    panel.convert(panel.bounds, to: controller.view)))
            }
            overlay.dismiss(.cancelled)
        }
    }

    @MainActor func testLandscapeOverflowScrollsTextAndActionsTogether() async {
        let parent = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 678, height: 466))
        window.rootViewController = parent
        window.isHidden = false
        defer { window.isHidden = true }
        let overlay = ShowcaseOverlayView(configuration: .init(
            title: "A little focus. A big difference.",
            message: "Keep your next great idea in sight. Pick up where you left off, with everything you need in one place.",
            nextTitle: "Got it"
        ), targetRect: { _ in
            CGRect(x: 0, y: 140, width: 678, height: 230)
        }, completion: { _ in })
        overlay.show(in: parent.view, parent: parent)
        defer { overlay.dismiss(.cancelled) }

        func scrollViews(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        for _ in 0..<100 {
            parent.view.layoutIfNeeded()
            overlay.layoutIfNeeded()
            if scrollViews(in: overlay).contains(where: { $0.contentSize.height > $0.bounds.height }) { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard let scroll = scrollViews(in: overlay).first else {
            XCTFail("Missing overflow scroll view")
            return
        }
        XCTAssertGreaterThan(scroll.bounds.height, 50)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        scroll.setContentOffset(CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height), animated: false)
        XCTAssertGreaterThan(scroll.contentOffset.y, 0)
    }

    @MainActor func testSwiftUIShowcaseAdvancesWaitsForTargetsAndRestarts() async {
        let state = ShowcaseExampleState()
        state.showsSecondTarget = false
        let controller = UIHostingController(rootView: ShowcaseTestScreen(state: state))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }

        func findOverlay(in view: UIView) -> ShowcaseOverlayView? {
            if let overlay = view as? ShowcaseOverlayView { return overlay }
            return view.subviews.lazy.compactMap { findOverlay(in: $0) }.first
        }
        func containsShowcaseHost(_ controller: UIViewController) -> Bool {
            controller is ShowcaseHostController || controller.children.contains { containsShowcaseHost($0) }
        }
        func waitUntil(_ phase: String, _ condition: () -> Bool) async {
            for _ in 0..<100 {
                controller.view.layoutIfNeeded()
                if condition() { return }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            XCTFail("SwiftUI showcase did not reach \(phase)")
        }

        await waitUntil("first target") { findOverlay(in: controller.view) != nil }
        let first = findOverlay(in: controller.view)
        first?.dismiss(.next)
        await waitUntil("first dismissal") { first?.superview == nil }
        XCTAssertTrue(state.isPresented)
        XCTAssertNil(findOverlay(in: controller.view))

        state.showsSecondTarget = true
        await waitUntil("second target") { findOverlay(in: controller.view) != nil }
        findOverlay(in: controller.view)?.dismiss(.next)
        await waitUntil("completion") {
            !state.isPresented && !containsShowcaseHost(controller)
        }

        state.isPresented = true
        await waitUntil("restart") { findOverlay(in: controller.view) != nil }
        findOverlay(in: controller.view)?.dismiss(.skipped)
        await waitUntil("skip") { !state.isPresented && !containsShowcaseHost(controller) }
    }

    @MainActor func testSwiftUIBridgeUpdatesTargetAndCleansUpWhenTargetDisappears() async {
        let controller = ShowcaseHostController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let step = ShowcaseStep(target: "button", title: "Button", message: "Details.")
        var completions: [ShowcaseOverlayView.Dismissal] = []
        func update(_ target: CGRect?) {
            controller.update(step: step, index: 0, total: 1, target: target,
                              layoutDirection: .rightToLeft, completion: { completions.append($0) })
            controller.view.layoutIfNeeded()
        }
        update(CGRect(x: 30, y: 80, width: 60, height: 50))
        guard let overlay = controller.view.subviews.compactMap({ $0 as? ShowcaseOverlayView }).first else {
            XCTFail("Missing SwiftUI bridge overlay")
            return
        }
        update(CGRect(x: 250, y: 100, width: 60, height: 50))
        overlay.layoutIfNeeded()
        let shade = overlay.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first
        XCTAssertEqual(shade?.path?.contains(CGPoint(x: 280, y: 125), using: .evenOdd), false)
        XCTAssertEqual(shade?.path?.contains(CGPoint(x: 60, y: 105), using: .evenOdd), true)
        update(nil)
        XCTAssertNil(overlay.superview)
        XCTAssertTrue(controller.children.isEmpty)
        XCTAssertTrue(completions.isEmpty)
        update(CGRect(x: 250, y: 100, width: 60, height: 50))
        XCTAssertFalse(controller.children.isEmpty)
        controller.view.subviews.compactMap { $0 as? ShowcaseOverlayView }.first?.dismiss(.skipped)
        controller.cancel()
        XCTAssertTrue(controller.children.isEmpty)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(completions.isEmpty)
    }

    @MainActor func testShowcaseTopRowUsesOneCutoutAfterResizeAndMirroring() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let configuration = ShowcaseOverlayView.Configuration(
            title: "Parking", message: "Choose a category.", color: .blue,
            titleFont: .systemFont(ofSize: 20), messageFont: .systemFont(ofSize: 14),
            nextTitle: "Next", skipTitle: "Skip", highlightPadding: 0
        )
        var mirrored = false
        var targets: [CGRect] = []
        let overlay = ShowcaseOverlayView(configuration: configuration, targetRect: { view in
            targets = [-100.0, 0, 100].enumerated().map { index, offset in
                let width: CGFloat = index == 1 ? 100 : 85
                let center = view.bounds.midX + CGFloat(mirrored ? -offset : offset)
                return CGRect(x: center - width / 2, y: 80, width: width, height: 90)
            }
            let buttonsRect = targets.reduce(CGRect.null) { $0.union($1) }
            let cardRect = CGRect(x: 0, y: 50, width: view.bounds.width, height: 120)
            return buttonsRect.insetBy(dx: -8, dy: -8).intersection(cardRect)
        }, completion: { _ in })
        overlay.show(in: host)
        defer { overlay.dismiss(.cancelled) }
        for size in [CGSize(width: 390, height: 844), CGSize(width: 678, height: 466)] {
            host.frame.size = size
            host.layoutIfNeeded()
            for rtl in [false, true] {
                mirrored = rtl
                overlay.setNeedsLayout()
                overlay.layoutIfNeeded()
                let shade = overlay.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first
                guard let path = shade?.path else {
                    XCTFail("Missing showcase mask")
                    return
                }
                for target in targets {
                    XCTAssertFalse(path.contains(CGPoint(x: target.midX, y: target.midY), using: .evenOdd))
                }
                let ordered = targets.sorted { $0.minX < $1.minX }
                for index in 0..<ordered.count - 1 {
                    let gap = CGPoint(x: (ordered[index].maxX + ordered[index + 1].minX) / 2, y: 125)
                    XCTAssertFalse(path.contains(gap, using: .evenOdd))
                }
                XCTAssertTrue(path.contains(CGPoint(x: overlay.bounds.midX, y: 40), using: .evenOdd))
                XCTAssertFalse(path.contains(CGPoint(x: overlay.bounds.midX, y: 169), using: .evenOdd))
                XCTAssertTrue(path.contains(CGPoint(x: overlay.bounds.midX, y: 174), using: .evenOdd))
            }
        }
    }

    @MainActor func testShowcasePanelHeightFitsContentAndCapsAtAvailableSpace() {
        let parent = UIViewController()
        parent.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        func panelHeight(message: String) -> CGFloat {
            let configuration = ShowcaseOverlayView.Configuration(
                title: "Vehicles", message: message, color: .blue,
                titleFont: .systemFont(ofSize: 20), messageFont: .systemFont(ofSize: 16),
                nextTitle: "Next", skipTitle: "Skip"
            )
            let overlay = ShowcaseOverlayView(configuration: configuration, targetRect: { _ in
                CGRect(x: 160, y: 760, width: 60, height: 60)
            }, completion: { _ in })
            overlay.show(in: parent.view, parent: parent)
            overlay.setNeedsLayout()
            overlay.layoutIfNeeded()
            let height = parent.children.first?.view.bounds.height ?? 0
            overlay.dismiss(.cancelled)
            XCTAssertTrue(parent.children.isEmpty)
            return height
        }
        let short = panelHeight(message: "Manage your vehicles.")
        let long = panelHeight(message: String(repeating: "Manage your vehicles and parking details. ", count: 10))
        let overflowing = panelHeight(message: String(repeating: "تفاصيل المركبات والمواقف. ", count: 100))
        XCTAssertGreaterThan(short, 0)
        XCTAssertLessThan(short, 340)
        XCTAssertGreaterThan(long, short)
        XCTAssertLessThanOrEqual(overflowing, 720)
    }

    func testShowcasePanelFollowsTabsAndStaysInsidePlacementRegion() {
        let region = CGRect(x: 16, y: 16, width: 900, height: 700)
        let size = CGSize(width: 360, height: 340)
        let left = ShowcaseOverlayView.panelFrame(
            in: region, size: size, following: CGRect(x: 200, y: 750, width: 60, height: 60))
        let right = ShowcaseOverlayView.panelFrame(
            in: region, size: size, following: CGRect(x: 700, y: 750, width: 60, height: 60))
        XCTAssertLessThan(left.midX, right.midX)
        for target in [CGRect(x: 940, y: 100, width: 60, height: 60),
                       CGRect(x: -60, y: 550, width: 60, height: 60)] {
            let frame = ShowcaseOverlayView.panelFrame(in: region, size: size, following: target)
            XCTAssertTrue(region.contains(frame))
        }
        let top = ShowcaseOverlayView.panelFrame(
            in: region, size: size, following: CGRect(x: 940, y: 100, width: 60, height: 60))
        let bottom = ShowcaseOverlayView.panelFrame(
            in: region, size: size, following: CGRect(x: 940, y: 550, width: 60, height: 60))
        XCTAssertLessThan(top.midY, bottom.midY)
    }

    @MainActor func testBottomTabPopupLeavesConnectorGapAboveCircularSpotlight() {
        let safeRect = CGRect(x: 16, y: 16, width: 434, height: 628)
        let circle = UIBezierPath(ovalIn: CGRect(x: 193, y: 584, width: 80, height: 80))
        let region = ShowcaseOverlayView.contentRegion(in: safeRect, avoiding: circle.bounds, regularWidth: false)
        let panel = CGRect(x: region.midX - 180, y: region.maxY - 340, width: 360, height: 340)
        XCTAssertGreaterThanOrEqual(circle.bounds.minY - panel.maxY, 16)
        XCTAssertNotNil(ShowcaseOverlayView.connectorPath(from: panel, to: circle))
    }

    @MainActor func testShowcaseConnectorMeetsSpotlightForBothRailsAndBottomBar() {
        let panel = CGRect(x: 100, y: 100, width: 240, height: 240)
        for rect in [CGRect(x: 380, y: 300, width: 60, height: 60),
                     CGRect(x: 0, y: 300, width: 60, height: 60),
                     CGRect(x: 190, y: 400, width: 60, height: 60)] {
            let spotlight = UIBezierPath(ovalIn: rect)
            let path = ShowcaseOverlayView.connectorPath(from: panel, to: spotlight)
            XCTAssertNotNil(path)
            if let end = path?.currentPoint {
                XCTAssertEqual(hypot(end.x - rect.midX, end.y - rect.midY), 30, accuracy: 0.1)
            }
        }
        XCTAssertNil(ShowcaseOverlayView.connectorPath(
            from: panel, to: UIBezierPath(ovalIn: CGRect(x: 150, y: 150, width: 60, height: 60))
        ))
    }

    func testShowcaseCircleEnclosesContentWithoutUsingUnionCorners() {
        let center = CGPoint(x: 350, y: 750)
        let text = CGRect(x: 40, y: 490, width: 300, height: 180)
        let target = CGRect(x: 320, y: 720, width: 60, height: 60)
        let radius = ShowcaseOverlayView.enclosingRadius(center: center, rectangles: [text, target])
        XCTAssertEqual(radius, hypot(310, 260), accuracy: 0.01)
        let mirrored = ShowcaseOverlayView.enclosingRadius(
            center: CGPoint(x: 40, y: 750),
            rectangles: [CGRect(x: 50, y: 490, width: 300, height: 180),
                         CGRect(x: 10, y: 720, width: 60, height: 60)]
        )
        XCTAssertEqual(radius, mirrored, accuracy: 0.01)
    }

    @MainActor func testShowcaseContentAvoidsTargetAndBothSafeAreaRails() {
        for safeRect in [
            CGRect(x: 0, y: 0, width: 382, height: 686),
            CGRect(x: 84, y: 0, width: 382, height: 686),
            CGRect(x: 0, y: 47, width: 390, height: 763)
        ] {
            let target = CGRect(x: safeRect.midX - 30, y: safeRect.maxY - 50,
                                width: 60, height: 50)
            let region = ShowcaseOverlayView.contentRegion(in: safeRect, avoiding: target, regularWidth: false)
            XCTAssertTrue(safeRect.contains(region))
            XCTAssertFalse(region.intersects(target))
            XCTAssertGreaterThan(region.height, 100)
        }
        let safeRect = CGRect(x: 16, y: 16, width: 900, height: 320)
        let sidebarTarget = CGRect(x: 820, y: 16, width: 80, height: 320)
        let region = ShowcaseOverlayView.contentRegion(in: safeRect, avoiding: sidebarTarget, regularWidth: true)
        XCTAssertTrue(safeRect.contains(region))
        XCTAssertFalse(region.intersects(sidebarTarget))
        XCTAssertGreaterThan(region.width, 480)
    }

    @MainActor func testShowcaseRecomputesSpotlightAfterContainerAndTargetResize() async {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let target = UIView(frame: CGRect(x: 100, y: 740, width: 50, height: 50))
        host.addSubview(target)
        let configuration = ShowcaseOverlayView.Configuration(
            title: "Title", message: "Message", color: .blue,
            titleFont: .systemFont(ofSize: 20), messageFont: .systemFont(ofSize: 14),
            nextTitle: "Next", skipTitle: "Skip"
        )
        var resolvedRects: [CGRect] = []
        var dismissals: [ShowcaseOverlayView.Dismissal] = []
        let dismissed = expectation(description: "Next finishes its transition")
        let overlay = ShowcaseOverlayView(configuration: configuration, targetRect: { view in
            let rect = target.convert(target.bounds, to: view)
            resolvedRects.append(rect)
            return rect
        }, completion: {
            dismissals.append($0)
            dismissed.fulfill()
        })
        overlay.show(in: host)
        for size in [CGSize(width: 700, height: 400), CGSize(width: 390, height: 844)] {
            host.frame.size = size
            target.frame.origin = CGPoint(x: size.width - 80, y: size.height - 80)
            host.setNeedsLayout()
            host.layoutIfNeeded()
            overlay.setNeedsLayout()
            overlay.layoutIfNeeded()
            XCTAssertEqual(overlay.bounds.size, size)
            XCTAssertEqual(resolvedRects.last, target.frame)
            let shade = overlay.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first
            XCTAssertEqual(shade?.path?.boundingBoxOfPath, overlay.bounds)
        }
        overlay.dismiss(.next)
        overlay.dismiss(.next)
        await fulfillment(of: [dismissed], timeout: 2)
        overlay.dismiss(.cancelled)
        XCTAssertEqual(dismissals.count, 1)
        if let dismissal = dismissals.first {
            XCTAssertEqual(dismissal, .next)
        }
        XCTAssertNil(overlay.superview)
    }

    @MainActor func testShowcaseCancellationDoesNotAdvanceAfterNextAnimation() async {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let configuration = ShowcaseOverlayView.Configuration(
            title: "Title", message: "Message", color: .blue,
            titleFont: .systemFont(ofSize: 20), messageFont: .systemFont(ofSize: 14),
            nextTitle: "Next", skipTitle: "Skip"
        )
        var reasons: [ShowcaseOverlayView.Dismissal] = []
        let overlay = ShowcaseOverlayView(configuration: configuration, targetRect: { _ in
            CGRect(x: 100, y: 740, width: 50, height: 50)
        }, completion: { reasons.append($0) })
        overlay.show(in: host)
        overlay.dismiss(.next)
        overlay.dismiss(.cancelled)
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(reasons.count, 1)
        XCTAssertEqual(reasons.first, UIAccessibility.isReduceMotionEnabled ? .next : .cancelled)
        XCTAssertNil(overlay.superview)
    }

    @MainActor func testShowcaseResolvesTabItemsInLTRAndRTLWithoutSelectingThem() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UITabBarController()
        controller.viewControllers = (0..<5).map { index in
            let viewController = UIViewController()
            viewController.tabBarItem = UITabBarItem(title: "Tab \(index)", image: nil, tag: index)
            return viewController
        }
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        for direction in [UISemanticContentAttribute.forceLeftToRight, .forceRightToLeft] {
            controller.tabBar.semanticContentAttribute = direction
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            controller.tabBar.setNeedsLayout()
            controller.tabBar.layoutIfNeeded()
            let first = ShowcaseOverlayView.tabItemRect(in: controller.tabBar, at: 1, convertedTo: controller.view)
            let last = ShowcaseOverlayView.tabItemRect(in: controller.tabBar, at: 4, convertedTo: controller.view)
            XCTAssertNotNil(first)
            XCTAssertNotNil(last)
            if let first = first, let last = last {
                if direction == .forceRightToLeft {
                    XCTAssertGreaterThan(first.midX, last.midX)
                } else {
                    XCTAssertLessThan(first.midX, last.midX)
                }
            }
            XCTAssertEqual(controller.selectedIndex, 0)
        }
        XCTAssertNil(ShowcaseOverlayView.tabItemRect(in: controller.tabBar, at: -1, convertedTo: controller.view))
        XCTAssertNil(ShowcaseOverlayView.tabItemRect(in: controller.tabBar, at: 5, convertedTo: controller.view))
    }

    @MainActor func testShowcaseUsesSystemGeometryRatherThanEstimatingMissingControls() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let tabBar = UITabBar(frame: CGRect(x: 0, y: 760, width: 390, height: 84))
        tabBar.items = (0..<5).map { UITabBarItem(title: "Tab \($0)", image: nil, tag: $0) }
        window.addSubview(tabBar)
        tabBar.layoutIfNeeded()
        for subview in tabBar.subviews {
            subview.isHidden = true
        }
        let rect = ShowcaseOverlayView.tabItemRect(in: tabBar, at: 1, convertedTo: window)
        if #available(iOS 17.0, *),
           let systemFrame = tabBar.items?[1].frame(in: window),
           !systemFrame.isNull, !systemFrame.isInfinite, !systemFrame.isEmpty,
           systemFrame.intersects(window.bounds) {
            XCTAssertEqual(rect, systemFrame)
        } else {
            XCTAssertNil(rect)
        }
    }

    @MainActor func testVerticalTabRailTargetsRenderedIconOutsideSafeArea() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 720))
        let bar = UITabBar(frame: CGRect(x: 382, y: 180, width: 84, height: 500))
        let image = UIImage(systemName: "car.fill")!
        bar.items = (0..<5).map {
            UITabBarItem(title: "Tab \($0)", image: $0 == 2 ? image : nil, tag: $0)
        }

        window.addSubview(bar)
        bar.layoutIfNeeded()
        for child in bar.subviews { child.isHidden = true }
        let container = UIControl(frame: bar.bounds)
        let icon = UIImageView(image: image)
        icon.frame = CGRect(x: 28, y: 300, width: 28, height: 28)
        container.addSubview(icon)
        bar.addSubview(container)
        for y: CGFloat in [300, 340] {
            icon.frame.origin.y = y
            let resolved = ShowcaseOverlayView.tabItemRect(in: bar, at: 2, convertedTo: window)
            if #available(iOS 17.0, *), let frame = bar.items?[2].frame(in: window),
               !frame.isEmpty, !frame.isInfinite, frame.intersects(window.bounds) {
                XCTAssertEqual(resolved, frame)
            } else {
                XCTAssertEqual(resolved, icon.convert(icon.bounds, to: window))
            }
            XCTAssertEqual(resolved?.midX ?? -1, 424, accuracy: 0.01)
        }
    }

    @MainActor func testBottomAlignedRailUsesActualGeometryAfterResizing() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 720))
        let bar = UITabBar(frame: CGRect(x: 382, y: 0, width: 84, height: 686))
        bar.items = (0..<5).map { UITabBarItem(title: "Tab \($0)", image: nil, tag: $0) }
        window.addSubview(bar)
        bar.layoutIfNeeded()
        for child in bar.subviews { child.isHidden = true }
        let icons = (0..<5).map { _ in UIImageView(image: UIImage(systemName: "circle.fill")) }
        for icon in icons { bar.addSubview(icon) }
        for height: CGFloat in [686, 500, 686] {
            bar.frame.size.height = height
            for (index, icon) in icons.enumerated() {
                icon.frame = CGRect(x: 28, y: height - 280 + CGFloat(index) * 52,
                                    width: 28, height: 28)
            }
            for index in icons.indices {
                let resolved = ShowcaseOverlayView.tabItemRect(in: bar, at: index, convertedTo: window)
                if #available(iOS 17.0, *), let frame = bar.items?[index].frame(in: window),
                   !frame.isEmpty, !frame.isInfinite, frame.intersects(window.bounds) {
                    XCTAssertEqual(resolved, frame)
                } else {
                    XCTAssertEqual(resolved, icons[index].convert(icons[index].bounds, to: window))
                }
            }
        }
    }

}
