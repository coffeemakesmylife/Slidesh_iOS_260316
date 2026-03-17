//
//  TemplateCell.swift
//  Slidesh
//
//  模板 CollectionView Cell，支持网格/列表两种布局形态
//

import UIKit

class TemplateCell: UICollectionViewCell {

    static let reuseID = "TemplateCell"

    // MARK: - 子视图

    private let previewView   = UIView()
    private let gradientLayer = CAGradientLayer()

    private let nameLabel  = UILabel()
    private let descLabel  = UILabel()
    private let usageLabel = UILabel()

    // 信息纵向堆叠（两种模式共用）
    private let infoStack = UIStackView()

    // 当前模式下的活跃约束组
    private var gridConstraints: [NSLayoutConstraint] = []
    private var listConstraints: [NSLayoutConstraint] = []
    private var currentMode: LayoutMode = .grid

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
    }

    // MARK: - 视图配置

    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        contentView.backgroundColor = .appCardBackground.withAlphaComponent(0.65)

        // 渐变预览
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        previewView.layer.addSublayer(gradientLayer)
        previewView.layer.cornerRadius = 12
        previewView.clipsToBounds = true
        previewView.translatesAutoresizingMaskIntoConstraints = false

        // 标题
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .appTextPrimary
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // 描述（列表模式使用）
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .appTextSecondary
        descLabel.numberOfLines = 2
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        // 使用次数（列表模式使用）
        usageLabel.font = .systemFont(ofSize: 11)
        usageLabel.textColor = .appTextTertiary
        usageLabel.translatesAutoresizingMaskIntoConstraints = false

        // 信息纵向堆叠
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .leading
        infoStack.addArrangedSubview(nameLabel)
        infoStack.addArrangedSubview(descLabel)
        infoStack.addArrangedSubview(usageLabel)
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(previewView)
        contentView.addSubview(infoStack)
    }

    private func setupConstraints() {
        let p = contentView

        // 网格：预览图上方，infoStack 在下
        gridConstraints = [
            previewView.topAnchor.constraint(equalTo: p.topAnchor, constant: 10),
            previewView.leadingAnchor.constraint(equalTo: p.leadingAnchor, constant: 10),
            previewView.trailingAnchor.constraint(equalTo: p.trailingAnchor, constant: -10),
            previewView.heightAnchor.constraint(equalTo: p.widthAnchor, multiplier: 0.62),

            infoStack.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 8),
            infoStack.leadingAnchor.constraint(equalTo: p.leadingAnchor, constant: 10),
            infoStack.trailingAnchor.constraint(equalTo: p.trailingAnchor, constant: -10),
            infoStack.bottomAnchor.constraint(lessThanOrEqualTo: p.bottomAnchor, constant: -10),
        ]

        // 列表：预览图左侧固定宽，infoStack 在右侧垂直居中
        listConstraints = [
            previewView.topAnchor.constraint(equalTo: p.topAnchor, constant: 10),
            previewView.leadingAnchor.constraint(equalTo: p.leadingAnchor, constant: 12),
            previewView.bottomAnchor.constraint(equalTo: p.bottomAnchor, constant: -10),
            previewView.widthAnchor.constraint(equalToConstant: 90),

            infoStack.leadingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: 12),
            infoStack.trailingAnchor.constraint(equalTo: p.trailingAnchor, constant: -12),
            infoStack.centerYAnchor.constraint(equalTo: p.centerYAnchor),
        ]

        // 默认激活网格约束
        NSLayoutConstraint.activate(gridConstraints)
    }

    // MARK: - 公开接口

    func configure(with model: TemplateModel, mode: LayoutMode) {
        nameLabel.text  = model.name
        descLabel.text  = model.description
        usageLabel.text = "已使用 \(model.usageCount.formatted()) 次"

        gradientLayer.colors = model.gradientColors.map { $0.cgColor }

        if mode != currentMode {
            applyMode(mode)
        }

        // 列表模式显示描述和使用量；网格模式隐藏
        descLabel.isHidden  = (mode == .grid)
        usageLabel.isHidden = (mode == .grid)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = previewView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 重置为网格模式，确保 configure() 每次正确切换
        currentMode = .grid
        NSLayoutConstraint.deactivate(listConstraints)
        NSLayoutConstraint.activate(gridConstraints)
    }

    // MARK: - 约束切换

    private func applyMode(_ mode: LayoutMode) {
        currentMode = mode
        if mode == .grid {
            NSLayoutConstraint.deactivate(listConstraints)
            NSLayoutConstraint.activate(gridConstraints)
        } else {
            NSLayoutConstraint.deactivate(gridConstraints)
            NSLayoutConstraint.activate(listConstraints)
        }
    }
}
