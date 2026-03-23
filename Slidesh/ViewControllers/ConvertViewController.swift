//
//  ConvertViewController.swift
//  Slidesh
//
//  Created by ted on 2026/03/22.
//

import UIKit

// MARK: - 数据模型（顶层类型，避免 @MainActor 污染 Sendable 约束）

enum ConvertSection: Int, CaseIterable, Sendable {
    case featured
    case pdfTools
    case officeTools
    case utility

    var title: String? {
        switch self {
        case .featured:    return nil
        case .pdfTools:    return "PDF 专家"
        case .officeTools: return "Office 转换"
        case .utility:     return "万能提取"
        }
    }
}

struct ConvertToolItem: Hashable, Sendable {
    let id       = UUID()
    let title:     String
    let subTitle:  String
    let icon:      String  // SF Symbol name
    let colorName: String  // 存颜色名称，UIColor 由 @MainActor extension 解析
    let isFeatured: Bool

    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
    nonisolated static func == (lhs: ConvertToolItem, rhs: ConvertToolItem) -> Bool { lhs.id == rhs.id }

    static let all: [ConvertSection: [ConvertToolItem]] = [
        .featured: [
            ConvertToolItem(title: "PDF 转 Word", subTitle: "保持排版，精准转换，支持多种 OCR 识别", icon: "doc.text.fill", colorName: "appPrimary", isFeatured: true)
        ],
        .pdfTools: [
            ConvertToolItem(title: "PDF 转换器", subTitle: "转为 Word/Excel/PPT/HTML", icon: "pdf.fill", colorName: "systemRed", isFeatured: false),
            ConvertToolItem(title: "合并 PDF", subTitle: "支持两份或多份文件合并", icon: "plus.square.fill.on.square.fill", colorName: "systemBlue", isFeatured: false)
        ],
        .officeTools: [
            ConvertToolItem(title: "Word 转换", subTitle: "转为 PDF/HTML/PNG", icon: "doc.richtext.fill", colorName: "systemIndigo", isFeatured: false),
            ConvertToolItem(title: "Excel 转换", subTitle: "转为 PDF/HTML/PNG", icon: "tablecells.fill", colorName: "systemGreen", isFeatured: false),
            ConvertToolItem(title: "PPT 转换", subTitle: "转为 PDF/HTML/PNG", icon: "tv.fill", colorName: "systemOrange", isFeatured: false)
        ],
        .utility: [
            ConvertToolItem(title: "文件转图片", subTitle: "将文档每一页提取为图片", icon: "photo.on.rectangle.angled.fill", colorName: "systemTeal", isFeatured: false)
        ]
    ]
}

// MARK: - 格式转换页

class ConvertViewController: UIViewController {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<ConvertSection, ConvertToolItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDataSource()
        applyInitialSnapshot()
    }

    private func setupUI() {
        navigationItem.title = "极速转换"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(ToolCardCell.self, forCellWithReuseIdentifier: ToolCardCell.reuseIdentifier)
        collectionView.register(FeaturedCardCell.self, forCellWithReuseIdentifier: FeaturedCardCell.featuredReuseIdentifier)
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderView.reuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let section = ConvertSection(rawValue: sectionIndex)!
            
            switch section {
            case .featured:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(180))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 24, trailing: 20)
                return layoutSection
                
            default:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(144))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 24, trailing: 12)
                
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
                header.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8)
                layoutSection.boundarySupplementaryItems = [header]
                
                return layoutSection
            }
        }
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<ConvertSection, ConvertToolItem>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, item: ConvertToolItem) -> UICollectionViewCell? in
            if item.isFeatured {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeaturedCardCell.featuredReuseIdentifier, for: indexPath) as! FeaturedCardCell
                cell.configure(with: item)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ToolCardCell.reuseIdentifier, for: indexPath) as! ToolCardCell
                cell.configure(with: item)
                return cell
            }
        }

        dataSource.supplementaryViewProvider = { (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.reuseIdentifier, for: indexPath) as! SectionHeaderView
            let section = ConvertSection(rawValue: indexPath.section)!
            header.titleLabel.text = section.title
            return header
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<ConvertSection, ConvertToolItem>()
        snapshot.appendSections(ConvertSection.allCases)
        for section in ConvertSection.allCases {
            if let items = ConvertToolItem.all[section] {
                snapshot.appendItems(items, toSection: section)
            }
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension ConvertViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        print("Selected tool: \(item.title)")
        
        // 触感反馈
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        // TODO: 根据接口文档跳转具体的转换逻辑页面
        let alert = UIAlertController(title: item.title, message: "功能开发中，敬请期待！", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    // 增加点击动画响应
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.2) {
                cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.2) {
                cell.transform = .identity
            }
        }
    }
}

