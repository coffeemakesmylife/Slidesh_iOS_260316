//
//  ParamsPickerViewController.swift
//  Slidesh
//
//  参数选择面板：页数、语言、场景、受众，配合 UISheetPresentationController medium detent 使用
//

import UIKit

class ParamsPickerViewController: UIViewController {

    // MARK: - 静态数据

    static let pageCounts: [Int]    = [5, 8, 10, 15, 20, 25, 30]
    static let languages:  [String] = ["中文", "English", "日本語", "한국어", "Français", "Español"]
    static let scenes:     [String] = ["通用", "商务", "教育", "科技", "医疗", "创意"]
    static let audiences:  [String] = ["通用", "学生", "职场人士", "管理层", "投资人", "客户"]

    // MARK: - 选择结果

    struct Selection {
        var pageIndex:     Int = 2  // 默认 10 页
        var languageIndex: Int = 0  // 默认中文
        var sceneIndex:    Int = 0  // 默认通用
        var audienceIndex: Int = 0  // 默认通用

        var pageCount: Int    { ParamsPickerViewController.pageCounts[pageIndex] }
        var language:  String { ParamsPickerViewController.languages[languageIndex] }
        var scene:     String { ParamsPickerViewController.scenes[sceneIndex] }
        var audience:  String { ParamsPickerViewController.audiences[audienceIndex] }
    }

    var onConfirm: ((Selection) -> Void)?
    private var selection: Selection

    // MARK: - 子视图

    // 每个 section 的 CollectionView，按 tag 0-3 区分
    private var sectionCollections: [UICollectionView] = []

    // Section 元数据
    private struct SectionMeta {
        let title: String
        let options: [String]
        let columns: Int
    }

    private lazy var sections: [SectionMeta] = [
        SectionMeta(title: "页数",
                    options: Self.pageCounts.map { "\($0) 页" },
                    columns: 4),
        SectionMeta(title: "语言",
                    options: Self.languages,
                    columns: 3),
        SectionMeta(title: "场景",
                    options: Self.scenes,
                    columns: 3),
        SectionMeta(title: "受众",
                    options: Self.audiences,
                    columns: 3),
    ]

    // MARK: - Init

    init(selection: Selection) {
        self.selection = selection
        super.init(nibName: nil, bundle: nil)
        // 不设置 overFullScreen，交由 sheetPresentationController 管理
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackgroundSecondary
        buildContent()
    }

    // 关闭时（完成按钮或手势下滑）均触发回调
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            onConfirm?(selection)
        }
    }

    // MARK: - 内容布局

    private func buildContent() {
        // 标题行
        let titleLabel = UILabel()
        titleLabel.text      = "参数设置"
        titleLabel.font      = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // 完成按钮
        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle("完成", for: .normal)
        doneBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        doneBtn.tintColor = .appPrimary
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(doneBtn)

        // 纵向滚动视图（容纳所有 section）
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis    = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // 添加四个 section
        for (idx, meta) in sections.enumerated() {
            let sectionView = buildSection(meta: meta, tag: idx)
            contentStack.addArrangedSubview(sectionView)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            doneBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    // 构建单个参数 section
    private func buildSection(meta: SectionMeta, tag: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Section 标题
        let header = UILabel()
        header.text      = meta.title
        header.font      = .systemFont(ofSize: 13, weight: .medium)
        header.textColor = .appTextSecondary
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        // CollectionView（不可滚动，高度由内容决定）
        let layout = makeSectionLayout(columns: meta.columns)
        let cv     = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.register(InlineChipCell.self, forCellWithReuseIdentifier: InlineChipCell.reuseID)
        cv.dataSource = self
        cv.delegate   = self
        cv.tag        = tag
        cv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cv)
        sectionCollections.append(cv)

        // 计算 CollectionView 固定高度
        let rows  = Int(ceil(Double(meta.options.count) / Double(meta.columns)))
        let chipH: CGFloat  = 36
        let rowGap: CGFloat = 8
        let cvH = CGFloat(rows) * chipH + CGFloat(max(rows - 1, 0)) * rowGap

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            cv.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            cv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cv.heightAnchor.constraint(equalToConstant: cvH),
            cv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeSectionLayout(columns: Int) -> UICollectionViewLayout {
        let fraction  = 1.0 / CGFloat(columns)
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction),
                                               heightDimension: .absolute(36))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(36))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    // 当前 section 的选中 index
    private func selectedIndex(for tag: Int) -> Int {
        switch tag {
        case 0: return selection.pageIndex
        case 1: return selection.languageIndex
        case 2: return selection.sceneIndex
        case 3: return selection.audienceIndex
        default: return 0
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension ParamsPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        sections[collectionView.tag].options.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: InlineChipCell.reuseID, for: indexPath) as! InlineChipCell
        let option   = sections[collectionView.tag].options[indexPath.item]
        let selected = indexPath.item == selectedIndex(for: collectionView.tag)
        cell.configure(title: option, selected: selected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        switch collectionView.tag {
        case 0: selection.pageIndex     = indexPath.item
        case 1: selection.languageIndex = indexPath.item
        case 2: selection.sceneIndex    = indexPath.item
        case 3: selection.audienceIndex = indexPath.item
        default: break
        }
        collectionView.reloadData()
    }
}

// MARK: - InlineChipCell

private class InlineChipCell: UICollectionViewCell {

    static let reuseID = "InlineChipCell"

    private let label         = UILabel()
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds      = true

        gradientLayer.colors     = [UIColor.appGradientStart.cgColor,
                                    UIColor.appGradientMid.cgColor,
                                    UIColor.appGradientEnd.cgColor]
        gradientLayer.locations  = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.isHidden   = true
        contentView.layer.insertSublayer(gradientLayer, at: 0)

        label.font          = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -4),
        ])
    }

    func configure(title: String, selected: Bool) {
        label.text                  = title
        gradientLayer.isHidden      = !selected
        // 未选中使用三级背景色（白/深蓝灰），选中使用渐变
        contentView.backgroundColor = selected ? .clear : .appBackgroundTertiary
        label.textColor             = selected ? .white : .appTextPrimary
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }
}
