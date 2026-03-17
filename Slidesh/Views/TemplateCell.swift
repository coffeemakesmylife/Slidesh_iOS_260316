//
//  TemplateCell.swift
//  Slidesh
//
//  模板 CollectionView Cell，支持网格/列表两种布局形态
//

import UIKit

// 渐变预览视图——在自身 layoutSubviews 中更新 gradientLayer.frame，
// 确保 bounds 已由 Auto Layout 确定，修复首次显示渐变不可见的问题
private class GradientPreviewView: UIView {
    let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradientLayer)
        layer.cornerRadius = 12
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

class TemplateCell: UICollectionViewCell {

    static let reuseID = "TemplateCell"

    // MARK: - 子视图

    private let previewView = GradientPreviewView()
    private let nameLabel   = UILabel()
    private let descLabel   = UILabel()
    private let usageLabel  = UILabel()
    private let infoStack   = UIStackView()
    // 外层栈：axis 切换实现网格/列表两种布局，替代 dual constraint 方案
    private let outerStack  = UIStackView()

    // 网格模式：预览图高度 ≈ 自身宽度 × 0.62
    private lazy var gridHeightConstraint = previewView.heightAnchor.constraint(
        equalTo: previewView.widthAnchor, multiplier: 0.62)
    // 列表模式：预览图固定宽度 90pt
    private lazy var listWidthConstraint = previewView.widthAnchor.constraint(equalToConstant: 90)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: - 视图配置

    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        contentView.backgroundColor = .appCardBackground.withAlphaComponent(0.65)

        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .appTextPrimary
        nameLabel.numberOfLines = 2

        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .appTextSecondary
        descLabel.numberOfLines = 2

        usageLabel.font = .systemFont(ofSize: 11)
        usageLabel.textColor = .appTextTertiary

        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .leading
        infoStack.addArrangedSubview(nameLabel)
        infoStack.addArrangedSubview(descLabel)
        infoStack.addArrangedSubview(usageLabel)

        outerStack.axis = .vertical
        outerStack.spacing = 8
        outerStack.alignment = .fill
        outerStack.addArrangedSubview(previewView)
        outerStack.addArrangedSubview(infoStack)
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            outerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            outerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            outerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

        // 默认网格模式
        gridHeightConstraint.isActive = true
    }

    // MARK: - 公开接口

    func configure(with model: TemplateModel, mode: LayoutMode) {
        nameLabel.text  = model.name
        descLabel.text  = model.description
        usageLabel.text = "已使用 \(model.usageCount.formatted()) 次"
        previewView.gradientLayer.colors = model.gradientColors.map { $0.cgColor }
        // 每次都强制应用模式，避免 reuse 后状态残留
        applyMode(mode)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        applyMode(.grid)
    }

    // MARK: - 模式切换

    private func applyMode(_ mode: LayoutMode) {
        if mode == .grid {
            listWidthConstraint.isActive  = false
            outerStack.axis      = .vertical
            outerStack.spacing   = 8
            outerStack.alignment = .fill
            gridHeightConstraint.isActive = true
        } else {
            gridHeightConstraint.isActive = false
            outerStack.axis      = .horizontal
            outerStack.spacing   = 12
            outerStack.alignment = .fill
            listWidthConstraint.isActive  = true
        }
        descLabel.isHidden  = (mode == .grid)
        usageLabel.isHidden = (mode == .grid)
    }
}
