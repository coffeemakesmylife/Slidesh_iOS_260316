//
//  TemplatesViewController.swift
//  Slidesh
//

import UIKit
import SkeletonView

class TemplatesViewController: UIViewController {

    // MARK: - 筛选状态（空字符串 = 全部）

    private var selectedCategory: String = ""
    private var selectedStyle:    String = ""
    private var selectedColor:    String = ""

    // MARK: - 分页 & 数据

    private var templates:     [PPTTemplate] = []
    private var currentPage    = 1
    private var isLoading      = false
    private var hasMore        = true
    private var loadGeneration = 0   // 防止旧请求的回调覆盖当前状态

    // MARK: - 筛选选项（API 加载后更新）

    private var categoryOptions: [(name: String, value: String)] = [("全部场景", "")]
    private var styleOptions:    [(name: String, value: String)] = [("全部风格", "")]
    private var colorOptions:    [(name: String, value: String)] = [("全部颜色", "")]

    // MARK: - 子视图

    private let categoryView       = CategorySelectorView()
    private let filterBar          = FilterAndToggleBar()
    private var collectionView:    UICollectionView!
    private var currentLayoutMode: LayoutMode = .grid
    private weak var footerView:   TemplatesFooterView?

    // MARK: - 缓存 Key

    private func currentCacheKey() -> String {
        TemplateCache.templatesKey(
            category: selectedCategory,
            style:    selectedStyle,
            color:    selectedColor,
            page:     1)
    }

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
        collectionView.backgroundColor  = .clear
        collectionView.isSkeletonable   = true   // SkeletonView 必须
        collectionView.register(TemplateCell.self, forCellWithReuseIdentifier: TemplateCell.reuseID)
        collectionView.register(TemplatesFooterView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: TemplatesFooterView.reuseID)
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
        filterBar.onStyleFilter = { [weak self] in self?.showStylePicker() }
        filterBar.onColorFilter = { [weak self] in self?.showColorPicker() }
        filterBar.onLayoutToggle = { [weak self] mode in self?.switchLayout(to: mode) }
    }

    // MARK: - API：筛选选项（带缓存）

    private func loadFilterOptions() {
        let key = TemplateCache.optionsKey()
        switch TemplateCache.shared.fetchOptions(key: key) {
        case .fresh(let data):
            if let options = data as? [PPTOption] { applyFilterOptions(options) }
            if TemplateCache.shared.isAging(key: key) { fetchAndCacheOptions(key: key) }
        case .stale(let data):
            if let options = data as? [PPTOption] { applyFilterOptions(options) }
            fetchAndCacheOptions(key: key)
        case .miss:
            fetchAndCacheOptions(key: key)
        }
    }

    private func applyFilterOptions(_ options: [PPTOption]) {
        let categories = options.filter { $0.type.lowercased() == "category" }
        let styles     = options.filter { $0.type.lowercased() == "style" }
        let colors     = options.filter { $0.type.lowercased() == "themecolor" }
        categoryOptions = [("全部场景", "")] + categories.map { ($0.name, $0.value) }
        styleOptions    = [("全部风格", "")] + styles.map    { ($0.name, $0.value) }
        colorOptions    = [("全部颜色", "")] + colors.map    { ($0.name, $0.value) }
        categoryView.configure(with: categoryOptions)
    }

    private func fetchAndCacheOptions(key: String) {
        PPTAPIService.shared.fetchOptions { [weak self] result in
            guard let self, case .success(let options) = result else { return }
            TemplateCache.shared.storeOptions(key: key, options: options)
            self.applyFilterOptions(options)
        }
    }

    // MARK: - API：分页查询模板（带缓存 + 骨架屏）

    private func loadTemplates(reset: Bool) {
        if reset {
            loadGeneration += 1
            isLoading   = false
            currentPage = 1
            templates   = []
            hasMore     = true
        }
        guard !isLoading, (reset || hasMore) else { return }

        if reset {
            showSkeleton()
            let key        = currentCacheKey()
            let generation = loadGeneration

            switch TemplateCache.shared.fetchTemplates(key: key) {
            case .fresh(let data):
                guard let cached = data as? [PPTTemplate] else { break }
                hideSkeleton()
                templates   = cached
                hasMore     = cached.count >= 20
                currentPage = 2
                collectionView.reloadData()
                if TemplateCache.shared.isAging(key: key) {
                    scheduleBackgroundRefresh(for: key)
                }
                return

            case .stale(let data):
                guard let cached = data as? [PPTTemplate] else { break }
                hideSkeleton()
                templates   = cached
                hasMore     = cached.count >= 20
                currentPage = 2
                collectionView.reloadData()
                scheduleBackgroundRefresh(for: key)   // 前台静默刷新（无骨架）
                return

            case .miss:
                break
            }

            // 缓存未命中：保留骨架屏，发起网络请求
            isLoading = true
            PPTAPIService.shared.fetchTemplates(
                category:   selectedCategory.isEmpty ? nil : selectedCategory,
                style:      selectedStyle.isEmpty    ? nil : selectedStyle,
                themeColor: selectedColor.isEmpty    ? nil : selectedColor,
                page:       1
            ) { [weak self] result in
                guard let self, self.loadGeneration == generation else { return }
                self.isLoading = false
                self.hideSkeleton()
                switch result {
                case .success(let newTemplates):
                    self.templates   = newTemplates
                    self.hasMore     = newTemplates.count >= 20
                    self.currentPage = 2
                    TemplateCache.shared.storeTemplates(key: key, templates: newTemplates)
                    self.collectionView.reloadData()
                case .failure(let error):
                    print("❌ 模板加载失败: \(error.localizedDescription)")
                    self.collectionView.reloadData()
                }
            }

        } else {
            // 翻页：不使用缓存，直接请求网络
            isLoading = true
            let generation = loadGeneration

            PPTAPIService.shared.fetchTemplates(
                category:   selectedCategory.isEmpty ? nil : selectedCategory,
                style:      selectedStyle.isEmpty    ? nil : selectedStyle,
                themeColor: selectedColor.isEmpty    ? nil : selectedColor,
                page:       currentPage
            ) { [weak self] result in
                guard let self, self.loadGeneration == generation else { return }
                self.isLoading = false
                switch result {
                case .success(let newTemplates):
                    self.hasMore     = newTemplates.count >= 20
                    self.currentPage += 1
                    let startIndex   = self.templates.count
                    self.templates.append(contentsOf: newTemplates)
                    let indexPaths = (startIndex..<self.templates.count).map {
                        IndexPath(item: $0, section: 0)
                    }
                    self.collectionView.performBatchUpdates({
                        self.collectionView.insertItems(at: indexPaths)
                    }, completion: { _ in self.reloadFooter() })
                case .failure(let error):
                    print("❌ 翻页加载失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 后台/前台静默刷新（有缓存时调用，不显示骨架屏）

    private func scheduleBackgroundRefresh(for key: String) {
        let category = selectedCategory
        let style    = selectedStyle
        let color    = selectedColor
        // 在后台线程发起刷新（spec 2.2），PPTAPIService 回调已 dispatch 到主线程
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            PPTAPIService.shared.fetchTemplates(
                category:   category.isEmpty ? nil : category,
                style:      style.isEmpty    ? nil : style,
                themeColor: color.isEmpty    ? nil : color,
                page:       1
            ) { [weak self] result in
                // PPTAPIService 已在主线程回调
                guard let self, case .success(let fresh) = result else { return }
                TemplateCache.shared.storeTemplates(key: key, templates: fresh)
                // 仅当筛选未变且用户未翻到第 2 页以后，才用刷新结果覆盖列表
                guard self.currentCacheKey() == key, self.currentPage == 2 else { return }
                self.templates   = fresh
                self.hasMore     = fresh.count >= 20
                self.collectionView.reloadData()
            }
        }
    }

    // MARK: - 骨架屏控制

    private func showSkeleton() {
        collectionView.showSkeleton(usingColor: .systemGray5,
                                    transition: .crossDissolve(0.25))
    }

    private func hideSkeleton() {
        guard collectionView.sk.isSkeletonActive else { return }
        // reloadDataAfter: false — 调用方在 hideSkeleton 后显式 reloadData，
        // 确保 self.templates 已赋值再触发数据源回调
        collectionView.hideSkeleton(reloadDataAfter: false,
                                    transition: .crossDissolve(0.25))
    }

    // MARK: - Footer 刷新

    private func reloadFooter() {
        footerView?.configure(showEnd: !hasMore && !templates.isEmpty)
    }

    // MARK: - 布局切换

    private func switchLayout(to mode: LayoutMode) {
        currentLayoutMode = mode
        let layout = mode == .grid ? makeGridLayout() : makeListLayout()
        if mode == .list {
            // 网格→列表：固定尺寸约束不会因宽度变化产生拉伸，直接动画即可
            for case let cell as TemplateCell in collectionView.visibleCells {
                cell.applyMode(.list)
            }
            collectionView.setCollectionViewLayout(layout, animated: true)
        } else {
            // 列表→网格：先设置与目标网格图片等高的固定约束，动画结束后换回比例约束
            let imageWidth = (collectionView.bounds.width - 20) / 2 - 20
            let targetImageHeight = imageWidth * 0.62
            for case let cell as TemplateCell in collectionView.visibleCells {
                cell.prepareForGridTransition(expectedImageHeight: targetImageHeight)
            }
            collectionView.setCollectionViewLayout(layout, animated: true) { [weak self] _ in
                for case let cell as TemplateCell in self?.collectionView.visibleCells ?? [] {
                    cell.activateProportionalGridConstraint()
                }
            }
        }
    }

    // MARK: - CompositionalLayout

    private func makeGridLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                               heightDimension: .fractionalHeight(1.0))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(160))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing    = 12
        section.contentInsets        = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        section.boundarySupplementaryItems = [makeFooterItem()]
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
        section.interGroupSpacing    = 10
        section.contentInsets        = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        section.boundarySupplementaryItems = [makeFooterItem()]
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func makeFooterItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                          heightDimension: .absolute(48))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom)
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
        let options  = colorOptions.map { $0.name }
        let current  = colorOptions.firstIndex { $0.value == selectedColor } ?? 0
        // 将颜色 value 映射为 UIColor，第一个（全部）传 nil 用品牌渐变
        let swatches: [UIColor?] = colorOptions.map { Self.uiColor(forValue: $0.value) }
        let picker   = FilterPickerViewController(title: "颜色", options: options,
                                                  selectedIndex: current, colorSwatches: swatches)
        picker.onSelect = { [weak self] index in
            guard let self, index < self.colorOptions.count else { return }
            let selected = self.colorOptions[index]
            self.selectedColor = selected.value
            self.filterBar.setColorTitle(selected.name, active: !selected.value.isEmpty)
            self.loadTemplates(reset: true)
        }
        present(picker, animated: false)
    }

    /// 根据 API 返回的颜色 value 值映射为 UIColor，空字符串（全部）返回 nil
    private static func uiColor(forValue value: String) -> UIColor? {
        switch value.lowercased() {
        case "":        return nil
        case "orange":  return UIColor(red: 0.98, green: 0.55, blue: 0.12, alpha: 1)
        case "blue":    return UIColor(red: 0.20, green: 0.49, blue: 0.96, alpha: 1)
        case "purple":  return UIColor(red: 0.60, green: 0.25, blue: 0.85, alpha: 1)
        case "cyan":    return UIColor(red: 0.15, green: 0.75, blue: 0.82, alpha: 1)
        case "green":   return UIColor(red: 0.22, green: 0.76, blue: 0.40, alpha: 1)
        case "yellow":  return UIColor(red: 0.98, green: 0.82, blue: 0.12, alpha: 1)
        case "red":     return UIColor(red: 0.95, green: 0.24, blue: 0.24, alpha: 1)
        case "brown":   return UIColor(red: 0.60, green: 0.38, blue: 0.22, alpha: 1)
        case "white":   return UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        case "black":   return UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
        default:
            // 尝试解析 #RRGGBB 格式
            var hex = value.trimmingCharacters(in: .whitespaces)
            if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
            if hex.count == 6, let rgb = UInt64(hex, radix: 16) {
                return UIColor(red:   CGFloat((rgb >> 16) & 0xFF) / 255,
                               green: CGFloat((rgb >> 8)  & 0xFF) / 255,
                               blue:  CGFloat( rgb        & 0xFF) / 255,
                               alpha: 1)
            }
            return UIColor.systemGray
        }
    }
}

