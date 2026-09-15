//
//  CardComponent.swift
//  AGenUI
//
// Created on 2026/2/27.
//

import UIKit

/// CardComponent component implementation (compliant with A2UI v0.9 protocol)
///
/// Supported properties:
/// - children: Child component ID array (Array<String>)
/// - CSS properties: padding, background-color, border-radius, filter (drop-shadow) (applied via CSSPropertyApplier)
class CardComponent: Component {
    
    // MARK: - Initialization
    
    init(componentId: String, properties: [String: Any]) {
        super.init(componentId: componentId, componentType: "Card", properties: properties)

        // Design defaults (used when the DSL carries no styles).
        // CSS properties from the DSL still override these via CSSPropertyApplier.
        backgroundColor = .white
        layer.borderWidth = 0.5                       // 1px @2x
        layer.borderColor = UIColor(red: 0xE5/255.0, green: 0xE7/255.0, blue: 0xEB/255.0, alpha: 1.0).cgColor
        layer.cornerRadius = 10                       // 20px / 2
        clipsToBounds = true

        // Apply initial properties
        updateProperties(DiffValue.from(properties))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Component Override
    
    override func updateProperties(_ diff: [String: DiffValue]) {
        // Call parent method to apply CSS properties to self
        // padding, background-color, border-radius, filter etc. are applied automatically
        super.updateProperties(diff)
    }
}
