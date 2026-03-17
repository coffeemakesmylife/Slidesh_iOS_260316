//
//  TemplatesViewController.swift
//  Slidesh
//

import UIKit

class TemplatesViewController: UIViewController {

    // MARK: - 状态

    private var layoutMode: LayoutMode = .grid
    private var selectedCategory: TemplateCategory = .all
    private var selectedStyle: TemplateStyle = .all
    private var selectedColor: TemplateColor = .all

    private var filteredData: [TemplateModel] = TemplateModel.mockData

    // MARK: - 子视图

    private let categoryView = CategorySelectorView()
    private let filterBar    = FilterAndToggleBar()
    private var collectionView: UICollectionView!

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "全部模板"
        addMeshGradientBackground()
        setupCategoryView()
        setupFilterBar()
        setupCollectionView()
        bindCallbacks()
    }

    // MARK: - 布局

    private func setupCategoryView() {
        categoryView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(categoryView)
        NSLayoutConstraint.activate([
            categoryView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            categoryView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func setupFilterBar() {
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterBar)
        NSLayoutConstraint.activate([
            filterBar.topAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: 4),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeGridLayout())
        collectionView.backgroundColor = .clear
        collectionView.register(TemplateCell.self, forCellWithReuseIdentifier: TemplateCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 100, right: 0)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - 回调绑定

    private func bindCallbacks() {
        categoryView.onCategorySelected = { [weak self] category in
            self?.selectedCategory = category
            self?.applyFilters()
        }

        filterBar.onStyleFilter = { [weak self] in
            self?.showStylePicker()
        }

        filterBar.onColorFilter = { [weak self] in
            self?.showColorPicker()
        }

        filterBar.onLayoutToggle = { [weak self] mode in
            self?.switchLayout(to: mode)
        }
    }

    // MARK: - 筛选逻辑

    private func applyFilters() {
        filteredData = TemplateModel.mockData.filter { model in
            let categoryMatch = selectedCategory == .all || model.category == selectedCategory
            let styleMatch    = selectedStyle == .all    || model.style    == selectedStyle
            let colorMatch    = selectedColor == .all    || model.color    == selectedColor
            return categoryMatch && styleMatch && colorMatch
        }
        collectionView.reloadData()
    }

    // MARK: - 布局切换

    private func switchLayout(to mode: LayoutMode) {
        layoutMode = mode
        let layout = mode == .grid ? makeGridLayout() : makeListLayout()
        collectionView.setCollectionViewLayout(layout, animated: true)
        collectionView.reloadData()
    }

    // MARK: - CompositionalLayout

    private func makeGridLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                               heightDimension: .fractionalHeight(1.0))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(200))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func makeListLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(110))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(110))
        let group     = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - 筛选弹窗

    private func showStylePicker() {
        let options = TemplateStyle.allCases.map { $0.rawValue }
        let current = TemplateStyle.allCases.firstIndex(of: selectedStyle) ?? 0
        let picker  = FilterPickerViewController(title: "风格", options: options, selectedIndex: current)
        picker.onSelect = { [weak self] index in
            let style = TemplateStyle.allCases[index]
            self?.selectedStyle = style
            self?.filterBar.setStyleTitle(style.rawValue, active: style != .all)
            self?.applyFilters()
        }
        present(picker, animated: false)
    }

    private func showColorPicker() {
        let options = TemplateColor.allCases.map { $0.rawValue }
        let current = TemplateColor.allCases.firstIndex(of: selectedColor) ?? 0
        let picker  = FilterPickerViewController(title: "颜色", options: options, selectedIndex: current)
        picker.onSelect = { [weak self] index in
            let color = TemplateColor.allCases[index]
            self?.selectedColor = color
            self?.filterBar.setColorTitle(color.rawValue, active: color != .all)
            self?.applyFilters()
        }
        present(picker, animated: false)
    }
}

// MARK: - UICollectionViewDataSource

extension TemplatesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        filteredData.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TemplateCell.reuseID, for: indexPath) as! TemplateCell
        cell.configure(with: filteredData[indexPath.item], mode: layoutMode)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension TemplatesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let template = filteredData[indexPath.item]
        print("选中模板: \(template.name)")
        // TODO: 跳转模板详情页
    }
}
