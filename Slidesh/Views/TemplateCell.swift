//
//  TemplateCell.swift
//  Slidesh
//
//  模板 CollectionView Cell，支持网格/列表两种布局形态
//

import UIKit
import Kingfisher

class TemplateCell: UICollectionViewCell {

    static let reuseID = "TemplateCell"

    // MARK: - 子视图

    private let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        // 图片加载前显示的占位背景色
        iv.backgroundColor = .appChipUnselectedBackground
        return iv
    }()

    private let nameLabel   = UILabel()
    private let descLabel   = UILabel()
    private let usageLabel  = UILabel()
    private let infoStack   = UIStackView()
    // 外层栈：axis 切换实现网格/列表两种布局，替代 dual constraint 方案
    private let outerStack  = UIStackView()

    // 网格模式：预览图高度 ≈ 自身宽度 × 0.62
    private lazy var gridHeightConstraint = previewImageView.heightAnchor.constraint(
        equalTo: previewImageView.widthAnchor, multiplier: 0.62)
    // 列表模式：预览图固定宽度 90pt，高度 4:3（height = width × 0.75）
    private lazy var listWidthConstraint  = previewImageView.widthAnchor.constraint(equalToConstant: 90)
    private lazy var listHeightConstraint = previewImageView.heightAnchor.constraint(
        equalTo: previewImageView.widthAnchor, multiplier: 0.75)

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

        previewImageView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
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
        outerStack.addArrangedSubview(previewImageView)
        outerStack.addArrangedSubview(infoStack)
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(outerStack)

        // bottom 约束降为 high 优先级，配合 .estimated 高度让网格 cell 自适应内容高度
        let bottomConstraint = outerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        bottomConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            outerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            outerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            bottomConstraint,
        ])

        // 默认网格模式
        gridHeightConstraint.isActive = true
    }

    // MARK: - 公开接口

    func configure(with model: PPTTemplate, mode: LayoutMode) {
        nameLabel.text = model.subject
        descLabel.text = "\(model.num) 页"
        usageLabel.text = model.category.isEmpty ? nil : model.category

        // Kingfisher 加载封面图，加载中显示占位色
        previewImageView.kf.cancelDownloadTask()
        previewImageView.image = nil
        if let url = model.coverImageURL {
            previewImageView.kf.setImage(
                with: url,
                options: [.transition(.fade(0.2)), .cacheOriginalImage]
            )
        }

        // 每次都强制应用模式，避免 reuse 后状态残留
        applyMode(mode)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.kf.cancelDownloadTask()
        previewImageView.image = nil
        applyMode(.grid)
    }

    // MARK: - 模式切换

    // 供 VC 在布局切换时直接更新可见 cell（animated layout transition 期间 reloadData 不可靠）
    func applyMode(_ mode: LayoutMode) {
        if mode == .grid {
            listWidthConstraint.isActive  = false
            listHeightConstraint.isActive = false
            outerStack.axis      = .vertical
            outerStack.spacing   = 8
            outerStack.alignment = .fill
            gridHeightConstraint.isActive = true
        } else {
            gridHeightConstraint.isActive = false
            outerStack.axis      = .horizontal
            outerStack.spacing   = 12
            outerStack.alignment = .center  // 垂直居中，图片不拉伸
            listWidthConstraint.isActive  = true
            listHeightConstraint.isActive = true  // 4:3 比例
        }
        descLabel.isHidden  = (mode == .grid)
        usageLabel.isHidden = (mode == .grid)
    }
}
