//
//  AppIconPickerViewController.swift
//  Slidesh
//
//  应用图标选择器：三列网格，选中动画 + 阴影
//

import UIKit

final class AppIconPickerViewController: UIViewController {

    private let manager = AppIconManager.shared
    private var collectionView: UICollectionView!

    // 记录当前选中的 identifier，用于精准更新 cell 而不 reloadData
    private var currentIdentifier: String? {
        get { manager.currentIdentifier }
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("应用图标", comment: "")
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
        // 关闭系统选中样式，由 cell 自己控制
        collectionView.allowsSelection = true
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
                                              heightDimension: .fractionalWidth(1/3))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .fractionalWidth(1/3))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 24
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
        let entry   = manager.icons[indexPath.item]
        let isSelected = entry.identifier == currentIdentifier
        cell.configure(image: manager.previewImage(for: entry),
                       name: entry.displayName,
                       isCurrentIcon: isSelected,
                       animated: false)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension AppIconPickerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let entry = manager.icons[indexPath.item]
        guard entry.identifier != currentIdentifier else { return }

        if !manager.supportsAlternateIcons {
            let alert = UIAlertController(title: NSLocalizedString("不支持", comment: ""), message: NSLocalizedString("当前设备不支持更换应用图标。", comment: ""),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }

        // 立即更新所有 cell 的选中状态（乐观更新，系统 alert 弹出前给出视觉反馈）
        animateSelection(to: indexPath)

        manager.setIcon(entry.identifier) { [weak self] success in
            guard let self else { return }
            // 系统强制弹出 alert 期间等待 0.5s 再做最终同步，防止闪烁
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.syncSelectionState()
            }
        }
    }

    // 立即用动画切换选中外观，不 reloadData
    private func animateSelection(to selectedIndexPath: IndexPath) {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? IconCell else { continue }
            let entry = manager.icons[indexPath.item]
            let shouldBeSelected = (indexPath == selectedIndexPath)
            // 只对状态有变化的 cell 执行动画
            let currentlySelected = entry.identifier == currentIdentifier
            if shouldBeSelected != currentlySelected {
                cell.setIconSelected(shouldBeSelected, animated: true)
            }
        }
    }

    // 切换完成后以真实状态同步所有可见 cell
    private func syncSelectionState() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? IconCell else { continue }
            let entry = manager.icons[indexPath.item]
            cell.setIconSelected(entry.identifier == currentIdentifier, animated: false)
        }
    }
}

// MARK: - IconCell

private final class IconCell: UICollectionViewCell {
    static let reuseID = "IconCell"

    // shadowWrapper：承载阴影，不裁切
    private let shadowWrapper = UIView()
    // iconView：裁切圆角，在 shadowWrapper 内
    private let iconView      = UIImageView()
    // 图片为 nil 时展示的渐变兜底（模拟 App 图标样式）
    private let gradientLayer = CAGradientLayer()
    private let nameLabel     = UILabel()
    private let checkmark     = UIImageView()

    private var isIconSelected = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        // ---- shadowWrapper ----
        shadowWrapper.layer.cornerRadius  = 16
        shadowWrapper.layer.shadowColor   = UIColor.black.cgColor
        shadowWrapper.layer.shadowOpacity = 0.18
        shadowWrapper.layer.shadowOffset  = CGSize(width: 0, height: 4)
        shadowWrapper.layer.shadowRadius  = 8
        shadowWrapper.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shadowWrapper)

        // ---- iconView（在 shadowWrapper 内）----
        iconView.contentMode   = .scaleAspectFill
        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 16
        iconView.translatesAutoresizingMaskIntoConstraints = false
        shadowWrapper.addSubview(iconView)

        // 渐变兜底（图片读取失败时显示 App 主题渐变）
        gradientLayer.colors = [
            UIColor.appGradientStart.cgColor,
            UIColor.appGradientMid.cgColor,
            UIColor.appGradientEnd.cgColor,
        ]
        gradientLayer.locations  = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.isHidden   = true
        iconView.layer.insertSublayer(gradientLayer, at: 0)

        // ---- 名称标签 ----
        nameLabel.font          = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor     = .appTextSecondary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        // ---- 选中角标 ----
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        checkmark.image              = UIImage(systemName: "checkmark.circle.fill", withConfiguration: cfg)
        checkmark.tintColor          = .appGradientMid
        checkmark.backgroundColor    = .white
        checkmark.layer.cornerRadius = 11
        checkmark.clipsToBounds      = true
        checkmark.alpha              = 0
        checkmark.transform          = CGAffineTransform(scaleX: 0.5, y: 0.5)
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkmark)

        NSLayoutConstraint.activate([
            // shadowWrapper 填满 iconView 区域
            shadowWrapper.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowWrapper.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shadowWrapper.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            shadowWrapper.heightAnchor.constraint(equalTo: shadowWrapper.widthAnchor),

            // iconView 填满 shadowWrapper
            iconView.topAnchor.constraint(equalTo: shadowWrapper.topAnchor),
            iconView.leadingAnchor.constraint(equalTo: shadowWrapper.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor),
            iconView.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor),

            // 名称标签
            nameLabel.topAnchor.constraint(equalTo: shadowWrapper.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // 角标右下角，稍微溢出 shadowWrapper
            checkmark.widthAnchor.constraint(equalToConstant: 22),
            checkmark.heightAnchor.constraint(equalToConstant: 22),
            checkmark.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor, constant: 4),
            checkmark.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor, constant: 4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = iconView.bounds
    }

    // MARK: - 配置

    func configure(image: UIImage?, name: String, isCurrentIcon: Bool, animated: Bool) {
        if let img = image {
            iconView.image         = img
            gradientLayer.isHidden = true
        } else {
            iconView.image         = nil
            gradientLayer.isHidden = false
        }
        nameLabel.text = name
        isIconSelected = isCurrentIcon
        applySelectionStyle(selected: isCurrentIcon, animated: animated)
    }

    func setIconSelected(_ selected: Bool, animated: Bool) {
        guard isIconSelected != selected else { return }
        isIconSelected = selected
        applySelectionStyle(selected: selected, animated: animated)
    }

    // MARK: - 选中样式动画

    private func applySelectionStyle(selected: Bool, animated: Bool) {
        let targetBorderWidth: CGFloat = selected ? 2.5 : 0
        let targetBorderColor = selected ? UIColor.appGradientMid.cgColor : UIColor.clear.cgColor
        let targetCheckAlpha: CGFloat  = selected ? 1 : 0
        let targetCheckScale           = selected ? CGAffineTransform.identity
                                                  : CGAffineTransform(scaleX: 0.5, y: 0.5)

        if animated {
            UIView.animate(withDuration: 0.25,
                           delay: 0,
                           usingSpringWithDamping: 0.65,
                           initialSpringVelocity: 0.5) {
                self.iconView.layer.borderWidth = targetBorderWidth
                self.iconView.layer.borderColor = targetBorderColor
                self.checkmark.alpha            = targetCheckAlpha
                self.checkmark.transform        = targetCheckScale
            }
        } else {
            iconView.layer.borderWidth = targetBorderWidth
            iconView.layer.borderColor = targetBorderColor
            checkmark.alpha            = targetCheckAlpha
            checkmark.transform        = targetCheckScale
        }
    }
}
