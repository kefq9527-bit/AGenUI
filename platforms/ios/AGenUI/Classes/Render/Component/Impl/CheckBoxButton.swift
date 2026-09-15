//
//  CheckBoxButton.swift
//  AGenUI
//
// Created on 2026/3/1.
//

#if AGENUI_SDK_BUILD
import UIKit

/// CheckBoxButton control (compliant with A2UI v0.9 protocol)
///
/// Supported properties:
/// - label: Display text (String)
/// - value: Associated value for data binding (String)
/// - isSelected: Checkbox selected state (Boolean)
/// - isEnabled: Checkbox enabled state (Boolean)
///
/// Design notes:
/// - Custom UIControl with checkbox (left) and label (right) layout using FlexLayout
/// - Three visual states: selected (blue fill + white checkmark), unselected (transparent + border), disabled (gray)
/// - Used by CheckBoxComponent and ChoicePickerComponent as the base control
class CheckBoxButton: UIControl {
    
    // MARK: - Public Properties
    
    /// Label text
    var label: String = "" {
        didSet {
            labelView.text = label
            labelView.invalidateIntrinsicContentSize()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
    
    /// Associated value (for data binding)
    var value: String = ""
    
    // MARK: - Style Configuration Properties
    
    /// Checkbox size
    var checkboxSize: CGFloat = 16 {
        didSet {
            updateLayout()
        }
    }
    
    /// Checkbox border width
    var checkboxBorderWidth: CGFloat = 1.5 {
        didSet {
            updateAppearance()
        }
    }
    
    /// Checkbox corner radius
    var checkboxBorderRadius: CGFloat = 6 {
        didSet {
            checkBoxView.layer.cornerRadius = checkboxBorderRadius
        }
    }
    
    /// Selected state background color
    var selectedBackgroundColor: UIColor = UIColor(red: 0x2E/255.0, green: 0x82/255.0, blue: 0xFF/255.0, alpha: 1.0) {
        didSet {
            updateAppearance()
        }
    }
    
    /// Selected state border color
    var selectedBorderColor: UIColor = UIColor(red: 0x2E/255.0, green: 0x82/255.0, blue: 0xFF/255.0, alpha: 1.0) {
        didSet {
            updateAppearance()
        }
    }
    
    /// Unselected state background color
    var unselectedBackgroundColor: UIColor = .clear {
        didSet {
            updateAppearance()
        }
    }
    
    /// Unselected state border color
    var unselectedBorderColor: UIColor = UIColor.black.withAlphaComponent(0.1) {
        didSet {
            updateAppearance()
        }
    }
    
    /// Text to checkbox spacing
    var textMargin: CGFloat = 8 {
        didSet {
            updateLayout()
        }
    }
    
    /// Text color
    var textColor: UIColor = .black {
        didSet {
            updateAppearance()
        }
    }
    
    /// Disabled state text color
    var textColorDisabled: UIColor = UIColor.black.withAlphaComponent(0.4) {
        didSet {
            updateAppearance()
        }
    }
    
    /// Text size
    var textSize: CGFloat = 16 {
        didSet {
            labelView.font = UIFont.systemFont(ofSize: textSize, weight: .regular)
        }
    }

    /// Render the indicator as a radio (exclusive): ring + center dot
    var isExclusive: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    // MARK: - Row Style Configuration

    /// Row background color (default clear so CheckBoxComponent is unaffected)
    var itemBackgroundColor: UIColor = .clear {
        didSet {
            updateAppearance()
        }
    }

    /// Row corner radius
    var itemCornerRadius: CGFloat = 0 {
        didSet {
            updateAppearance()
        }
    }

    /// Row horizontal padding
    var itemPaddingHorizontal: CGFloat = 0 {
        didSet {
            updateLayout()
        }
    }

    /// Row vertical padding
    var itemPaddingVertical: CGFloat = 0 {
        didSet {
            updateLayout()
        }
    }

    // MARK: - Radio Style Configuration (exclusive)

    /// Radio ring color (unselected)
    var radioBorderColor: UIColor = UIColor(red: 0xC5/255.0, green: 0xC5/255.0, blue: 0xC5/255.0, alpha: 1.0) {
        didSet {
            updateAppearance()
        }
    }

    /// Radio ring color (selected)
    var radioBorderColorSelected: UIColor = UIColor(red: 0x24/255.0, green: 0x96/255.0, blue: 0xFF/255.0, alpha: 1.0) {
        didSet {
            updateAppearance()
        }
    }

    /// Radio center dot color (selected)
    var radioDotColor: UIColor = UIColor(red: 0x24/255.0, green: 0x96/255.0, blue: 0xFF/255.0, alpha: 1.0) {
        didSet {
            updateAppearance()
        }
    }

    /// Checkmark tint color (multi selection)
    var checkColor: UIColor = .white {
        didSet {
            checkMarkImageView.tintColor = checkColor
        }
    }

    /// 禁用+选中态背景色；nil 时回退 selectedBackgroundColor 50% 透明度（回显只读浅蓝）
    var disabledSelectedBackgroundColor: UIColor? {
        didSet {
            updateAppearance()
        }
    }

    // MARK: - UIControl Override
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let availWidth = size.width - itemPaddingHorizontal * 2 - checkboxSize - textMargin
        let labelSize = labelView.sizeThatFits(CGSize(width: max(availWidth, 0), height: .greatestFiniteMagnitude))
        let height = max(checkboxSize, labelSize.height) + itemPaddingVertical * 2
        let width = itemPaddingHorizontal * 2 + checkboxSize + textMargin + labelSize.width
        return CGSize(width: min(width, size.width), height: height)
    }
    
    // MARK: - Private Properties
    
    private let labelView: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.black
        label.numberOfLines = 0
        return label
    }()
    