// MARK: - 颜色名称解析（在主线程 UI 层调用）

private func resolveToolColor(name: String) -> UIColor {
    switch name {
    case "appPrimary":   return .appPrimary
    case "systemRed":    return .systemRed
    case "systemBlue":   return .systemBlue
    case "systemIndigo": return .systemIndigo
    case "systemGreen":  return .systemGreen
    case "systemOrange": return .systemOrange
    case "systemTeal":   return .systemTeal
    default:             return .appPrimary
    }
}

// MARK: - UI Components

class ToolCardCell: UICollectionViewCell {
    static let reuseIdentifier = "ToolCardCell"

    let bgView = UIView()
    let iconContainer = UIView()
    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    let subTitleLabel = UILabel()
    
    // 约束引用以便子类修改
    var iconSizeConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        contentView.backgroundColor = .clear
        
        bgView.backgroundColor = .appCardBackground
        bgView.layer.cornerRadius = 18
        bgView.layer.borderWidth = 1
        bgView.layer.borderColor = UIColor.appCardBorder.cgColor
        bgView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bgView)

        iconContainer.layer.cornerRadius = 12
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(iconContainer)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(titleLabel)

        subTitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subTitleLabel.textColor = .appTextSecondary
        subTitleLabel.numberOfLines = 2
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(subTitleLabel)

        iconSizeConstraints = [
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40)
        ]

        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bgView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bgView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconContainer.topAnchor.constraint(equalTo: bgView.topAnchor, constant: 16),
            iconContainer.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 16),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: bgView.trailingAnchor, constant: -16),

            subTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subTitleLabel.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 16),
            subTitleLabel.trailingAnchor.constraint(equalTo: bgView.trailingAnchor, constant: -16)
        ] + iconSizeConstraints)
    }

    func configure(with item: ConvertToolItem) {
        titleLabel.text = item.title
        subTitleLabel.text = item.subTitle
        iconImageView.image = UIImage(systemName: item.icon)
        let color = resolveToolColor(name: item.colorName)
        iconContainer.backgroundColor = color.withAlphaComponent(0.15)
        iconImageView.tintColor = color
    }
}

class FeaturedCardCell: ToolCardCell {
    static let featuredReuseIdentifier = "FeaturedCardCell"

    private let gradLayer = CAGradientLayer()

    override func setupUI() {
        super.setupUI()

        bgView.backgroundColor = .clear
        bgView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        bgView.layer.masksToBounds = true
        bgView.layer.cornerRadius = 20

        // 渐变背景，颜色随深/浅模式切换
        gradLayer.startPoint = CGPoint(x: 0, y: 0)
        gradLayer.endPoint = CGPoint(x: 1, y: 1)
        bgView.layer.insertSublayer(gradLayer, at: 0)

        titleLabel.textColor = .white
        subTitleLabel.textColor = .white.withAlphaComponent(0.8)
        titleLabel.font = .systemFont(ofSize: 24, weight: .heavy)
        subTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        iconContainer.backgroundColor = .white.withAlphaComponent(0.2)
        iconImageView.tintColor = .white

        NSLayoutConstraint.deactivate(iconSizeConstraints)
        iconSizeConstraints = [
            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56)
        ]
        NSLayoutConstraint.activate(iconSizeConstraints)

        for constraint in iconImageView.constraints {
            if constraint.firstAttribute == .width || constraint.firstAttribute == .height {
                constraint.constant = 30
            }
        }

        applyGradientColors()
    }

    // 浅色：主色深蓝 → 品牌中蓝；深色：深海蓝 → 中蓝，白色文字在两种模式下均可读
    private func applyGradientColors() {
        if traitCollection.userInterfaceStyle == .dark {
            gradLayer.colors = [UIColor.appGradientStart.cgColor, UIColor.appGradientMid.cgColor]
        } else {
            gradLayer.colors = [UIColor.appPrimary.cgColor, UIColor.appPrimaryLight.cgColor]
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            applyGradientColors()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradLayer.frame = bgView.bounds
    }
}

class SectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "SectionHeaderView"
    let titleLabel = UILabel()
    let indicator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        indicator.backgroundColor = .appPrimary
        indicator.layer.cornerRadius = 2
        indicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicator)

        titleLabel.font = .systemFont(ofSize: 18, weight: .heavy)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: 4),
            indicator.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
