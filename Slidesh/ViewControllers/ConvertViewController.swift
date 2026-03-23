//
//  ConvertViewController.swift
//  Slidesh
//

import UIKit
import UniformTypeIdentifiers

// MARK: - 数据模型（顶层，避免 @MainActor 污染 Sendable 约束）

// 每个转换工具对应的 API 类型
enum ConvertToolKind: String, Sendable {
    case pdfToWord      // 精选卡，固定输出 WORD
    case pdfConvert     // PDF 多格式
    case mergePDF       // 合并 PDF
    case wordConvert
    case excelConvert
    case pptConvert
    case fileToImage
}

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
    let id            = UUID()
    let title:          String
    let subTitle:       String
    let icon:           String   // SF Symbol name
    let colorName:      String   // UIColor 由 UI 层解析，保持 Sendable
    let isFeatured:     Bool
    // 新增字段
    let kind:           ConvertToolKind
    let formatOptions:  [String]   // 空 = 无格式选择步骤
    let acceptedExtensions: [String] // 用于 UTType 文件过滤
    let allowsMultiple: Bool       // 合并PDF为true

    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
    nonisolated static func == (l: ConvertToolItem, r: ConvertToolItem) -> Bool { l.id == r.id }

    static let all: [ConvertSection: [ConvertToolItem]] = [
        .featured: [
            ConvertToolItem(title: "PDF 转 Word",
                            subTitle: "保持排版，精准转换，支持多种 OCR 识别",
                            icon: "doc.text.fill", colorName: "appPrimary", isFeatured: true,
                            kind: .pdfToWord, formatOptions: [],
                            acceptedExtensions: ["pdf"], allowsMultiple: false),
        ],
        .pdfTools: [
            ConvertToolItem(title: "PDF 转换器", subTitle: "转为 Word/Excel/PPT/HTML",
                            icon: "book.pages.fill", colorName: "systemRed", isFeatured: false,
                            kind: .pdfConvert,
                            formatOptions: ["WORD", "XML", "EXCEL", "PPT", "PNG", "HTML"],
                            acceptedExtensions: ["pdf"], allowsMultiple: false),
            ConvertToolItem(title: "合并 PDF", subTitle: "支持两份或多份文件合并",
                            icon: "plus.square.fill.on.square.fill", colorName: "systemBlue", isFeatured: false,
                            kind: .mergePDF, formatOptions: [],
                            acceptedExtensions: ["pdf"], allowsMultiple: true),
        ],
        .officeTools: [
            ConvertToolItem(title: "Word 转换", subTitle: "转为 PDF/HTML/PNG",
                            icon: "doc.richtext.fill", colorName: "systemIndigo", isFeatured: false,
                            kind: .wordConvert, formatOptions: ["PDF", "HTML", "PNG"],
                            acceptedExtensions: ["doc", "docx"], allowsMultiple: false),
            ConvertToolItem(title: "Excel 转换", subTitle: "转为 PDF/HTML/PNG",
                            icon: "tablecells.fill", colorName: "systemGreen", isFeatured: false,
                            kind: .excelConvert, formatOptions: ["PDF", "HTML", "PNG"],
                            acceptedExtensions: ["xls", "xlsx"], allowsMultiple: false),
            ConvertToolItem(title: "PPT 转换", subTitle: "转为 PDF/HTML/PNG",
                            icon: "tv.fill", colorName: "systemOrange", isFeatured: false,
                            kind: .pptConvert, formatOptions: ["PDF", "HTML", "PNG"],
                            acceptedExtensions: ["ppt", "pptx"], allowsMultiple: false),
        ],
        .utility: [
            ConvertToolItem(title: "文件转图片", subTitle: "将文档每一页提取为图片",
                            icon: "photo.on.rectangle.angled.fill", colorName: "systemTeal", isFeatured: false,
                            kind: .fileToImage, formatOptions: [],
                            acceptedExtensions: ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx"],
                            allowsMultiple: false),
        ],
    ]
}