// MARK: - SkeletonCollectionViewDataSource + UICollectionViewDataSource

extension TemplatesViewController: SkeletonCollectionViewDataSource {

    // SkeletonView 在骨架屏期间调用此方法替代标准 numberOfItemsInSection
    func collectionSkeletonView(_ skeletonView: UICollectionView,
                                numberOfItemsInSection section: Int) -> Int {
        currentLayoutMode == .grid ? 6 : 5
    }

    func collectionSkeletonView(_ skeletonView: UICollectionView,
                                cellIdentifierForItemAt indexPath: IndexPath) -> ReusableCellIdentifier {
        TemplateCell.reuseID
    }

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

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: TemplatesFooterView.reuseID,
            for: indexPath) as! TemplatesFooterView
        footerView = footer
        footer.configure(showEnd: !hasMore && !templates.isEmpty)
        return footer
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY  = scrollView.contentOffset.y
        let contentH = scrollView.contentSize.height
        let frameH   = scrollView.frame.height
        if offsetY > contentH - frameH - 200 {
            loadTemplates(reset: false)
        }
    }
}

// MARK: - Footer 视图

private class TemplatesFooterView: UICollectionReusableView {

    static let reuseID = "TemplatesFooter"

    private let label: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font          = .systemFont(ofSize: 13)
        l.textColor     = .appTextTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(showEnd: Bool) {
        label.text = showEnd ? "— 到底了 —" : nil
    }
}
