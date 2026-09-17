  //
//  ButtonComponent.swift
//  AGenUI
//
// Created on 2026/2/27.
//

import UIKit

/// Button component implementation (compliant with A2UI v0.9 protocol)
///
/// Supported properties:
/// - child: Child component ID (usually Text or Icon component) - required
/// - variant: Button style (primary, borderless)
/// - action: Tap action definition - required
/// - value: Optional boolean value (inherited from Checkable)
/// - disable: Whether to disable button (true: not clickable, false: clickable)
/// - checks: Validation result (Dictionary with "result"); button is not clickable while failing
/// - background-color-disabled: Background color when button is disabled
/// - disabled-opacity: Disabled state opacity (0-1), example: 0.5
///
/// Design notes:
/// - Button is a container component that can hold one child component (Text or Icon)
/// - Button itself is a UIView, child components are added via Component.addChild()
class ButtonComponent: Component {
    
    // MARK: - Properties
    
    private var isDisabled: Bool = false
    /// Persisted validation result from the `checks` property; survives diffs
    /// that do not carry a "checks" key (styles/layout/action updates).
    private var checksPassed: Bool = true
    private var disabledBackgroundColor: UIColor? = UIColor(hexString: "#84C4FF")
    private var normalBackgroundColor: UIColor? = UIColor(hexString: "#2496FF")
    private var disabledOpacity: CGFloat = 0.4  // Default disabled opacity
    /// Alpha value recorded just before entering the disabled state, used to restore
    /// the correct opacity (which may come from a CSS "opacity" style) when re-enabled.
    private var normalAlpha: CGFloat = 1.0
    
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
    
    override func updateProperties(_ diff: [String: DiffValue]) {
        
        // Call parent method to apply CSS properties to self
        super.updateProperties(diff)
        
        // Record the alpha set by CSS (e.g. "opacity" style) before any disabled-state
        // override, so it can be correctly restored when the button is re-enabled.
        // Skip while a disabled/checks-failed override is active, otherwise the
        // override alpha (e.g. 0.5) would be mistaken for the CSS normal alpha.
        if !isDisabled && checksPassed {
            normalAlpha = alpha
        }
        
        // Read background-color and background-color-disabled properties from styles field.
        // Explicit CSS colors win over the built-in defaults (#2496FF normal / #84C4FF disabled).
        if case .value(let stylesValue) = diff["styles"], let styles = stylesValue as? [String: Any] {
            if let normalColorStr = styles["background-color"] as? String {
                self.normalBackgroundColor = UIColor(hexString: normalColorStr)
            }
            if let disabledColorStr = styles["background-color-disabled"] as? String {
                self.disabledBackgroundColor = UIColor(hexString: disabledColorStr)
            }
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
        
        // checks adaptation: persist the validation result so later diffs that do
        // not carry a "checks" key (styles/layout/action) cannot wipe the state.
        if case .value(let v) = diff["checks"], let checks = v as? [String: Any] {
            checksPassed = checks["result"] as? Bool ?? true
        } else if case .deleted = diff["checks"] {
            checksPassed = true
        }
        
        // Apply disabled state
        applyDisabledState()
    }
    
    // MARK: - Private Methods
    
    /// Apply disabled state
    private func applyDisabledState() {
        if isDisabled {
            // Disabled state
            isUserInteractionEnabled = false
            
            // If disabled background color specified, use it; otherwise use default
            if let disabledColor = disabledBackgroundColor {
                backgroundColor = disabledColor
            } else {
                // Default disabled background color
                backgroundColor = UIColor(hexString: "#84C4FF")
            }
            
            // Use configured disabled opacity
            alpha = disabledOpacity
            return
        }
        
        // Restore normal background color
        if let normalColor = normalBackgroundColor {
            backgroundColor = normalColor
        }
        
        if !checksPassed {
            // Validation failed: block interaction and gray out the button
            isUserInteractionEnabled = false
            alpha = 0.5
            return
        }
        
        // Enabled state
        isUserInteractionEnabled = true
        
        // Restore the alpha that was recorded before the disabled state was applied.
        // This correctly handles CSS "opacity" styles as well as the default alpha of 1.0.
        alpha = normalAlpha
    }
    
    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        for subview in subviews {
            guard subview is Component else { continue }
            subview.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    // MARK: - Event Handling

    override func handleTap() {
        // If button is disabled, do not handle tap events
        if isDisabled {
            Logger.shared.info("ButtonComponent: Button is disabled, ignoring click: \(componentId)")
            return
        }
        
        // If validation checks failed, do not handle tap events
        if !checksPassed {
            Logger.shared.info("ButtonComponent: checks failed, ignoring click: \(componentId)")
            return
        }
        
        super.handleTap()
    }
}
