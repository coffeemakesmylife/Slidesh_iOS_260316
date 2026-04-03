//
//  AppIconPickerViewController.swift
//  Slidesh
//
//  应用图标选择器：三列网格，当前图标高亮 + 选中后立即切换
//

import UIKit

final class AppIconPickerViewController: UIViewController {

    private let manager = AppIconManager.shared
    private var collectionView: UICollectionView!

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "应用图标"
        addMeshGradientBackground()
        setupCollectionView()
    }

    // MARK: - 布局

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero,
                                          collectionViewLayout: makeLayout())
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.register(IconCell.self, forCellWithReuseIdentifier: IconCell.reuseID)
        collectionView.contentInset = UIEdgeInsets(top: 24, left: 0, bottom: 24, right: 0)
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
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3),
                                              heightDimension: .fractionalWidth(1/3) )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .fractionalWidth(1/3))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        return UICollectionViewCompositionalLayout(section: section)
    }
}

// MARK: - UICollectionViewDataSource

extension AppIconPickerViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        manager.icons.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: IconCell.reuseID, for: indexPath) as! IconCell
        let entry = manager.icons[indexPath.item]
        let isSelected = entry.identifier == manager.currentIdentifier
        cell.configure(image: manager.previewImage(for: entry),
                       name: entry.displayName,
                       isCurrentIcon: isSelected)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension AppIconPickerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let entry = manager.icons[indexPath.item]
        guard entry.identifier != manager.currentIdentifier else { return }

        if !manager.supportsAlternateIcons {
            let alert = UIAlertController(title: "不支持", message: "当前设备不支持更换应用图标。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }

        manager.setIcon(entry.identifier) { [weak self] success in
            guard let self, success else { return }
            // 系统会弹出无法屏蔽的 alert，这里延迟 0.5s 再刷新，避免和系统 alert 冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.collectionView.reloadData()
            }
        }
    }
}

// MARK: - IconCell

private final class IconCell: UICollectionViewCell {
    static let reuseID = "IconCell"

    private let iconView     = UIImageView()
    private let nameLabel    = UILabel()
    private let checkmark    = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 圆角图标，和系统 App 图标风格一致
        iconView.contentMode   = .scaleAspectFill
        iconView.clipsToBounds = true
        iconView.backgroundColor = .systemGray5
        iconView.layer.cornerRadius = 16
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font          = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor     = .appTextSecondary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // 选中时右下角打勾
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        checkmark.image         = UIImage(systemName: "checkmark.circle.fill", withConfiguration: cfg)
        checkmark.tintColor     = .appGradientMid
        checkmark.backgroundColor = .white
        checkmark.layer.cornerRadius = 11
        checkmark.clipsToBounds = true
        checkmark.isHidden      = true
        checkmark.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkmark)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            checkmark.widthAnchor.constraint(equalToConstant: 22),
            checkmark.heightAnchor.constraint(equalToConstant: 22),
            checkmark.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            checkmark.bottomAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(image: UIImage?, name: String, isCurrentIcon: Bool) {
        iconView.image      = image
        nameLabel.text      = name
        checkmark.isHidden  = !isCurrentIcon

        // 当前图标加边框描边
        iconView.layer.borderWidth = isCurrentIcon ? 2.5 : 0
        iconView.layer.borderColor = isCurrentIcon ? UIColor.appGradientMid.cgColor : nil
    }
}
