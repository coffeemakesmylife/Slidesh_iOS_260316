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

    private let dimView   = UIView()
    private let panelView = UIView()
    private let titleLabel = UILabel()
    private var collectionView: UICollectionView!
    private var panelBottomConstraint: NSLayoutConstraint!

    // MARK: - Init

    init(title: String, options: [String], selectedIndex: Int) {
        self.pickerTitle   = title
        self.options       = options
        self.selectedIndex = selectedIndex
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

        // 选项集合视图
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeChipLayout())
        collectionView.backgroundColor = .clear
        collectionView.register(PickerChipCell.self, forCellWithReuseIdentifier: PickerChipCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(collectionView)

        // 根据选项数量计算高度（4 列，行高 40，行间距 10）
        let rows    = Int(ceil(Double(options.count) / 4.0))
        let chipH: CGFloat = 40
        let rowGap: CGFloat = 10
        let collH   = CGFloat(rows) * chipH + CGFloat(max(rows - 1, 0)) * rowGap

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
            collectionView.heightAnchor.constraint(equalToConstant: collH),
            collectionView.bottomAnchor.constraint(equalTo: panelView.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
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
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PickerChipCell.reuseID, for: indexPath) as! PickerChipCell
        cell.configure(title: options[indexPath.item], selected: indexPath.item == selectedIndex)
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
