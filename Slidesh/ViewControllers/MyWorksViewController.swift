//
//  MyWorksViewController.swift
//  Slidesh
//
//  我的作品页：PPT 两列网格 + 大纲列表
//

import UIKit
import Kingfisher

// MARK: - PPT 网格 Cell

private class PPTGridCell: UICollectionViewCell {
    static let reuseID = "PPTGridCell"

    private let coverView  = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel  = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .appCardBackground.withAlphaComponent(0.7)
        bg.cornerRadius    = 14
        backgroundConfiguration = bg

        coverView.contentMode   = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.backgroundColor = .systemGray5
        coverView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coverView.layer.cornerRadius  = 14
        coverView.tintColor = .appPrimary.withAlphaComponent(0.4)
        coverView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font          = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor     = .appTextPrimary
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font      = .systemFont(ofSize: 11)
        dateLabel.textColor = .appTextSecondary
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(coverView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // 16:9 封面高度
            coverView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 9.0 / 16.0),

            titleLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            dateLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverView.kf.cancelDownloadTask()
        coverView.image = nil
    }

    func configure(with info: PPTInfo) {
        titleLabel.text = info.subject ?? NSLocalizedString("未命名", comment: "")
        // createTime 可能含 T 分隔符（如 "2026-03-21T10:59:00"），替换 T 为空格后截取前16字符
        if let t = info.createTime {
            let normalized = t.replacingOccurrences(of: "T", with: " ")
            dateLabel.text = normalized.count >= 16 ? String(normalized.prefix(16)) : normalized
        } else {
            dateLabel.text = nil
        }
        if let urlStr = info.coverUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
            // 使用 Kingfisher 加载封面，带缓存和淡入动画，无占位图
            coverView.kf.setImage(with: url, options: [
                .transition(.fade(0.25)),
                .cacheOriginalImage,
            ])
        }
    }
}

// MARK: - Section Header

private class WorksSectionHeader: UICollectionReusableView {
    static let reuseID = "WorksSectionHeader"
    private let bar        = UIView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        bar.layer.cornerRadius = 2
        bar.backgroundColor    = .appPrimary
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)

        titleLabel.font      = .systemFont(ofSize: 18, weight: .heavy)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            bar.centerYAnchor.constraint(equalTo: centerYAnchor),
            bar.widthAnchor.constraint(equalToConstant: 4),
            bar.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) { titleLabel.text = title }
}

// MARK: - MyWorksViewController

class MyWorksViewController: UIViewController {

    // PPT 来自服务端 list-me；大纲来自本地 WorksStore
    private var ppts:     [PPTInfo]       = []
    private var outlines: [OutlineRecord] = []
    // T6：记录进入页面次数，第3次且有作品时触发评分
    private var visitCount = 0
    private var collectionView: UICollectionView!

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"; return f
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("我的作品", comment: "")
        view.backgroundColor = .systemGroupedBackground
        addMeshGradientBackground()
        setupCollectionView()
        outlines = WorksStore.shared.outlines
        fetchPPTs()

        NotificationCenter.default.addObserver(
            self, selector: #selector(worksDidUpdate), name: .worksDidUpdate, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchPPTs()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        visitCount += 1
        // T6：第3次进入且已有 PPT 作品时触发
        if visitCount == 3, !ppts.isEmpty {
            RatingManager.shared.trigger(from: .myWorksThirdVisit)
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - 拉取 PPT 列表

    private func fetchPPTs() {
        PPTAPIService.shared.listMyPPTs { [weak self] result in
            guard let self else { return }
            if case .success(let list) = result {
                self.ppts = list
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.reloadData()
            }
        }
    }

    // MARK: - 布局

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.dataSource = self
        collectionView.delegate   = self

        collectionView.register(PPTGridCell.self,
            forCellWithReuseIdentifier: PPTGridCell.reuseID)
        collectionView.register(UICollectionViewListCell.self,
            forCellWithReuseIdentifier: "OutlineCell")
        collectionView.register(UICollectionViewCell.self,
            forCellWithReuseIdentifier: "PlaceholderCell")
        collectionView.register(WorksSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: WorksSectionHeader.reuseID)

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
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self else { return nil }
            return sectionIndex == 0 ? self.makePPTSection() : self.makeOutlineSection(env: env)
        }
    }

