//
//  ShowcasePalette.swift
//  AdaptiveShowcase
//
//  Created by Satham Hussain on 04/11/2026.
//


import UIKit
import SwiftUI

private enum ShowcasePalette {
    static let background = UIColor(red: 18 / 255, green: 59 / 255, blue: 93 / 255, alpha: 1)
    static let text = UIColor(red: 220 / 255, green: 231 / 255, blue: 240 / 255, alpha: 1)
    static let button = UIColor(red: 185 / 255, green: 222 / 255, blue: 255 / 255, alpha: 1)
    static let accent = UIColor(red: 140 / 255, green: 203 / 255, blue: 255 / 255, alpha: 1)
    static let inactive = UIColor(red: 96 / 255, green: 125 / 255, blue: 148 / 255, alpha: 1)
}

private struct ShowcasePanel: View {
    let configuration: ShowcaseOverlayView.Configuration
    let next: () -> Void
    let skip: () -> Void
    var measuresContent = false
    var compactLayout = false
    var scrollsWholePanel = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var titleScale = 1.0
    @ScaledMetric(relativeTo: .body) private var messageScale = 1.0

    private let accent = Color(ShowcasePalette.accent)

    var body: some View {
        Group {
            if scrollsWholePanel {
                ScrollView(.vertical) {
                    panelContent
                }
            } else {
                panelContent
            }
        }
        .background(Color(configuration.backgroundColor ?? ShowcasePalette.background))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: compactLayout ? 8 : 20) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<configuration.totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index == configuration.step - 1 ? accent : Color(ShowcasePalette.inactive))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
                Spacer(minLength: 8)
                Text("\(configuration.step) / \(configuration.totalSteps)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(ShowcasePalette.text))
            }
            if measuresContent || scrollsWholePanel {
                textContent.fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    textContent
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) { nextButton; skipButton }
            } else {
                HStack(spacing: 16) {
                    skipButton
                    Spacer(minLength: 0)
                    nextButton
                }
            }
        }
        .padding(compactLayout ? 12 : 24)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: compactLayout ? 8 : 16) {
            Text(configuration.title)
                .font(Font(configuration.titleFont.withSize(configuration.titleFont.pointSize * titleScale)).weight(.semibold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text(configuration.message)
                .font(Font(configuration.messageFont.withSize(configuration.messageFont.pointSize * messageScale)))
                .foregroundStyle(Color(ShowcasePalette.text))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private var nextButton: some View {
        Button(action: next) {
            Text(configuration.nextTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(minHeight: 48)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .foregroundStyle(Color(configuration.backgroundColor ?? ShowcasePalette.background))
                .background(Color(ShowcasePalette.button), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("showcase.next")
    }

    private var skipButton: some View {
        Button(configuration.skipTitle, action: skip)
            .font(.body)
            .foregroundStyle(Color(ShowcasePalette.text))
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            .accessibilityIdentifier("showcase.skip")
    }
}

private final class ShowcasePresentationController: UIViewController {
    var onDismiss: (() -> Void)?
    private var dismissing = false

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissing = isBeingDismissed || presentingViewController?.isBeingDismissed == true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard dismissing || presentingViewController == nil else { return }
        let callback = onDismiss
        onDismiss = nil
        callback?()
    }
}

public final class ShowcaseOverlayView: UIView {
    public enum HighlightShape: Equatable {
        case circle
        case roundedRectangle
    }
    public enum Dismissal {
        case next
        case skipped
        case cancelled
        case unavailable
    }

    public struct Configuration {
        public let title: String
        public let message: String
        public let color: UIColor
        public let titleFont: UIFont
        public let messageFont: UIFont
        public let nextTitle: String
        public let skipTitle: String
        public var highlightShape: HighlightShape
        public var highlightPadding: CGFloat
        public var rippleEnabled: Bool
        public var step: Int
        public var totalSteps: Int
        public var layoutDirection: LayoutDirection
        public var backgroundColor: UIColor?

        public init(title: String, message: String, color: UIColor = .clear,
                    titleFont: UIFont = .systemFont(ofSize: 20),
                    messageFont: UIFont = .systemFont(ofSize: 16),
                    nextTitle: String = "Next", skipTitle: String = "Skip",
                    highlightShape: HighlightShape = .roundedRectangle,
                    highlightPadding: CGFloat = 8, rippleEnabled: Bool = false,
                    step: Int = 1, totalSteps: Int = 1,
                    layoutDirection: LayoutDirection = .leftToRight,
                    backgroundColor: UIColor? = nil) {
            self.title = title
            self.message = message
            self.color = color
            self.titleFont = titleFont
            self.messageFont = messageFont
            self.nextTitle = nextTitle
            self.skipTitle = skipTitle
            self.highlightShape = highlightShape
            self.highlightPadding = highlightPadding
            self.rippleEnabled = rippleEnabled
            self.step = step
            self.totalSteps = totalSteps
            self.layoutDirection = layoutDirection
            self.backgroundColor = backgroundColor
        }
    }

    private let configuration: Configuration
    private let targetRect: (UIView) -> CGRect?
    private var completion: ((Dismissal) -> Void)?
    private var isTransitioningOut = false
    private let shade = CAShapeLayer()
    private let connector = CAShapeLayer()
    private let ripple = CAShapeLayer()
    private var spotlightPath = UIBezierPath()
    private var previousBounds = CGRect.zero
    private let backgroundButton = UIButton(type: .custom)
    private let card = UIView()
    private var panelController: UIHostingController<AnyView>?
    private var sizingController: UIHostingController<AnyView>?
    private var compactPanel = false
    private var scrollsWholePanel = false
    private weak var presentationHost: ShowcasePresentationController?

    public func ownsPresentation(_ controller: UIViewController?) -> Bool {
        guard let controller = controller else { return false }
        return controller === presentationHost
    }

    public init(configuration: Configuration, targetRect: @escaping (UIView) -> CGRect?,
         completion: @escaping (Dismissal) -> Void) {
        self.configuration = configuration
        self.targetRect = targetRect
        self.completion = completion
        super.init(frame: .zero)
        configureViews()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) {
                (view: ShowcaseOverlayView, _: UITraitCollection) in
                view.setNeedsLayout()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show(in host: UIView, parent: UIViewController? = nil) {
        guard superview == nil, completion != nil else { return }
        if parent is UITabBarController || parent is UINavigationController {
            guard presentationHost == nil, let parent = parent,
                  parent.view.window != nil, parent.presentedViewController == nil else {
                dismiss(.unavailable)
                return
            }
            // Present above system containers instead of modifying their managed children.
            let controller = ShowcasePresentationController()
            controller.modalPresentationStyle = .overFullScreen
            controller.view.backgroundColor = .clear
            controller.onDismiss = { [weak self] in
                self?.finishDismissal(.cancelled, dismissPresentation: false)
            }
            presentationHost = controller
            parent.present(controller, animated: false) { [weak self, weak controller] in
                guard let self = self, let controller = controller, self.completion != nil else { return }
                self.attach(in: controller.view, parent: controller)
            }
            return
        }
        attach(in: host, parent: parent)
    }

    private func attach(in host: UIView, parent: UIViewController?) {
        guard superview == nil, completion != nil else { return }
        if let parent = parent, let controller = panelController {
            parent.addChild(controller)
        }
        if let parent = parent, let controller = sizingController {
            parent.addChild(controller)
            controller.didMove(toParent: parent)
        }
        translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self)
        if let parent = parent {
            panelController?.didMove(toParent: parent)
        }
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            topAnchor.constraint(equalTo: host.topAnchor),
            bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        host.layoutIfNeeded()
        if !UIAccessibility.isReduceMotionEnabled {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 12)
            UIView.animate(withDuration: 0.3, delay: 0.15, options: [.curveEaseOut]) {
                self.card.alpha = 1
                self.card.transform = .identity
            }
            alpha = 0
            UIView.animate(withDuration: 0.2) {
                self.alpha = 1
            }
            startRipple()
        }
        UIAccessibility.post(notification: .screenChanged, argument: panelController?.view)
    }

    public func dismiss(_ reason: Dismissal) {
        guard completion != nil else { return }
        if reason == .cancelled {
            finishDismissal(reason)
            return
        }
        guard !isTransitioningOut else { return }
        if reason == .next, !UIAccessibility.isReduceMotionEnabled, superview != nil {
            isTransitioningOut = true
            isUserInteractionEnabled = false
            ripple.removeAllAnimations()
            ripple.opacity = 0
            UIView.animate(withDuration: 0.3, delay: 0,
                           options: [.curveEaseIn, .beginFromCurrentState], animations: {
                self.alpha = 0
            }, completion: { [weak self] _ in
                self?.finishDismissal(reason)
            })
        } else {
            finishDismissal(reason)
        }
    }

    private func finishDismissal(_ reason: Dismissal, dismissPresentation: Bool = true) {
        guard let completion = completion else { return }
        self.completion = nil
        layer.removeAllAnimations()
        ripple.removeAllAnimations()
        card.layer.removeAllAnimations()
        if let controller = panelController, controller.parent != nil {
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
        }
        if let controller = sizingController, controller.parent != nil {
            controller.willMove(toParent: nil)
            controller.removeFromParent()
        }
        removeFromSuperview()
        if let presentationHost = presentationHost, dismissPresentation {
            presentationHost.onDismiss = nil
            presentationHost.dismiss(animated: false) { [self] in
                self.presentationHost = nil
                completion(reason)
            }
        } else {
            presentationHost = nil
            completion(reason)
        }
    }

    public override func accessibilityPerformEscape() -> Bool {
        dismiss(.skipped)
        return true
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard completion != nil, !bounds.isEmpty else { return }
        if bounds != previousBounds {
            card.layer.removeAllAnimations()
            card.transform = .identity
            card.alpha = 1
            previousBounds = bounds
        }
        backgroundButton.frame = bounds

        guard let rect = targetRect(self), !rect.isEmpty,
              rect.intersects(bounds) else {
            connector.path = nil
            // Allow the parent layout to settle before advancing a missing target.
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.completion != nil else { return }
                if self.targetRect(self)?.intersects(self.bounds) != true {
                    self.dismiss(.unavailable)
                }
            }
            return
        }

        let spotlight = rect.insetBy(dx: -configuration.highlightPadding,
                                     dy: -configuration.highlightPadding).intersection(bounds)
        if configuration.highlightShape == .circle {
            let diameter = max(spotlight.width, spotlight.height)
            spotlightPath = UIBezierPath(ovalIn: CGRect(
                x: spotlight.midX - diameter / 2, y: spotlight.midY - diameter / 2,
                width: diameter, height: diameter
            ))
        } else {
            spotlightPath = UIBezierPath(roundedRect: spotlight, cornerRadius: 16)
        }
        let path = UIBezierPath(rect: bounds)
        path.append(spotlightPath)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shade.frame = bounds
        shade.path = path.cgPath
        CATransaction.commit()

        let safeRect = safeAreaLayoutGuide.layoutFrame.insetBy(dx: 16, dy: 16)
        let highlightBounds = spotlightPath.bounds
        let region = Self.contentRegion(in: safeRect, avoiding: highlightBounds,
                                        regularWidth: traitCollection.horizontalSizeClass == .regular)
        let width = min(region.width, traitCollection.horizontalSizeClass == .regular ? 480 : 360)
        guard width > 32, region.height > 0 else {
            card.isHidden = true
            connector.path = nil
            return
        }
        card.isHidden = false
        sizingController?.rootView = panelRoot(measuresContent: true, compact: false)
        var measuredSize = sizingController?.sizeThatFits(
            in: CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        ) ?? .zero
        let needsCompactPanel = ceil(measuredSize.height) > region.height
        if needsCompactPanel {
            sizingController?.rootView = panelRoot(measuresContent: true, compact: true)
            measuredSize = sizingController?.sizeThatFits(
                in: CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
            ) ?? .zero
        }
        let needsWholePanelScroll = ceil(measuredSize.height) > region.height
        if compactPanel != needsCompactPanel || scrollsWholePanel != needsWholePanelScroll {
            compactPanel = needsCompactPanel
            scrollsWholePanel = needsWholePanelScroll
            panelController?.rootView = panelRoot(measuresContent: false, compact: compactPanel)
        }
        let height = min(region.height, ceil(measuredSize.height))
        let panelFrame = Self.panelFrame(in: region, size: CGSize(width: width, height: height),
                                         following: highlightBounds)
        card.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        card.center = CGPoint(x: panelFrame.midX, y: panelFrame.midY)
        panelController?.view.frame = card.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        connector.frame = bounds
        connector.path = Self.connectorPath(from: panelFrame, to: spotlightPath)?.cgPath
        ripple.frame = CGRect(x: spotlight.midX - 1, y: spotlight.midY - 1, width: 2, height: 2)
        let ringRect = spotlightPath.bounds.offsetBy(dx: -spotlight.midX + 1, dy: -spotlight.midY + 1)
        ripple.path = (configuration.highlightShape == .circle
            ? UIBezierPath(ovalIn: ringRect)
            : UIBezierPath(roundedRect: ringRect, cornerRadius: 16)).cgPath
        CATransaction.commit()
    }

    static func panelFrame(in region: CGRect, size: CGSize, following target: CGRect) -> CGRect {
        let width = min(size.width, region.width)
        let height = min(size.height, region.height)
        let x = min(max(target.midX - width / 2, region.minX), region.maxX - width)
        let y: CGFloat
        if region.maxY <= target.minY {
            y = region.maxY - height
        } else if region.minY >= target.maxY {
            y = region.minY
        } else {
            y = min(max(target.midY - height / 2, region.minY), region.maxY - height)
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func connectorPath(from panel: CGRect, to spotlight: UIBezierPath) -> UIBezierPath? {
        let target = CGPoint(x: spotlight.bounds.midX, y: spotlight.bounds.midY)
        guard !panel.contains(target), !spotlight.bounds.isEmpty else { return nil }
        let margin = min(24, panel.width / 2, panel.height / 2)
        var start = CGPoint(
            x: min(max(target.x, panel.minX + margin), panel.maxX - margin),
            y: min(max(target.y, panel.minY + margin), panel.maxY - margin)
        )
        if target.x > panel.maxX {
            start.x = panel.maxX
        } else if target.x < panel.minX {
            start.x = panel.minX
        } else {
            start.y = target.y < panel.minY ? panel.minY : panel.maxY
        }
        guard !spotlight.contains(start) else { return nil }
        var inside: CGFloat = 0
        var outside: CGFloat = 1
        for _ in 0..<24 {
            let fraction = (inside + outside) / 2
            let point = CGPoint(x: target.x + (start.x - target.x) * fraction,
                                y: target.y + (start.y - target.y) * fraction)
            if spotlight.contains(point) { inside = fraction } else { outside = fraction }
        }
        let end = CGPoint(x: target.x + (start.x - target.x) * outside,
                          y: target.y + (start.y - target.y) * outside)
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    static func enclosingRadius(center: CGPoint, rectangles: [CGRect]) -> CGFloat {
        rectangles.flatMap { rect in
            [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
             CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        }.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
    }

    private func startRipple() {
        guard configuration.rippleEnabled, !UIAccessibility.isReduceMotionEnabled else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 1.35
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.55
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 1.2
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.beginTime = CACurrentMediaTime() + 0.45
        ripple.add(group, forKey: "ripple")
    }

    static func contentRegion(in safeRect: CGRect, avoiding target: CGRect,
                              regularWidth: Bool) -> CGRect {
        let gap: CGFloat = 16
        var regions = [
            CGRect(x: safeRect.minX, y: safeRect.minY, width: safeRect.width,
                   height: max(0, min(safeRect.maxY, target.minY - gap) - safeRect.minY)),
            CGRect(x: safeRect.minX, y: max(safeRect.minY, target.maxY + gap),
                   width: safeRect.width,
                   height: max(0, safeRect.maxY - max(safeRect.minY, target.maxY + gap)))
        ]
        if regularWidth {
            regions += [
                CGRect(x: safeRect.minX, y: safeRect.minY,
                       width: max(0, min(safeRect.maxX, target.minX - gap) - safeRect.minX),
                       height: safeRect.height),
                CGRect(x: max(safeRect.minX, target.maxX + gap), y: safeRect.minY,
                       width: max(0, safeRect.maxX - max(safeRect.minX, target.maxX + gap)),
                       height: safeRect.height)
            ]
        }
        return regions.max {
            min($0.width, regularWidth ? 480 : 360) * $0.height <
                min($1.width, regularWidth ? 480 : 360) * $1.height
        } ?? safeRect
    }

    public static func tabItemRect(in tabBar: UITabBar, at index: Int, convertedTo overlay: UIView) -> CGRect? {
        guard let items = tabBar.items, items.indices.contains(index),
              tabBar.window != nil, !tabBar.isHidden, tabBar.alpha > 0 else { return nil }
        if #available(iOS 17.0, *) {
            if let frame = items[index].frame(in: overlay),
               !frame.isNull, !frame.isInfinite, !frame.isEmpty,
               frame.intersects(overlay.bounds) {
                return frame
            }
        }
        if let icon = renderedTabIcon(in: tabBar, item: items[index]) {
            return icon.convert(icon.bounds, to: overlay)
        }
        let icons = visibleImageViews(in: tabBar).filter { $0.image != nil }
        if icons.count == items.count {
            let horizontal = tabBar.bounds.width >= tabBar.bounds.height
            let rtl = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
            let ordered = icons.sorted {
                let first = $0.convert($0.bounds, to: tabBar)
                let second = $1.convert($1.bounds, to: tabBar)
                if horizontal {
                    return rtl ? first.midX > second.midX : first.midX < second.midX
                }
                return first.midY < second.midY
            }
            let icon = ordered[index]
            return icon.convert(icon.bounds, to: overlay)
        }
        let controls = visibleControls(in: tabBar)
        // Prefer semantic identity; sorting is only safe when there is one control per item.
        let label = items[index].accessibilityLabel ?? items[index].title
        if let label = label {
            let matches = controls.filter { $0.accessibilityLabel == label }
            if matches.count == 1, let control = matches.first {
                return control.convert(control.bounds, to: overlay)
            }
            if let window = overlay.window,
               let frame = accessibilityFrame(in: tabBar, matching: label, depth: 0) {
                let windowRect = window.convert(frame, from: window.screen.coordinateSpace)
                let overlayRect = overlay.convert(windowRect, from: window)
                let barRect = tabBar.convert(tabBar.bounds, to: overlay)
                if !overlayRect.isEmpty, barRect.contains(overlayRect),
                   overlayRect.width < barRect.width / 2 {
                    return overlayRect
                }
            }
        }
        guard controls.count == items.count else { return nil }
        let horizontal = tabBar.bounds.width >= tabBar.bounds.height
        let rtl = tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let ordered = controls.sorted {
            let first = $0.convert($0.bounds, to: tabBar)
            let second = $1.convert($1.bounds, to: tabBar)
            if horizontal {
                return rtl ? first.midX > second.midX : first.midX < second.midX
            }
            return first.midY < second.midY
        }
        let control = ordered[index]
        return control.convert(control.bounds, to: overlay)
    }

    private static func accessibilityFrame(in object: NSObject, matching label: String,
                                           depth: Int) -> CGRect? {
        guard depth < 8 else { return nil }
        if object.accessibilityLabel == label, !object.accessibilityFrame.isEmpty {
            return object.accessibilityFrame
        }
        if let view = object as? UIView {
            for child in view.subviews where !child.isHidden && child.alpha > 0 {
                if let frame = accessibilityFrame(in: child, matching: label, depth: depth + 1) {
                    return frame
                }
            }
        }
        let count = object.accessibilityElementCount()
        if count > 0, count < 100 {
            for index in 0..<count {
                if let child = object.accessibilityElement(at: index) as? NSObject, child !== object,
                   let frame = accessibilityFrame(in: child, matching: label, depth: depth + 1) {
                    return frame
                }
            }
        }
        return nil
    }

    private static func visibleControls(in view: UIView) -> [UIControl] {
        view.subviews.flatMap { subview -> [UIControl] in
            guard !subview.isHidden, subview.alpha > 0, !subview.bounds.isEmpty else { return [] }
            let nested = visibleControls(in: subview)
            if !nested.isEmpty { return nested }
            if let control = subview as? UIControl { return [control] }
            return []
        }
    }

    private static func visibleImageViews(in view: UIView) -> [UIImageView] {
        view.subviews.flatMap { child -> [UIImageView] in
            guard !child.isHidden, child.alpha > 0, !child.bounds.isEmpty else { return [] }
            if let imageView = child as? UIImageView { return [imageView] }
            return visibleImageViews(in: child)
        }
    }

    private static func renderedTabIcon(in tabBar: UITabBar, item: UITabBarItem) -> UIImageView? {
        let images = [item.image, item.selectedImage].compactMap { $0 }
        guard !images.isEmpty else { return nil }
        let candidates = visibleImageViews(in: tabBar)
        let exact = candidates.filter { candidate in
            guard let image = candidate.image else { return false }
            return images.contains { $0 === image || ($0.cgImage != nil && $0.cgImage === image.cgImage) }
        }
        if exact.count == 1 { return exact.first }
        let representations = images.compactMap { $0.pngData() }
        let matching = candidates.filter { candidate in
            guard let data = candidate.image?.pngData() else { return false }
            return representations.contains(data)
        }
        return matching.count == 1 ? matching.first : nil
    }

    #if DEBUG
    public static func logTabGeometry(_ tabBar: UITabBar, index: Int, target: CGRect?, overlay: UIView) {
        print("[ShowcaseGeometry] index=\(index) overlay=\(overlay.bounds) safe=\(overlay.safeAreaInsets) target=\(String(describing: target))")
        print("[ShowcaseGeometry] bar children=\(tabBar.subviews.count) accessibilityCount=\(tabBar.accessibilityElementCount())")
        for (position, item) in (tabBar.items ?? []).enumerated() {
            print("[ShowcaseGeometry] item=\(position) accessibilityFrame=\(item.accessibilityFrame)")
        }
        var railRemaining = 100
        func logRail(_ object: NSObject, depth: Int) {
            guard depth < 12, railRemaining > 0 else { return }
            railRemaining -= 1
            if let view = object as? UIView {
                print("[ShowcaseGeometry] rail depth=\(depth) \(type(of: view)) rect=\(view.convert(view.bounds, to: overlay)) hidden=\(view.isHidden) alpha=\(view.alpha) children=\(view.subviews.count)")
                for child in view.subviews { logRail(child, depth: depth + 1) }
            } else {
                print("[ShowcaseGeometry] rail depth=\(depth) \(type(of: object)) accessibilityFrame=\(object.accessibilityFrame)")
            }
            let count = object.accessibilityElementCount()
            if count > 0, count < 100 {
                for position in 0..<count {
                    if let child = object.accessibilityElement(at: position) as? NSObject, child !== object {
                        logRail(child, depth: depth + 1)
                    }
                }
            }
        }
        logRail(tabBar, depth: 0)
        var ancestor: UIView? = tabBar
        while let view = ancestor {
            print("[ShowcaseGeometry] ancestor \(type(of: view)) rect=\(view.convert(view.bounds, to: overlay))")
            ancestor = view.superview
        }
        var remaining = 150
        func log(_ view: UIView, depth: Int) {
            guard remaining > 0, depth < 12, view !== overlay,
                  !view.isHidden, view.alpha > 0 else { return }
            remaining -= 1
            if view.isDescendant(of: tabBar) || view is UIControl || view is UIImageView {
                print("[ShowcaseGeometry] depth=\(depth) \(type(of: view)) rect=\(view.convert(view.bounds, to: overlay)) image=\((view as? UIImageView)?.image != nil)")
            }
            for child in view.subviews { log(child, depth: depth + 1) }
        }
        if let host = overlay.superview { log(host, depth: 0) }
    }
    #endif

    private func configureViews() {
        accessibilityViewIsModal = true
        shade.fillRule = .evenOdd
        clipsToBounds = true
        shade.fillColor = UIColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 0.55).cgColor
        layer.addSublayer(shade)
        connector.fillColor = UIColor.clear.cgColor
        connector.strokeColor = ShowcasePalette.accent.withAlphaComponent(0.9).cgColor
        connector.lineWidth = 1.5
        connector.lineCap = .round
        layer.addSublayer(connector)
        ripple.fillColor = UIColor.clear.cgColor
        ripple.strokeColor = ShowcasePalette.accent.cgColor
        ripple.lineWidth = 3
        ripple.opacity = 0
        layer.addSublayer(ripple)
        addSubview(backgroundButton)
        backgroundButton.isAccessibilityElement = false
        backgroundButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        addSubview(card)
        card.backgroundColor = .clear
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        let controller = UIHostingController(rootView: panelRoot(measuresContent: false, compact: false))
        if #available(iOS 16.4, *) {
            controller.safeAreaRegions = []
        }
        controller.view.backgroundColor = .clear
        card.addSubview(controller.view)
        panelController = controller
        sizingController = UIHostingController(rootView: panelRoot(measuresContent: true, compact: false))
        if #available(iOS 16.4, *) {
            sizingController?.safeAreaRegions = []
        }
        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeChanged),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    private func panelRoot(measuresContent: Bool, compact: Bool) -> AnyView {
        AnyView(ShowcasePanel(configuration: configuration, next: { [weak self] in
            self?.dismiss(.next)
        }, skip: { [weak self] in
            self?.dismiss(.skipped)
        }, measuresContent: measuresContent, compactLayout: compact,
            scrollsWholePanel: !measuresContent && scrollsWholePanel)
            .environment(\.layoutDirection, configuration.layoutDirection)
            .ignoresSafeArea())
    }

    @objc private func contentSizeChanged() { setNeedsLayout() }
    @objc private func reduceMotionChanged() {
        ripple.removeAllAnimations()
        if UIAccessibility.isReduceMotionEnabled {
            card.layer.removeAllAnimations()
            card.transform = .identity
            card.alpha = 1
        } else if !isTransitioningOut, completion != nil {
            startRipple()
        }
    }
    @objc private func nextTapped() { dismiss(.next) }
    @objc private func skipTapped() { dismiss(.skipped) }
}

public struct ShowcaseStep: Equatable {
    public let target: String
    public private(set) var tabIndex: Int?
    public let title: String
    public let message: String
    public var nextTitle: String
    public var skipTitle: String
    public var highlightShape: ShowcaseOverlayView.HighlightShape
    public var backgroundColor: UIColor?

    public init(target: String, title: String, message: String,
                nextTitle: String = "Next", skipTitle: String = "Skip",
                highlightShape: ShowcaseOverlayView.HighlightShape = .roundedRectangle,
                backgroundColor: UIColor? = nil) {
        self.target = target
        self.title = title
        self.message = message
        self.nextTitle = nextTitle
        self.skipTitle = skipTitle
        self.highlightShape = highlightShape
        self.backgroundColor = backgroundColor
    }

    /// Targets a zero-based item in the enclosing native TabView's UIKit tab controller.
    public init(tabIndex: Int, title: String, message: String,
                nextTitle: String = "Next", skipTitle: String = "Skip",
                highlightShape: ShowcaseOverlayView.HighlightShape = .circle,
                backgroundColor: UIColor? = nil) {
        self.init(target: "", title: title, message: message,
                  nextTitle: nextTitle, skipTitle: skipTitle,
                  highlightShape: highlightShape, backgroundColor: backgroundColor)
        self.tabIndex = tabIndex
    }
}

private struct ShowcaseTargetPreference: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    public func showcaseTarget(_ id: String) -> some View {
        anchorPreference(key: ShowcaseTargetPreference.self, value: .bounds) { [id: $0] }
    }

    /// Attach to a common ancestor of uniquely named targets, inside the current screen or sheet.
    /// A step waits for its target to appear; off-screen targets must be scrolled into view by the app.
    public func showcase(isPresented: Binding<Bool>, steps: [ShowcaseStep]) -> some View {
        modifier(ShowcaseModifier(isPresented: isPresented, steps: steps))
    }
}

private struct ShowcaseModifier: ViewModifier {
    @Binding var isPresented: Bool
    let steps: [ShowcaseStep]
    @State private var index = 0
    @State private var generation = UUID()
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(ShowcaseTargetPreference.self) { targets in
            GeometryReader { geometry in
                if isPresented, steps.indices.contains(index) {
                    let step = steps[index]
                    let rect = targets[step.target].map { geometry[$0] }.flatMap { rect in
                        rect.isEmpty || !rect.intersects(CGRect(origin: .zero, size: geometry.size)) ? nil : rect
                    }
                    let currentGeneration = generation
                    ShowcaseHost(
                        step: step, index: index, total: steps.count,
                        target: rect, layoutDirection: layoutDirection
                    ) { reason in
                        guard isPresented, generation == currentGeneration else { return }
                        switch reason {
                        case .next:
                            if index + 1 < steps.count {
                                index += 1
                            } else {
                                isPresented = false
                            }
                        case .skipped:
                            isPresented = false
                        case .cancelled, .unavailable:
                            break
                        }
                    }
                    .allowsHitTesting(rect != nil || step.tabIndex != nil)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: isPresented) { presented in
            index = 0
            generation = UUID()
            if presented, steps.isEmpty { isPresented = false }
        }
        .onChange(of: steps) { _ in
            index = 0
            generation = UUID()
            if steps.isEmpty { isPresented = false }
        }
        .onAppear {
            if steps.isEmpty { isPresented = false }
        }
    }
}

private struct ShowcaseHost: UIViewControllerRepresentable {
    let step: ShowcaseStep
    let index: Int
    let total: Int
    let target: CGRect?
    let layoutDirection: LayoutDirection
    let completion: (ShowcaseOverlayView.Dismissal) -> Void

    func makeUIViewController(context: Context) -> ShowcaseHostController {
        ShowcaseHostController()
    }

    func updateUIViewController(_ controller: ShowcaseHostController, context: Context) {
        controller.update(
            step: step, index: index, total: total, target: target,
            layoutDirection: layoutDirection, completion: completion)
    }

    static func dismantleUIViewController(_ controller: ShowcaseHostController, coordinator: ()) {
        controller.cancel()
    }
}

final class ShowcaseHostController: UIViewController {
    private var step: ShowcaseStep?
    private var index = 0
    private var total = 0
    private var target: CGRect?
    private var direction: LayoutDirection = .leftToRight
    private var completion: ((ShowcaseOverlayView.Dismissal) -> Void)?
    private var overlay: ShowcaseOverlayView?
    private var completedStep = false
    private var completionGeneration = UUID()

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
    }

    func update(
        step: ShowcaseStep, index: Int, total: Int, target: CGRect?,
        layoutDirection: LayoutDirection,
        completion: @escaping (ShowcaseOverlayView.Dismissal) -> Void
    ) {
        if self.step != step || self.index != index || self.total != total
            || direction != layoutDirection
        {
            cancel()
            completedStep = false
        }
        self.step = step
        self.index = index
        self.total = total
        self.target = target
        direction = layoutDirection
        self.completion = completion
        if target == nil && step.tabIndex == nil { cancel() }
        view.setNeedsLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.window != nil, !view.bounds.isEmpty, let step = step, !completedStep
        else { return }
        let tabController = tabBarController
        if let index = step.tabIndex {
            guard let tabController = tabController,
                  ShowcaseOverlayView.tabItemRect(in: tabController.tabBar, at: index,
                                                  convertedTo: tabController.view) != nil else { return }
        } else {
            guard let target = target, !target.isEmpty, target.intersects(view.bounds) else { return }
        }
        if let overlay = overlay {
            overlay.setNeedsLayout()
            return
        }
        let configuration = ShowcaseOverlayView.Configuration(
            title: step.title, message: step.message, color: .clear,
            titleFont: .systemFont(ofSize: 20), messageFont: .systemFont(ofSize: 16),
            nextTitle: step.nextTitle, skipTitle: step.skipTitle,
            highlightShape: step.highlightShape, rippleEnabled: step.tabIndex != nil,
            step: index + 1, totalSteps: total,
            layoutDirection: direction, backgroundColor: step.backgroundColor
        )
        let overlay = ShowcaseOverlayView(
            configuration: configuration,
            targetRect: { [weak self] overlay in
                guard let self = self else { return nil }
                if let index = self.step?.tabIndex, let tabController = self.tabBarController {
                    return ShowcaseOverlayView.tabItemRect(
                        in: tabController.tabBar, at: index, convertedTo: overlay)
                }
                guard let target = self.target else { return nil }
                return self.view.convert(target, to: overlay)
            },
            completion: { [weak self] reason in
                guard let self = self else { return }
                self.overlay = nil
                guard reason == .next || reason == .skipped else { return }
                self.completedStep = true
                let completion = self.completion
                let generation = self.completionGeneration
                // SwiftUI state must not be changed during a representable layout/update.
                DispatchQueue.main.async { [weak self] in
                    guard self?.completionGeneration == generation else { return }
                    completion?(reason)
                }
            })
        self.overlay = overlay
        if step.tabIndex != nil, let tabController = tabController {
            overlay.show(in: tabController.view, parent: tabController)
        } else {
            overlay.show(in: view, parent: self)
        }
    }

    func cancel() {
        completionGeneration = UUID()
        overlay?.dismiss(.cancelled)
        overlay = nil
    }
}

#if DEBUG
    struct ShowcaseSwiftUIExample: View {
        @State private var showGuide = false

        var body: some View {
            VStack(spacing: 32) {
                Button("Edit profile") {}
                    .showcaseTarget("editProfile")
                Button("Notifications") {}
                    .showcaseTarget("notifications")
                Button("Show guide") { showGuide = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .showcase(
                isPresented: $showGuide,
                steps: [
                    ShowcaseStep(
                        target: "editProfile", title: "Edit your profile",
                        message: "Update your details here."),
                    ShowcaseStep(
                        target: "notifications", title: "Notifications",
                        message: "Manage your notification preferences.", nextTitle: "Done"),
                ])
        }
    }

    private struct ShowcaseSwiftUIExamplePreviews: PreviewProvider {
        static var previews: some View {
            ShowcaseSwiftUIExample()
            ShowcaseSwiftUIExample()
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
#endif
