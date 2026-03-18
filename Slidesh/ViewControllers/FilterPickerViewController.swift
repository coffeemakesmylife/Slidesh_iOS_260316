//
//  FilterPickerViewController.swift
//  Slidesh
//
//  自定义底部弹出筛选面板，参考截图风格
//  选中用品牌渐变，未选中用 appChip 颜色系统色
//

import UIKit

class FilterPickerViewController: UIViewController {

    // MARK: - 公开接口

    /// 选中某项后回调（index 为 allCases 下标）
    var onSelect: ((Int) -> Void)?

    // MARK: - 私有属性

    private let pickerTitle: String
    private let options: [String]
    private var selectedIndex: Int
    /// 非 nil 时启用色块模式；每个元素对应 options 中同位置的颜色，nil 表示"全部"用品牌渐变
    private let colorSwatches: [UIColor?]?

    private let dimView   = UIView()
    private let panelView = UIView()
    private let titleLabel = UILabel()
    private var collectionView: UICollectionView!
    private var panelBottomConstraint: NSLayoutConstraint!

    // MARK: - Init

    init(title: String, options: [String], selectedIndex: Int, colorSwatches: [UIColor?]? = nil) {
        self.pickerTitle   = title
        self.options       = options
        self.selectedIndex = selectedIndex
        self.colorSwatches = colorSwatches
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupDim()
        setupPanel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 面板从屏幕外滑入
        panelBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.38, delay: 0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.6,
                       options: .curveEaseOut) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - UI 搭建

    private func setupDim() {
        dimView.backgroundColor = .appOverlay
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissPicker)))
        UIView.animate(withDuration: 0.22) { self.dimView.alpha = 1 }
    }

    private func setupPanel() {
        panelView.backgroundColor = .appBackgroundSecondary
        panelView.layer.cornerRadius = 26
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)

        // 初始位置在屏幕下方
        panelBottomConstraint = panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 500)
        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelBottomConstraint,
        ])

        // 拖拽手势关闭
        panelView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))

        setupPanelContent()
    }

    private func setupPanelContent() {
        // 顶部拖拽指示条
        let indicator = UIView()
        indicator.backgroundColor = .appTextTertiary.withAlphaComponent(0.4)
        indicator.layer.cornerRadius = 2.5
        indicator.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 10),
            indicator.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            indicator.widthAnchor.constraint(equalToConstant: 36),
            indicator.heightAnchor.constraint(equalToConstant: 5),
        ])

        // 标题
        titleLabel.text = pickerTitle
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 20),
        ])

        // 选项集合视图：色块模式用 5 列 64pt，文字模式用 4 列 40pt
        let isSwatchMode = colorSwatches != nil
        collectionView = UICollectionView(frame: .zero,
                                          collectionViewLayout: isSwatchMode ? makeSwatchLayout() : makeChipLayout())
        collectionView.backgroundColor = .clear
        if isSwatchMode {
            collectionView.register(ColorSwatchCell.self, forCellWithReuseIdentifier: ColorSwatchCell.reuseID)
        } else {
            collectionView.register(PickerChipCell.self, forCellWithReuseIdentifier: PickerChipCell.reuseID)
        }
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(collectionView)

        // 色块模式：5 列，行高 64pt；文字模式：4 列，行高 40pt
        let columns: Int    = isSwatchMode ? 5 : 4
        let chipH: CGFloat  = isSwatchMode ? 64 : 40
        let rowGap: CGFloat = 10
        let rows    = Int(ceil(Double(options.count) / Double(columns)))
        let collH   = CGFloat(rows) * chipH + CGFloat(max(rows - 1, 0)) * rowGap

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
            collectionView.heightAnchor.constraint(equalToConstant: collH),
            collectionView.bottomAnchor.constraint(equalTo: panelView.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func makeSwatchLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.2),
                                               heightDimension: .absolute(64))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(64))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func makeChipLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25),
                                               heightDimension: .absolute(40))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(40))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - 关闭动画

    @objc private func dismissPicker() {
        panelBottomConstraint.constant = 500
        UIView.animate(withDuration: 0.28, animations: {
            self.dimView.alpha = 0
            self.view.layoutIfNeeded()
        }) { _ in
            self.dismiss(animated: false)
        }
    }

    // MARK: - 拖拽手势关闭

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view).y
        switch gesture.state {
        case .changed:
            if translation > 0 {
                panelBottomConstraint.constant = -translation
                view.layoutIfNeeded()
            }
        case .ended, .cancelled:
            if translation > 80 {
                dismissPicker()
            } else {
                panelBottomConstraint.constant = 0
                UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
            }
        default: break
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension FilterPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int { options.count }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let isSelected = indexPath.item == selectedIndex
        if let swatches = colorSwatches {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ColorSwatchCell.reuseID, for: indexPath) as! ColorSwatchCell
            cell.configure(title: options[indexPath.item],
                           color: swatches[indexPath.item],
                           selected: isSelected)
            return cell
        }
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PickerChipCell.reuseID, for: indexPath) as! PickerChipCell
        cell.configure(title: options[indexPath.item], selected: isSelected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.item
        collectionView.reloadData()
        // 短暂停留后关闭，让选中动画可见
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.onSelect?(indexPath.item)
            self.dismissPicker()
        }
    }
}