// 文件私有函数，UI 层调用，解析 colorName 到 UIColor
private func resolveToolColor(_ name: String) -> UIColor {
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

// MARK: - ConvertViewController

class ConvertViewController: UIViewController {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<ConvertSection, ConvertToolItem>!

    // 文件选择过程中暂存工具和格式
    private var pendingTool:   ConvertToolItem?
    private var pendingFormat: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDataSource()
        applySnapshot()
    }

    private func setupUI() {
        navigationItem.title = "极速转换"
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(FeaturedCell.self,  forCellWithReuseIdentifier: FeaturedCell.reuseID)
        collectionView.register(ToolCell.self,       forCellWithReuseIdentifier: ToolCell.reuseID)
        collectionView.register(ConvertSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ConvertSectionHeader.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            guard let section = ConvertSection(rawValue: sectionIndex) else { return nil }
            switch section {
            case .featured: return Self.featuredSection()
            default:        return Self.gridSection()
            }
        }
    }

    private static func featuredSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(180)),
            subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 10, leading: 20, bottom: 24, trailing: 20)
        return section
    }

    private static func gridSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1)))
        item.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(144)),
            subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 12, bottom: 24, trailing: 12)
        let headerItem = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
        headerItem.contentInsets = .init(top: 8, leading: 8, bottom: 0, trailing: 8)
        section.boundarySupplementaryItems = [headerItem]
        return section
    }

    private func setupDataSource() {
        dataSource = .init(collectionView: collectionView) { cv, indexPath, item in
            if item.isFeatured {
                let cell = cv.dequeueReusableCell(
                    withReuseIdentifier: FeaturedCell.reuseID, for: indexPath) as! FeaturedCell
                cell.configure(with: item)
                return cell
            }
            let cell = cv.dequeueReusableCell(
                withReuseIdentifier: ToolCell.reuseID, for: indexPath) as! ToolCell
            cell.configure(with: item)
            return cell
        }
        dataSource.supplementaryViewProvider = { (cv: UICollectionView, kind: String, indexPath: IndexPath) in
            let header = cv.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: ConvertSectionHeader.reuseID,
                for: indexPath) as! ConvertSectionHeader
            header.configure(title: ConvertSection(rawValue: indexPath.section)?.title)
            return header
        }
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<ConvertSection, ConvertToolItem>()
        snap.appendSections(ConvertSection.allCases)
        for section in ConvertSection.allCases {
            snap.appendItems(ConvertToolItem.all[section] ?? [], toSection: section)
        }
        dataSource.apply(snap, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension ConvertViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        UISelectionFeedbackGenerator().selectionChanged()

        if item.formatOptions.isEmpty {
            // 无格式选项：直接选文件
            pendingTool   = item
            pendingFormat = nil
            openDocumentPicker(for: item)
        } else {
            // 有格式选项：先弹格式选择面板
            let sheet = FormatPickerSheet(formats: item.formatOptions)
            sheet.onSelect = { [weak self] format in
                guard let self else { return }
                self.pendingTool   = item
                self.pendingFormat = format
                self.openDocumentPicker(for: item)
            }
            present(sheet, animated: false)
        }
    }

    private func openDocumentPicker(for item: ConvertToolItem) {
        let types = item.acceptedExtensions.compactMap { UTType(filenameExtension: $0) }
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: types.isEmpty ? [.item] : types)
        picker.allowsMultipleSelection = item.allowsMultiple
        picker.delegate = self
        present(picker, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        UIView.animate(withDuration: 0.18) {
            collectionView.cellForItem(at: indexPath)?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        UIView.animate(withDuration: 0.18) {
            collectionView.cellForItem(at: indexPath)?.transform = .identity
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension ConvertViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let tool = pendingTool else { return }
        urls.forEach { _ = $0.startAccessingSecurityScopedResource() }
        let jobVC = ConvertJobViewController(tool: tool, outputFormat: pendingFormat)
        jobVC.prefillFiles(urls)
        navigationController?.pushViewController(jobVC, animated: true)
        pendingTool   = nil
        pendingFormat = nil
    }
}

// MARK: - FeaturedCell
// 精选大卡片：与 SettingsViewController VIP 卡片完全相同的渐变和边框，
// 使用 GradientFrameUpdater 解决初次渲染 frame=0 的问题

final class FeaturedCell: UICollectionViewCell {
    static let reuseID = "FeaturedCell"

    private let bgView     = UIView()
    private let gradLayer  = CAGradientLayer()
    private let iconBg     = UIView()
    private let iconView   = UIImageView()
    private let titleLabel = UILabel()
    private let subLabel   = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.backgroundColor = .clear

        // 卡片样式与 VIP 卡片一致
        bgView.layer.cornerRadius = 32
        bgView.clipsToBounds      = true
        bgView.layer.borderColor  = UIColor.white.withAlphaComponent(0.25).cgColor
        bgView.layer.borderWidth  = 2.0
        bgView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bgView)

        // 渐变颜色与 VIP 卡片完全一致，深浅模式均相同
        gradLayer.colors     = [UIColor.appGradientStart.cgColor,
                                UIColor.appGradientMid.cgColor,
                                UIColor.appGradientEnd.cgColor]
        gradLayer.locations  = [0.0, 0.55, 1.0]
        gradLayer.startPoint = CGPoint(x: 0, y: 0)
        gradLayer.endPoint   = CGPoint(x: 1, y: 1)
        bgView.layer.insertSublayer(gradLayer, at: 0)

        // 用 helper view 的 layoutSubviews 更新 gradLayer.frame，
        // 保证初次显示时 frame 就正确（与 SettingsViewController 相同方案）
        let updater = GradientFrameUpdater(gradLayer)
        updater.translatesAutoresizingMaskIntoConstraints = false
        bgView.insertSubview(updater, at: 0)
        NSLayoutConstraint.activate([
            updater.topAnchor.constraint(equalTo: bgView.topAnchor),
            updater.leadingAnchor.constraint(equalTo: bgView.leadingAnchor),
            updater.trailingAnchor.constraint(equalTo: bgView.trailingAnchor),
            updater.bottomAnchor.constraint(equalTo: bgView.bottomAnchor),
        ])

        // 图标背景
        iconBg.layer.cornerRadius = 20
        iconBg.backgroundColor    = UIColor.white.withAlphaComponent(0.22)
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(iconBg)

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor   = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        titleLabel.font          = .systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor     = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(titleLabel)

        subLabel.font          = .systemFont(ofSize: 14, weight: .medium)
        subLabel.textColor     = UIColor.white.withAlphaComponent(0.82)
        subLabel.numberOfLines = 2
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(subLabel)

        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bgView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bgView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconBg.topAnchor.constraint(equalTo: bgView.topAnchor, constant: 20),
            iconBg.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 20),
            iconBg.widthAnchor.constraint(equalToConstant: 52),
            iconBg.heightAnchor.constraint(equalToConstant: 52),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: bgView.trailingAnchor, constant: -20),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 20),
            subLabel.trailingAnchor.constraint(equalTo: bgView.trailingAnchor, constant: -20),
        ])
    }

    func configure(with item: ConvertToolItem) {
        titleLabel.text = item.title
        subLabel.text   = item.subTitle
        iconView.image  = UIImage(systemName: item.icon)
    }
}

