//
//  TemplatesViewController.swift
//  Slidesh
//

import UIKit

class TemplatesViewController: UIViewController {

    // MARK: - 筛选状态（空字符串 = 全部）

    private var selectedCategory: String = ""
    private var selectedStyle:    String = ""
    private var selectedColor:    String = ""

    // MARK: - 分页 & 数据

    private var templates:   [PPTTemplate] = []
    private var currentPage  = 1
    private var isLoading    = false
    private var hasMore      = true

    // MARK: - 筛选选项（API 加载后更新）

    private var categoryOptions: [(name: String, value: String)] = [("全部场景", "")]
    private var styleOptions:    [(name: String, value: String)] = [("全部风格", "")]
    private var colorOptions:    [(name: String, value: String)] = [("全部颜色", "")]

    // MARK: - 子视图

    private let categoryView    = CategorySelectorView()
    private let filterBar       = FilterAndToggleBar()
    private var collectionView: UICollectionView!
    private let layoutMode: LayoutMode = .grid  // 当前布局
    private var currentLayoutMode: LayoutMode = .grid

    // 加载指示器（底部加载更多时显示）
    private let loadingIndicator: UIActivityIndicatorView = {
        let iv = UIActivityIndicatorView(style: .medium)
        iv.hidesWhenStopped = true
        return iv
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "全部模板"
        addMeshGradientBackground()
        setupCategoryView()
        setupFilterBar()
        setupCollectionView()
        bindCallbacks()

        loadFilterOptions()
        loadTemplates(reset: true)
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
        categoryView.onCategorySelected = { [weak self] value in
            self?.selectedCategory = value
            self?.loadTemplates(reset: true)
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

    // MARK: - API：筛选选项

    private func loadFilterOptions() {
        PPTAPIService.shared.fetchOptions { [weak self] result in
            guard let self, case .success(let options) = result else {
                if case .failure(let e) = result { print("❌ fetchOptions 失败：\(e)") }
                return
            }

            // 按 type 分组，type 值匹配 API 文档字段名
            let categories = options.filter { $0.type.lowercased() == "category" }
            let styles     = options.filter { $0.type.lowercased() == "style" }
            let colors     = options.filter { $0.type.lowercased() == "themecolor" }

            self.categoryOptions = [("全部场景", "")] + categories.map { ($0.name, $0.value) }
            self.styleOptions    = [("全部风格", "")] + styles.map    { ($0.name, $0.value) }
            self.colorOptions    = [("全部颜色", "")] + colors.map    { ($0.name, $0.value) }

            // 用 API 分类重建 chip 列表
            self.categoryView.configure(with: self.categoryOptions)
        }
    }

    // MARK: - API：分页查询模板

    private func loadTemplates(reset: Bool) {
        guard !isLoading, (reset || hasMore) else { return }

        if reset {
            currentPage = 1
            templates   = []
            hasMore     = true
            collectionView.reloadData()
        }

        isLoading = true
        loadingIndicator.startAnimating()

        PPTAPIService.shared.fetchTemplates(
            category:   selectedCategory.isEmpty ? nil : selectedCategory,
            style:      selectedStyle.isEmpty    ? nil : selectedStyle,
            themeColor: selectedColor.isEmpty    ? nil : selectedColor,
            page:       currentPage
        ) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            self.loadingIndicator.stopAnimating()

            switch result {
            case .success(let newTemplates):
                if reset {
                    self.templates = newTemplates
                } else {
                    self.templates.append(contentsOf: newTemplates)
                }
                self.hasMore = newTemplates.count >= 20
                self.currentPage += 1
                self.collectionView.reloadData()

            case .failure(let error):
                print("❌ 模板加载失败: \(error.localizedDescription)")
                self.collectionView.reloadData()
            }
        }
    }

    // MARK: - 布局切换

    private func switchLayout(to mode: LayoutMode) {
        currentLayoutMode = mode
        // 在布局切换前更新所有可见 cell 内部状态，
        // 因为 setCollectionViewLayout(animated:true) + reloadData() 对可见 cell 不可靠
        for case let cell as TemplateCell in collectionView.visibleCells {
            cell.applyMode(mode)
        }
        let layout = mode == .grid ? makeGridLayout() : makeListLayout()
        collectionView.setCollectionViewLayout(layout, animated: true)
    }

    // MARK: - CompositionalLayout

    private func makeGridLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                               heightDimension: .fractionalHeight(1.0))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)

        // estimated 让 cell 根据内容（预览图比例 + 标题文字）自适应高度
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(160))
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
        let options = styleOptions.map { $0.name }
        let current = styleOptions.firstIndex { $0.value == selectedStyle } ?? 0
        let picker  = FilterPickerViewController(title: "风格", options: options, selectedIndex: current)
        picker.onSelect = { [weak self] index in
            guard let self, index < self.styleOptions.count else { return }
            let selected = self.styleOptions[index]
            self.selectedStyle = selected.value
            self.filterBar.setStyleTitle(selected.name, active: !selected.value.isEmpty)
            self.loadTemplates(reset: true)
        }
        present(picker, animated: false)
    }

    private func showColorPicker() {
        let options = colorOptions.map { $0.name }
        let current = colorOptions.firstIndex { $0.value == selectedColor } ?? 0
        let picker  = FilterPickerViewController(title: "颜色", options: options, selectedIndex: current)
        picker.onSelect = { [weak self] index in
            guard let self, index < self.colorOptions.count else { return }
            let selected = self.colorOptions[index]
            self.selectedColor = selected.value
            self.filterBar.setColorTitle(selected.name, active: !selected.value.isEmpty)
            self.loadTemplates(reset: true)
        }
        present(picker, animated: false)
    }
}

// MARK: - UICollectionViewDataSource

extension TemplatesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        templates.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TemplateCell.reuseID, for: indexPath) as! TemplateCell
        cell.configure(with: templates[indexPath.item], mode: currentLayoutMode)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension TemplatesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let template = templates[indexPath.item]
        print("选中模板: \(template.subject) id=\(template.id)")
        // TODO: 跳转模板详情页
    }

    // 接近底部时加载下一页
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY     = scrollView.contentOffset.y
        let contentH    = scrollView.contentSize.height
        let frameH      = scrollView.frame.height
        if offsetY > contentH - frameH - 200 {
            loadTemplates(reset: false)
        }
    }
}