// MARK: - ColorSwatchCell（色块模式）

private class ColorSwatchCell: UICollectionViewCell {

    static let reuseID = "ColorSwatchCell"

    // 色块直径固定 34pt
    private static let diameter: CGFloat = 34

    private let circleView    = UIView()
    private let gradientLayer = CAGradientLayer()
    private let checkmark     = UIImageView()
    private let titleLabel    = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let d = Self.diameter

        // 圆形：固定 cornerRadius，避免依赖 layoutSubviews 时机
        circleView.layer.cornerRadius = d / 2
        circleView.clipsToBounds      = true
        circleView.layer.borderWidth  = 2.5
        circleView.layer.borderColor  = UIColor.clear.cgColor
        circleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(circleView)

        // 品牌渐变（全部颜色），frame 在 setup 时直接给定，不依赖 layoutSubviews
        gradientLayer.colors     = [UIColor.appGradientStart.cgColor,
                                    UIColor.appGradientMid.cgColor,
                                    UIColor.appGradientEnd.cgColor]
        gradientLayer.locations  = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.frame      = CGRect(x: 0, y: 0, width: d, height: d)
        gradientLayer.isHidden   = true
        circleView.layer.insertSublayer(gradientLayer, at: 0)

        // 选中对勾
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        checkmark.image     = UIImage(systemName: "checkmark", withConfiguration: config)
        checkmark.tintColor = .white
        checkmark.isHidden  = true
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        circleView.addSubview(checkmark)

        // 颜色名称标签
        titleLabel.font          = .systemFont(ofSize: 11)
        titleLabel.textColor     = .appTextSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            circleView.widthAnchor.constraint(equalToConstant: d),
            circleView.heightAnchor.constraint(equalToConstant: d),

            checkmark.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    func configure(title: String, color: UIColor?, selected: Bool) {
        titleLabel.text = title

        if let c = color {
            circleView.backgroundColor = c
            gradientLayer.isHidden = true
        } else {
            // 全部颜色：显示品牌渐变
            circleView.backgroundColor = .clear
            gradientLayer.isHidden = false
        }

        checkmark.isHidden = !selected

        // 选中描边直接用 circleView.layer.borderColor（坐标系始终正确）
        circleView.layer.borderColor = selected
            ? (color ?? .white).withAlphaComponent(0.55).cgColor
            : UIColor.clear.cgColor

        titleLabel.textColor = selected ? .appTextPrimary : .appTextSecondary
        titleLabel.font = selected
            ? .systemFont(ofSize: 11, weight: .semibold)
            : .systemFont(ofSize: 11)
    }
}

// MARK: - PickerChipCell

private class PickerChipCell: UICollectionViewCell {

    static let reuseID = "PickerChipCell"

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
        contentView.layer.cornerRadius = 20
        contentView.clipsToBounds = true

        // 品牌渐变层（选中时显示）
        gradientLayer.colors     = [UIColor.appGradientStart.cgColor,
                                    UIColor.appGradientMid.cgColor,
                                    UIColor.appGradientEnd.cgColor]
        gradientLayer.locations  = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.isHidden   = true
        contentView.layer.insertSublayer(gradientLayer, at: 0)

        label.font          = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func configure(title: String, selected: Bool) {
        label.text = title
        gradientLayer.isHidden     = !selected
        contentView.backgroundColor = selected ? .clear : .appChipUnselectedBackground
        label.textColor             = selected ? .white : .appChipUnselectedText
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }
}
