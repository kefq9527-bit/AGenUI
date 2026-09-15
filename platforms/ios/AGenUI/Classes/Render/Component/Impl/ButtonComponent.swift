  //
//  ButtonComponent.swift
//  AGenUI
//
// Created on 2026/2/27.
//

import UIKit
import QuartzCore

enum FlashLog {
    static let url: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("flash.log")
    static func log(_ msg: String) {
        let line = String(format: "%.6f %@ %@", CACurrentMediaTime(), Thread.isMainThread ? "M" : "B", msg)
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: url.path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: url.path, contents: data)
        }
    }
}

/// Button component implementation (compliant with A2UI v0.9 protocol)
///
/// Supported properties:
/// - child: Child component ID (usually Text or Icon component) - required
/// - variant: Button style (primary, borderless)
/// - action: Tap action definition - required
/// - value: Optional boolean value (inherited from Checkable)
/// - disable: Whether to disable button (true: not clickable, false: clickable)
/// - background-color-disabled: Background color when button is disabled
/// - disabled-opacity: Disabled state opacity (0-1), example: 0.5
///
/// Design notes:
/// - Button is a container component that can hold one child component (Text or Icon)
/// - Button itself is a UIView, child components are added via Component.addChild()
class ButtonComponent: Component {
    
    // MARK: - Properties
    
    private var isDisabled: Bool = false
    private var disabledBackgroundColor: UIColor?
    private var normalBackgroundColor: UIColor?
    private var disabledOpacity: CGFloat = 0.4  // Default disabled opacity
    /// Alpha value recorded just before entering the disabled state, used to restore
    /// the correct opacity (which may come from a CSS "opacity" style) when re-enabled.
    private var normalAlpha: CGFloat = 1.0

    // Default primary look, used when no explicit CSS background / radius is provided
    private let defaultNormalBackgroundColor = UIColor(red: 0x24/255.0, green: 0x96/255.0, blue: 0xFF/255.0, alpha: 1.0)
    private let defaultDisabledBackgroundColor = UIColor(red: 0x84/255.0, green: 0xC4/255.0, blue: 0xFF/255.0, alpha: 1.0)
    private let defaultCornerRadius: CGFloat = 8
    private let normalTextColor = UIColor.white
    private let disabledTextColor = UIColor(red: 0xEB/255.0, green: 0xF5/255.0, blue: 0xFF/255.0, alpha: 1.0)
    private var hasExplicitBackground = false
    private var hasExplicitCornerRadius = false
    /// User-provided padding or explicit size in styles; skips default padding injection
    private var hasExplicitSizeOrPadding = false
    private var paddingHorizontal: CGFloat = 16
    private var paddingVertical: CGFloat = 8
    /// Last size reported to the engine; used to hold the padded frame across
    /// engine-side platform-size resets (prevents a one-tick shrink flash).
    private var lastReportedSize: CGSize = .zero
    /// primary buttons get the filled blue default look; borderless stays transparent
    private var variant: String = "primary"

    private var isPrimary: Bool {
        return variant != "borderless"
    }

    // MARK: - Initialization
    
