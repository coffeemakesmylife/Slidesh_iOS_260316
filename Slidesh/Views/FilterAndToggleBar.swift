//
//  FilterAndToggleBar.swift
//  Slidesh
//
//  筛选栏：左侧风格/颜色筛选，右侧网格/列表切换
//

import UIKit

// 筛选栏：左侧风格/颜色筛选按钮，右侧网格/列表切换（LayoutMode 定义在 TemplateModel.swift）
class FilterAndToggleBar: UIView {

    var onStyleFilter: (() -> Void)?
    var onColorFilter: (() -> Void)?
    var onLayoutToggle: ((LayoutMode) -> Void)?

    private(set) var layoutMode: LayoutMode = .grid

    // 对外暴露，让 VC 可更新选中文字
    let styleButton = FilterChipButton(title: "风格")
    let colorButton = FilterChipButton(title: "颜色")
    private let toggleButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let leftStack = UIStackView(arrangedSubviews: [styleButton, colorButton])
        leftStack.axis = .horizontal
        leftStack.spacing = 8
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        toggleButton.setImage(UIImage(systemName: "square.grid.2x2"), for: .normal)
        toggleButton.tintColor = .appTextSecondary
        toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftStack)
        addSubview(toggleButton)

        NSLayoutConstraint.activate([
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            toggleButton.widthAnchor.constraint(equalToConstant: 36),
            toggleButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        styleButton.addTarget(self, action: #selector(styleTapped), for: .touchUpInside)
        colorButton.addTarget(self, action: #selector(colorTapped), for: .touchUpInside)
    }

    @objc private func styleTapped() { onStyleFilter?() }
    @objc private func colorTapped() { onColorFilter?() }

    @objc private func toggleTapped() {
        layoutMode = layoutMode == .grid ? .list : .grid
        let icon = layoutMode == .grid ? "square.grid.2x2" : "list.bullet"
        toggleButton.setImage(UIImage(systemName: icon), for: .normal)
        onLayoutToggle?(layoutMode)
    }

    // 更新筛选按钮选中状态标题
    func setStyleTitle(_ title: String, active: Bool) {
        styleButton.setFilterTitle(title, active: active)
    }

    func setColorTitle(_ title: String, active: Bool) {
        colorButton.setFilterTitle(title, active: active)
    }
}

// MARK: - FilterChipButton

// 带下箭头的筛选胶囊按钮
class FilterChipButton: UIControl {

    private let titleLabel  = UILabel()
    private let chevronView = UIImageView()
    private var isActive = false

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = 14
        layer.borderWidth = 1

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        chevronView.image = UIImage(systemName: "chevron.down",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        chevronView.contentMode = .scaleAspectFit

        let stack = UIStackView(arrangedSubviews: [titleLabel, chevronView])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        updateStyle()
    }

    func setFilterTitle(_ title: String, active: Bool) {
        titleLabel.text = title
        isActive = active
        updateStyle()
    }

    private func updateStyle() {
        let color: UIColor = isActive ? .appPrimary : .appTextSecondary
        titleLabel.textColor = color
        chevronView.tintColor = color
        layer.borderColor = isActive ? UIColor.appPrimary.cgColor : UIColor.appCardBorder.cgColor
        backgroundColor = isActive ? .appPrimarySubtle : .clear
    }
}
