//
//  CategorySelectorView.swift
//  Slidesh
//
//  横向滚动分类选择器，选中时使用品牌渐变背景，宽度随文案自适应
//

import UIKit

class CategorySelectorView: UIView {

    var onCategorySelected: ((TemplateCategory) -> Void)?
    private(set) var selectedCategory: TemplateCategory = .all

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()
    private var chips: [CategoryChipButton] = []

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

        for (index, category) in TemplateCategory.allCases.enumerated() {
            let chip = CategoryChipButton(title: category.rawValue, tag: index)
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(chip)
            chips.append(chip)
        }

        updateChipStates()
    }

    @objc private func chipTapped(_ sender: CategoryChipButton) {
        let category = TemplateCategory.allCases[sender.tag]
        selectedCategory = category
        updateChipStates()
        onCategorySelected?(category)
    }

    private func updateChipStates() {
        for (index, chip) in chips.enumerated() {
            chip.setSelected(TemplateCategory.allCases[index] == selectedCategory)
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

        // 品牌渐变层（仅选中时显示）
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

    // 宽度由 label 内容驱动，Auto Layout 自动推导
    override var intrinsicContentSize: CGSize {
        let w = label.intrinsicContentSize.width + 28  // 左右各 14pt padding
        let h = label.intrinsicContentSize.height + 14 // 上下各 7pt padding
        return CGSize(width: w, height: h)
    }
}
