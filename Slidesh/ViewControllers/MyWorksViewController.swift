//
//  MyWorksViewController.swift
//  Slidesh
//
//  我的作品页：PPT 两列网格 + 大纲列表
//

import UIKit

// MARK: - PPT 网格 Cell

private class PPTGridCell: UICollectionViewCell {
    static let reuseID = "PPTGridCell"

    private let coverView  = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel  = UILabel()
    private var imageTask:  URLSessionDataTask?

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
        coverView.image     = UIImage(systemName: "doc.richtext.fill")
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

            titleLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            dateLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        coverView.image = UIImage(systemName: "doc.richtext.fill")
    }

    func configure(with record: PPTRecord, dateText: String) {
        titleLabel.text = record.subject
        dateLabel.text  = dateText
        if let urlStr = record.coverUrl, let url = URL(string: urlStr) {
            imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { self?.coverView.image = img }
            }
            imageTask?.resume()
        }
    }
}

// MARK: - Section Header

private class WorksSectionHeader: UICollectionReusableView {
    static let reuseID = "WorksSectionHeader"
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font      = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) { titleLabel.text = title }
}

// MARK: - MyWorksViewController

class MyWorksViewController: UIViewController {

    private var ppts:     [PPTRecord]     = []
    private var outlines: [OutlineRecord] = []
    private var collectionView: UICollectionView!

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"; return f
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "我的作品"
        view.backgroundColor = .systemGroupedBackground
        addMeshGradientBackground()
        setupCollectionView()
        reloadData()

        NotificationCenter.default.addObserver(
            self, selector: #selector(worksDidUpdate), name: .worksDidUpdate, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

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
        let groupHeight: CGFloat = isEmpty ? 44 : 180

        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: itemWidth, heightDimension: .fractionalHeight(1.0)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(groupHeight)),
            subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 11, bottom: 8, trailing: 11)
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

    private func reloadData() {
        ppts     = WorksStore.shared.ppts
        outlines = WorksStore.shared.outlines
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }

    @objc private func worksDidUpdate() {
        DispatchQueue.main.async { self.reloadData() }
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
                var cfg = UIListContentConfiguration.cell()
                cfg.text = "暂无 PPT 记录"
                cfg.textProperties.color     = .secondaryLabel
                cfg.textProperties.alignment = .center
                cell.contentConfiguration = cfg
                cell.backgroundColor = .clear
                return cell
            }
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PPTGridCell.reuseID, for: indexPath) as! PPTGridCell
            let r = ppts[indexPath.item]
            cell.configure(with: r, dateText: Self.dateFormatter.string(from: r.savedAt))
            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "OutlineCell", for: indexPath) as! UICollectionViewListCell
            if outlines.isEmpty {
                var cfg = cell.defaultContentConfiguration()
                cfg.text = "暂无大纲记录"
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
            ? "PPT 文件（\(ppts.count)）"
            : "大纲（\(outlines.count)）")
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension MyWorksViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        if indexPath.section == 0, !ppts.isEmpty {
            let r    = ppts[indexPath.item]
            let info = PPTInfo(pptId: r.id, taskId: r.taskId, subject: r.subject,
                               fileUrl: r.fileUrl, coverUrl: r.coverUrl,
                               status: "SUCCESS", total: nil)
            navigationController?.pushViewController(PPTPreviewViewController(pptInfo: info), animated: true)

        } else if indexPath.section == 1, !outlines.isEmpty {
            let r = outlines[indexPath.item]
            navigationController?.pushViewController(SavedOutlineViewController(record: r), animated: true)
        }
    }
}