    init(componentId: String, properties: [String: Any]) {
        super.init(componentId: componentId, componentType: "Button", properties: properties)
        
        // Apply initial properties
        updateProperties(DiffValue.from(properties))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Component Override

    override var frame: CGRect {
        get { super.frame }
        set {
            let old = super.frame
            super.frame = newValue
            if abs(old.minX - newValue.minX) > 0.5 || abs(old.minY - newValue.minY) > 0.5
                || abs(old.width - newValue.width) > 0.5 || abs(old.height - newValue.height) > 0.5 {
                FlashLog.log("BTN frame \(NSCoder.string(for: old)) -> \(NSCoder.string(for: newValue))")
            }
        }
    }

    override func updateProperties(_ diff: [String: DiffValue]) {
        var styleDesc = ""
        if case .value(let stylesValue) = diff["styles"], let styles = stylesValue as? [String: Any] {
            styleDesc = " styles[x=\(styles["x"] ?? "-"),y=\(styles["y"] ?? "-"),w=\(styles["width"] ?? "-"),h=\(styles["height"] ?? "-"),bg=\(styles["background-color"] ?? "-")]"
        }
        FlashLog.log("BTN updateProperties keys=\(Array(diff.keys).sorted().joined(separator: ","))\(styleDesc)")

        // Call parent method to apply CSS properties to self
        super.updateProperties(diff)
        
        // Record the alpha set by CSS (e.g. "opacity" style) before any disabled-state
        // override, so it can be correctly restored when the button is re-enabled.
        if !isDisabled {
            normalAlpha = alpha
        }
        
        // Read background-color-disabled and disabled-opacity properties from styles field
        if case .value(let stylesValue) = diff["styles"], let styles = stylesValue as? [String: Any] {
            if let disabledColorStr = styles["background-color-disabled"] as? String {
                self.disabledBackgroundColor = UIColor(hexString: disabledColorStr)
            }
            if let normalColorStr = styles["background-color"] as? String {
                let color = UIColor(hexString: normalColorStr)
                self.normalBackgroundColor = color
                self.hasExplicitBackground = !isSpecDefaultBackground(color)
            }
            if styles["padding"] != nil {
                self.hasExplicitSizeOrPadding = true
            }
            if let width = styles["width"] as? String, width != "auto" {
                self.hasExplicitSizeOrPadding = true
            }
            if let height = styles["height"] as? String, height != "auto" {
                self.hasExplicitSizeOrPadding = true
            }
            if styles["border-radius"] != nil {
                self.hasExplicitCornerRadius = true
            }
        }
        
        // Handle variant property
        if case .value(let v) = diff["variant"], let variantValue = v as? String {
            self.variant = variantValue
        } else if case .deleted = diff["variant"] {
            self.variant = "primary"
        }

        // Handle disable property
        if case .value(let v) = diff["disable"], let disable = v as? Bool {
            self.isDisabled = disable
        } else if case .deleted = diff["disable"] {
            self.isDisabled = false
        }
        
        // Parse disabled-opacity property, range 0-1
        let localStyleConfig = ComponentStyleConfigManager.shared.getConfig(for: componentType)
        // In JSON, disabled-opacity is string type "0.8", need to check String first
        if let opacityStr = localStyleConfig?["disabled-opacity"] as? String {
            if let opacity = Double(opacityStr) {
                self.disabledOpacity = max(0.0, min(1.0, CGFloat(opacity)))
            }
        } else if let opacity = localStyleConfig?["disabled-opacity"] as? Double {
            self.disabledOpacity = max(0.0, min(1.0, CGFloat(opacity)))
        } else if let opacity = localStyleConfig?["disabled-opacity"] as? NSNumber {
            self.disabledOpacity = max(0.0, min(1.0, CGFloat(truncating: opacity)))
        }
        
        // Parse default padding from local style config (design px, halved by parseSize)
        if let padding = localStyleConfig?["padding-horizontal"] as? String,
           let value = ComponentStyleConfigManager.parseSize(padding) {
            self.paddingHorizontal = value
        }
        if let padding = localStyleConfig?["padding-vertical"] as? String,
           let value = ComponentStyleConfigManager.parseSize(padding) {
            self.paddingVertical = value
        }
        
        // A partial updateComponents may carry only the Button definition, leaving the
        // declared child Text detached; re-attach it so the button never collapses.
        ensureChildAttached()

        // Apply disabled state
        applyDisabledState()
        
        // checks adaptation
        if case .value(let v) = diff["checks"], let checks = v as? [String: Any] {
            let result = checks["result"] as? Bool ?? true
            
            // Control clickability and enabled state
            isUserInteractionEnabled = result
            
            // Visual feedback - button grays out on validation failure
            alpha = result ? 1.0 : 0.5
        }
    }
    
    // MARK: - Private Methods

    /// Re-attaches the child component declared in properties when a partial
    /// update left the Button without its title Text (which would collapse its size).
    @MainActor private func ensureChildAttached() {
        guard let surface = surface else { return }
        for childId in getChildrenIdsFromProperties() {
            if children.contains(where: { $0.componentId == childId }) { continue }
            if let child = surface.getComponent(componentId: childId) {
                addChild(child)
            }
        }
    }

    /// Apply disabled state
    private func applyDisabledState() {
        if isPrimary, !hasExplicitCornerRadius {
            layer.cornerRadius = defaultCornerRadius
        }
        if isPrimary, !hasExplicitBackground {
            layer.borderWidth = 0
        }
        clipsToBounds = true

        if isDisabled {
            // Disabled state
            isUserInteractionEnabled = false

            // Primary falls back to the default light blue; borderless stays transparent
            if isPrimary {
                backgroundColor = disabledBackgroundColor ?? defaultDisabledBackgroundColor
            } else {
                backgroundColor = disabledBackgroundColor ?? (hasExplicitBackground ? normalBackgroundColor : .clear)
            }

            // Use configured disabled opacity
            alpha = disabledOpacity
            if isPrimary {
                applyTitleColor(disabledTextColor)
            }
        } else {
            // Enabled state
            isUserInteractionEnabled = true

            // Restore normal background color, falling back to the default primary blue
            backgroundColor = hasExplicitBackground ? normalBackgroundColor : (isPrimary ? defaultNormalBackgroundColor : .clear)

            // Restore the alpha that was recorded before the disabled state was applied.
            // This correctly handles CSS "opacity" styles as well as the default alpha of 1.0.
            alpha = normalAlpha
            if isPrimary {
                applyTitleColor(normalTextColor)
            }
        }
    }

    /// Recolors the UILabel rendered by the child Text component so the title
    /// stays legible on the primary background in both enabled and disabled states.
    private func applyTitleColor(_ color: UIColor) {
        for case let label as UILabel in subviews where !(label is Component) {
            label.textColor = color
            label.textAlignment = .center
        }
        for child in children {
            for case let label as UILabel in child.subviews {
                label.textColor = color
                label.textAlignment = .center
            }
        }
    }
    
    /// Detects the background color injected by the C++ component spec default
    /// (design token Color_BG_L5: light #FFFFFF / dark #363E4D). Such a value
    /// means the author did not choose a background, so the primary default
    /// look (blue fill + white title) must be kept.
    private func isSpecDefaultBackground(_ color: UIColor?) -> Bool {
        guard let color else { return false }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
        let isWhite = abs(r - 1) < 0.001 && abs(g - 1) < 0.001 && abs(b - 1) < 0.001
        let isDarkToken = abs(r - 54/255) < 0.001 && abs(g - 62/255) < 0.001 && abs(b - 77/255) < 0.001
        return (isWhite || isDarkToken) && abs(a - 1) < 0.001
    }

    /// Measures the title label's intrinsic size; independent of the Yoga frame,
    /// which may be stretched by the parent's align-items and must not be fed back.
    private static func measuredContentSize(of component: Component) -> CGSize {
        for case let label as UILabel in component.subviews {
            return label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                              height: CGFloat.greatestFiniteMagnitude))
        }
        return .zero
    }

    /// Reports the content size plus default padding back to the Yoga engine so
    /// the button frame grows around its title (visual horizontal/vertical padding).
    private func notifyPaddedSizeIfNeeded() {
        guard !hasExplicitSizeOrPadding, let child = children.first else { return }
        let content = Self.measuredContentSize(of: child)
        guard content.width > 0, content.height > 0 else { return }
        let desiredWidth = content.width + paddingHorizontal * 2
        let desiredHeight = content.height + paddingVertical * 2
        if abs(bounds.width - desiredWidth) <= 0.5, abs(bounds.height - desiredHeight) <= 0.5 {
            lastReportedSize = CGSize(width: desiredWidth, height: desiredHeight)
            return
        }
        // The engine clears platform-reported sizes whenever business attributes
        // change (e.g. disable toggling on each option tap), which would flash a
        // shrunken frame for one tick. Hold the padded frame until the re-report
        // converges so the shrink is never rendered.
        if abs(lastReportedSize.width - desiredWidth) <= 0.5,
           abs(lastReportedSize.height - desiredHeight) <= 0.5 {
            FlashLog.log("BTN hold bounds=\(NSCoder.string(for: bounds)) desired=\(desiredWidth)x\(desiredHeight)")
            let center = CGPoint(x: frame.midX, y: frame.midY)
            frame = CGRect(x: center.x - desiredWidth / 2,
                           y: center.y - desiredHeight / 2,
                           width: desiredWidth,
                           height: desiredHeight)
        } else {
            FlashLog.log("BTN report-new bounds=\(NSCoder.string(for: bounds)) desired=\(desiredWidth)x\(desiredHeight)")
            lastReportedSize = CGSize(width: desiredWidth, height: desiredHeight)
        }
        notifyLayoutChanged(width: desiredWidth, height: desiredHeight)
    }

    // MARK: - Child Management

    @MainActor override func addChild(_ child: Component) {
        super.addChild(child)
        if isPrimary {
            applyTitleColor(isDisabled ? disabledTextColor : normalTextColor)
        }
        notifyPaddedSizeIfNeeded()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        FlashLog.log("BTN layoutSubviews bounds=\(NSCoder.string(for: bounds)) frame=\(NSCoder.string(for: frame))")
        for subview in subviews {
            guard let component = subview as? Component else { continue }
            let content = Self.measuredContentSize(of: component)
            if content.width > 0, content.height > 0 {
                component.frame = CGRect(x: (bounds.width - content.width) / 2,
                                         y: (bounds.height - content.height) / 2,
                                         width: content.width,
                                         height: content.height)
            } else {
                component.center = CGPoint(x: bounds.midX, y: bounds.midY)
            }
        }
        notifyPaddedSizeIfNeeded()
    }

    // MARK: - Event Handling

    override func handleTap() {
        // If button is disabled, do not handle tap events
        if isDisabled {
            Logger.shared.debug("ButtonComponent: Button is disabled, ignoring click: \(componentId)")
            return
        }
        
        super.handleTap()
    }
}
