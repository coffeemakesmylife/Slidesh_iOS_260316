//
//  CategorySelectorView.swift
//  Slidesh
//
//  横向滚动分类选择器，选中时背景变为主色
//

import UIKit

class CategorySelectorView: UIView {

    var onCategorySelected: ((TemplateCategory) -> Void)?
    private(set) var selectedCategory: TemplateCategory = .all

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()
    private var buttons: [UIButton] = []

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

        stackView.axis = .horizontal
        stackView.spacing = 8
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

        TemplateCategory.allCases.forEach { category in
            let btn = makeButton(title: category.rawValue)
            btn.tag = TemplateCategory.allCases.firstIndex(of: category) ?? 0
            btn.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
            buttons.append(btn)
        }

        updateButtonStates()
    }

    private func makeButton(title: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = .systemFont(ofSize: 14, weight: .medium)
            return a
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        config.cornerStyle = .capsule
        let btn = UIButton(configuration: config)
        return btn
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let category = TemplateCategory.allCases[sender.tag]
        selectedCategory = category
        updateButtonStates()
        onCategorySelected?(category)
    }

    private func updateButtonStates() {
        for (index, btn) in buttons.enumerated() {
            let isSelected = TemplateCategory.allCases[index] == selectedCategory
            btn.configuration?.baseBackgroundColor = isSelected ? .appPrimary : .appPrimarySubtle
            btn.configuration?.baseForegroundColor = isSelected ? .white : .appPrimary
        }
    }
}