    private let checkBoxView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.layer.borderWidth = 1.5
        return view
    }()
    
    private let checkMarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private let dotView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Private Methods
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let currentCheckboxSize = checkboxSize
        let currentTextMargin = textMargin
        
        // Layout checkbox on the left (respecting row horizontal padding)
        let checkBoxY = (bounds.height - currentCheckboxSize) / 2
        checkBoxView.frame = CGRect(x: itemPaddingHorizontal, y: checkBoxY, width: currentCheckboxSize, height: currentCheckboxSize)
        
        // Layout radio dot centered inside checkbox
        let dotSize = currentCheckboxSize / 2
        let dotInset = (currentCheckboxSize - dotSize) / 2
        dotView.frame = CGRect(x: dotInset, y: dotInset, width: dotSize, height: dotSize)
        dotView.layer.cornerRadius = dotSize / 2
        
        // Layout label to the right of checkbox (respecting row padding)
        let labelX = itemPaddingHorizontal + currentCheckboxSize + currentTextMargin
        let labelWidth = bounds.width - labelX - itemPaddingHorizontal
        if labelWidth > 0 {
            labelView.frame = CGRect(x: labelX, y: itemPaddingVertical, width: labelWidth, height: max(bounds.height - itemPaddingVertical * 2, 0))
        }
    }
    
    private func setupViews() {
        // Use FlexLayout for layout
        updateLayout()
        updateAppearance()
    }
    
    private func updateLayout() {
        // Ensure checkbox and label are added as subviews
        checkBoxView.isUserInteractionEnabled = false
        if checkBoxView.superview == nil {
            checkBoxView.addSubview(checkMarkImageView)
            checkBoxView.addSubview(dotView)
            addSubview(checkBoxView)
        }
        
        // Set checkmark icon frame (centered, dynamically calculated based on checkbox size)
        let iconSize = checkboxSize * 0.75
        let iconOffset = (checkboxSize - iconSize) / 2
        checkMarkImageView.frame = CGRect(x: iconOffset, y: iconOffset, width: iconSize, height: iconSize)
        checkMarkImageView.isUserInteractionEnabled = false
        
        // Add label if not already added
        labelView.isUserInteractionEnabled = false
        if labelView.superview == nil {
            addSubview(labelView)
        }
        
        setNeedsLayout()
    }
    
    private func setCheckmarkVisible(_ visible: Bool) {
        if visible {
            let iconSize = checkboxSize * 0.6
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
            checkMarkImageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
        } else {
            checkMarkImageView.image = nil
        }
        checkMarkImageView.isHidden = !visible
    }

    private func updateAppearance() {
        backgroundColor = itemBackgroundColor
        layer.cornerRadius = itemCornerRadius
        checkMarkImageView.tintColor = checkColor
        
        if isExclusive {
            updateRadioAppearance()
            return
        }
        
        if !isEnabled, !isSelected {
            // Disabled+unselected: keep the empty box look, only dim the label
            checkBoxView.backgroundColor = unselectedBackgroundColor
            checkBoxView.layer.borderColor = unselectedBorderColor.cgColor
            checkBoxView.layer.borderWidth = checkboxBorderWidth
            labelView.textColor = textColorDisabled
            setCheckmarkVisible(false)
        } else if isSelected {
            // Selected state: disabled (read-only replay) uses the light-blue
            // tint so checked rows stay distinguishable from enabled selection
            if !isEnabled {
                checkBoxView.backgroundColor = disabledSelectedBackgroundColor
                    ?? selectedBackgroundColor.withAlphaComponent(0.5)
                labelView.textColor = textColorDisabled
            } else {
                checkBoxView.backgroundColor = selectedBackgroundColor
                labelView.textColor = textColor
            }
            checkBoxView.layer.borderColor = selectedBorderColor.cgColor
            checkBoxView.layer.borderWidth = 0

            // Show checkmark
            let iconSize = checkboxSize * 0.6
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
            checkMarkImageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
            checkMarkImageView.isHidden = false
        } else {
            // Unselected state: use unselected style
            checkBoxView.backgroundColor = unselectedBackgroundColor
            checkBoxView.layer.borderColor = unselectedBorderColor.cgColor
            checkBoxView.layer.borderWidth = checkboxBorderWidth
            labelView.textColor = textColor
            
            // Hide checkmark
            checkMarkImageView.image = nil
            checkMarkImageView.isHidden = true
        }
    }
    
    private func updateRadioAppearance() {
        checkBoxView.backgroundColor = .clear
        checkBoxView.layer.cornerRadius = checkboxSize / 2
        checkBoxView.layer.borderWidth = checkboxBorderWidth
        checkMarkImageView.image = nil
        checkMarkImageView.isHidden = true
        
        if !isEnabled, !isSelected {
            // Disabled+unselected: plain ring without dot, only dim the label
            checkBoxView.layer.borderColor = radioBorderColor.cgColor
            dotView.isHidden = true
            labelView.textColor = textColorDisabled
        } else if isSelected, !isEnabled {
            // Disabled+selected (read-only replay): gray ring + gray dot + dim label,
            // keeps the selection visible while clearly distinct from enabled blue selection
            checkBoxView.layer.borderColor = radioBorderColor.cgColor
            dotView.backgroundColor = textColorDisabled
            dotView.isHidden = false
            labelView.textColor = textColorDisabled
        } else if isSelected {
            checkBoxView.layer.borderColor = radioBorderColorSelected.cgColor
            dotView.backgroundColor = radioDotColor
            dotView.isHidden = false
            labelView.textColor = textColor
        } else {
            checkBoxView.layer.borderColor = radioBorderColor.cgColor
            dotView.isHidden = true
            labelView.textColor = textColor
        }
    }
}

#endif // AGENUI_SDK_BUILD