// 与 SettingsViewController.GradientFrameUpdateView 相同原理：
// 通过 AutoLayout 将此 view 撑满容器，layoutSubviews 时更新 gradLayer.frame
private final class GradientFrameUpdater: UIView {
    private let grad: CAGradientLayer
    init(_ grad: CAGradientLayer) {
        self.grad = grad
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        grad.frame = bounds
    }
}

// MARK: - ToolCell
// 工具网格卡片：颜色系统全覆盖，边框随主题更新

final class ToolCell: UICollectionViewCell {
    static let reuseID = "ToolCell"

    private let iconBg      = UIView()
    private let iconView    = UIImageView()
    private let titleLabel  = UILabel()
    private let subLabel    = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // 卡片背景：动态颜色，自动适应深/浅模式
        contentView.backgroundColor = .appCardBackground.withAlphaComponent(0.65)
        contentView.layer.cornerRadius = 26
        contentView.layer.borderWidth  = 1

        iconBg.layer.cornerRadius = 15
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBg)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        titleLabel.font      = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subLabel.font          = .systemFont(ofSize: 12, weight: .regular)
        subLabel.textColor     = .appTextSecondary
        subLabel.numberOfLines = 2
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subLabel)

        NSLayoutConstraint.activate([
            iconBg.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])

        updateBorderColor()
    }

    func configure(with item: ConvertToolItem) {
        let color = resolveToolColor(item.colorName)
        titleLabel.text = item.title
        subLabel.text   = item.subTitle
        iconView.image  = UIImage(systemName: item.icon)
        iconView.tintColor        = color
        iconBg.backgroundColor   = color.withAlphaComponent(0.15)
    }

    // CALayer.borderColor 不支持动态 UIColor，需手动更新
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateBorderColor()
    }

    private func updateBorderColor() {
        contentView.layer.borderColor = UIColor.appCardBorder.cgColor
    }
}

// MARK: - ConvertSectionHeader
// 分区标题：左侧色块指示器 + 加粗标题，颜色均来自颜色系统

final class ConvertSectionHeader: UICollectionReusableView {
    static let reuseID = "ConvertSectionHeader"

    private let bar   = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        bar.layer.cornerRadius = 2
        bar.backgroundColor    = .appPrimary
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)

        label.font      = .systemFont(ofSize: 18, weight: .heavy)
        label.textColor = .appTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bar.centerYAnchor.constraint(equalTo: centerYAnchor),
            bar.widthAnchor.constraint(equalToConstant: 4),
            bar.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String?) { label.text = title }
}
