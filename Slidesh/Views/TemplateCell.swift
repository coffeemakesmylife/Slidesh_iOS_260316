//
//  TemplateCell.swift
//  Slidesh
//
//  模板 CollectionView Cell，支持网格/列表两种布局形态
//

import UIKit
import Kingfisher
import SkeletonView

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
    // 列表模式：120×90pt（cell 110pt，上下各 10pt 边距 = 90pt，与左边距等距）
    private lazy var listWidthConstraint  = previewImageView.widthAnchor.constraint(equalToConstant: 120)
    private lazy var listHeightConstraint = previewImageView.heightAnchor.constraint(equalToConstant: 90)
    // 列表→网格过渡期间使用固定高度，避免宽高比约束在大尺寸下提前生效
    private var gridTransitionHeightConstraint: NSLayoutConstraint?

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
        // SkeletonView：从 cell 到叶子视图全链路开启
        isSkeletonable            = true
        contentView.isSkeletonable = true
        outerStack.isSkeletonable  = true
        infoStack.isSkeletonable   = true
        previewImageView.isSkeletonable = true
        nameLabel.isSkeletonable   = true
        descLabel.isSkeletonable   = true
        usageLabel.isSkeletonable  = true

        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        contentView.backgroundColor = .appCardBackground.withAlphaComponent(0.65)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = .appTextPrimary
        nameLabel.numberOfLines = 2
        // 低拥抱优先级：让栈视图横向拉伸 nameLabel，骨架屏时宽度不会收缩到 0
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

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

    /// 控制选中边框高亮，供 TemplateSelectorViewController 在 didSelectItem 时调用
    func setSelectedState(_ selected: Bool) {
        contentView.layer.borderColor = selected
            ? UIColor.appPrimary.cgColor
            : UIColor.clear.cgColor
        contentView.layer.borderWidth = selected ? 2 : 0
    }

    func configure(with model: PPTTemplate, mode: LayoutMode) {
        nameLabel.text = model.subject
        descLabel.text = "\(model.num) " + NSLocalizedString("页", comment: "")
        usageLabel.text = model.category.isEmpty ? nil : model.category

        // Kingfisher 加载封面图：先显示骨架闪烁，加载完成后隐藏
        previewImageView.kf.cancelDownloadTask()
        previewImageView.image = nil
        if let url = model.coverImageURL {
            previewImageView.showAnimatedGradientSkeleton()
            previewImageView.kf.setImage(
                with: url,
                options: [.transition(.fade(0.2)), .cacheOriginalImage]
            ) { [weak self] _ in
                self?.previewImageView.hideSkeleton()
            }
        }

        // 每次都强制应用模式，避免 reuse 后状态残留
        applyMode(mode)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.kf.cancelDownloadTask()
        previewImageView.hideSkeleton()
        previewImageView.image = nil
        applyMode(.grid)
        setSelectedState(false)
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
            // .center 垂直居中：图片 90pt 高恰好填满 outerStack（cell 110 - 上下各 10 = 90）
            // 左/上/下边距均为 10pt
            outerStack.alignment = .center
            listWidthConstraint.isActive  = true
            listHeightConstraint.isActive = true
        }
        descLabel.isHidden  = (mode == .grid)
        usageLabel.isHidden = (mode == .grid)
    }

    /// 列表→网格过渡：用固定高度代替宽高比约束，避免动画起点过高
    func prepareForGridTransition(expectedImageHeight: CGFloat) {
        listWidthConstraint.isActive  = false
        listHeightConstraint.isActive = false
        gridHeightConstraint.isActive = false
        outerStack.axis      = .vertical
        outerStack.spacing   = 8
        outerStack.alignment = .fill
        gridTransitionHeightConstraint?.isActive = false
        gridTransitionHeightConstraint = previewImageView.heightAnchor.constraint(
            equalToConstant: expectedImageHeight)
        gridTransitionHeightConstraint?.isActive = true
        descLabel.isHidden  = true
        usageLabel.isHidden = true
    }

    /// 过渡动画结束后换回比例约束
    func activateProportionalGridConstraint() {
        gridTransitionHeightConstraint?.isActive = false
        gridTransitionHeightConstraint = nil
        gridHeightConstraint.isActive = true
    }
}
