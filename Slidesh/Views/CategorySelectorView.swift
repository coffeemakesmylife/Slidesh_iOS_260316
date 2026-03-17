//
//  CategorySelectorView.swift
//  Slidesh
//
//  横向滚动分类选择器，选中时使用品牌渐变背景，宽度随文案自适应
//

import UIKit

class CategorySelectorView: UIView {

    // 回调返回选中项的 API value（空字符串 = 全部）
    var onCategorySelected: ((String) -> Void)?

    private(set) var selectedValue: String = ""

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()
    private var chips: [CategoryChipButton] = []
    // 当前选项数组（name, value）
    private var options: [(name: String, value: String)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        stackView.axis      = .horizontal
        stackView.spacing   = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        // 初始默认 "全部场景"
        configure(with: [("全部场景", "")])
    }

    /// 用 API 返回的分类选项重建 chips
    func configure(with options: [(name: String, value: String)]) {
        self.options = options
        // 清空旧 chips
        chips.forEach { $0.removeFromSuperview() }
        chips.removeAll()

        for (index, option) in options.enumerated() {
            let chip = CategoryChipButton(title: option.name, tag: index)
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(chip)
            chips.append(chip)
        }

        // 如果原先选中的 value 不在新选项中，重置为第一项
        if !options.contains(where: { $0.value == selectedValue }) {
            selectedValue = options.first?.value ?? ""
        }
        updateChipStates()
    }

    @objc private func chipTapped(_ sender: CategoryChipButton) {
        guard sender.tag < options.count else { return }
        selectedValue = options[sender.tag].value
        updateChipStates()
        onCategorySelected?(selectedValue)
    }

    private func updateChipStates() {
        for (index, chip) in chips.enumerated() {
            chip.setSelected(options[index].value == selectedValue)
        }
    }
}

// MARK: - CategoryChipButton

// 宽度随文案内容自适应，选中时显示品牌渐变背景
private class CategoryChipButton: UIControl {

    private let label         = UILabel()
    private let gradientLayer = CAGradientLayer()

    init(title: String, tag: Int) {
        super.init(frame: .zero)
        self.tag = tag
        label.text = title
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = 15
        clipsToBounds = true

        gradientLayer.colors     = [UIColor.appGradientStart.cgColor,
                                    UIColor.appGradientMid.cgColor,
                                    UIColor.appGradientEnd.cgColor]
        gradientLayer.locations  = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.isHidden   = true
        layer.insertSublayer(gradientLayer, at: 0)

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])

        updateStyle(selected: false)
    }

    func setSelected(_ selected: Bool) {
        updateStyle(selected: selected)
    }

    private func updateStyle(selected: Bool) {
        if selected {
            gradientLayer.isHidden = false
            backgroundColor        = .clear
            layer.borderColor      = UIColor.clear.cgColor
            label.textColor        = .white
        } else {
            gradientLayer.isHidden = true
            backgroundColor        = .appChipUnselectedBackground
            layer.borderColor      = UIColor.clear.cgColor
            label.textColor        = .appChipUnselectedText
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    override var intrinsicContentSize: CGSize {
        let w = label.intrinsicContentSize.width + 28
        let h = label.intrinsicContentSize.height + 14
        return CGSize(width: w, height: h)
    }
}