    private func makePPTSection() -> NSCollectionLayoutSection {
        let isEmpty = ppts.isEmpty
        // 空状态：单行全宽占位；有数据：两列网格
        let itemWidth: NSCollectionLayoutDimension = isEmpty ? .fractionalWidth(1.0) : .fractionalWidth(0.5)
        let groupHeight: CGFloat = isEmpty ? 80 : 190

        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: itemWidth, heightDimension: .fractionalHeight(1.0)))
        item.contentInsets = isEmpty
            ? NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            : NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(groupHeight)),
            subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        // leading/trailing=15 使格子单元格从 x=20(15+5) 开始，与 section header 指示器（x=20）对齐
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15)
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }

    private func makeOutlineSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = .clear
        let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
        section.boundarySupplementaryItems = [makeSectionHeader()]
        return section
    }

    private func makeSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(40)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
    }

    // MARK: - 数据

    @objc private func worksDidUpdate() {
        outlines = WorksStore.shared.outlines
        collectionView.reloadSections(IndexSet(integer: 1))
    }
}

// MARK: - UICollectionViewDataSource

extension MyWorksViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        section == 0 ? max(ppts.count, 1) : max(outlines.count, 1)
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            if ppts.isEmpty {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "PlaceholderCell", for: indexPath)
                cell.backgroundConfiguration = .clear()
                // tag=1 防止复用时重复添加子视图
                if cell.contentView.viewWithTag(1) == nil {
                    let icon = UIImageView(image: UIImage(systemName: "photo.on.rectangle.angled"))
                    icon.tintColor = .secondaryLabel
                    icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
                    icon.contentMode = .scaleAspectFit

                    let label = UILabel()
                    label.text      = NSLocalizedString("暂无 PPT 文件", comment: "")
                    label.textColor = .secondaryLabel
                    label.font      = .systemFont(ofSize: 14)

                    let stack = UIStackView(arrangedSubviews: [icon, label])
                    stack.tag       = 1
                    stack.axis      = .vertical
                    stack.alignment = .center
                    stack.spacing   = 8
                    stack.translatesAutoresizingMaskIntoConstraints = false
                    cell.contentView.addSubview(stack)
                    NSLayoutConstraint.activate([
                        stack.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                        stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    ])
                }
                return cell
            }
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PPTGridCell.reuseID, for: indexPath) as! PPTGridCell
            cell.configure(with: ppts[indexPath.item])
            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "OutlineCell", for: indexPath) as! UICollectionViewListCell
            var bg = UIBackgroundConfiguration.listGroupedCell()
            bg.backgroundColor = .appCardBackground.withAlphaComponent(0.7)
            cell.backgroundConfiguration = bg
            if outlines.isEmpty {
                var cfg = cell.defaultContentConfiguration()
                cfg.text = NSLocalizedString("暂无大纲记录", comment: "")
                cfg.textProperties.color = .secondaryLabel
                cell.contentConfiguration = cfg
                cell.accessories = []
            } else {
                let r = outlines[indexPath.item]
                var cfg = cell.defaultContentConfiguration()
                cfg.text          = r.subject
                cfg.secondaryText = Self.dateFormatter.string(from: r.savedAt)
                cfg.image         = UIImage(systemName: "list.bullet.rectangle")
                cell.contentConfiguration = cfg
                cell.accessories = [.disclosureIndicator()]
            }
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: WorksSectionHeader.reuseID,
            for: indexPath) as! WorksSectionHeader
        header.configure(title: indexPath.section == 0
            ? NSLocalizedString("PPT 文件（", comment: "") + "\(ppts.count)）"
            : NSLocalizedString("大纲（", comment: "") + "\(outlines.count)）")
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension MyWorksViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        if indexPath.section == 0, !ppts.isEmpty {
            let info = ppts[indexPath.item]
            navigationController?.pushViewController(PPTPreviewViewController(pptInfo: info, canChangeTemplate: true, source: .myWorks), animated: true)

        } else if indexPath.section == 1, !outlines.isEmpty {
            let r = outlines[indexPath.item]
            navigationController?.pushViewController(SavedOutlineViewController(record: r), animated: true)
        }
    }
}
