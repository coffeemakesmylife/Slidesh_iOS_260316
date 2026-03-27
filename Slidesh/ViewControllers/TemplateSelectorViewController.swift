//
//  TemplateSelectorViewController.swift
//  Slidesh
//
//  模板选择器：tab 栏 + 分类 + 筛选 + 网格 + 底部合成PPT按钮
//

import UIKit
import SkeletonView

class TemplateSelectorViewController: UIViewController {

    // MARK: - 参数

    private let taskId:   String
    private let markdown: String

    /// 非空时进入"换模板"模式：选好后回调 templateId，不走 generatePptx 流程
    var onTemplateSelected: ((String) -> Void)?

    // MARK: - 数据状态

    private var selectedTemplate:  PPTTemplate?
    private var allTemplates:      [PPTTemplate] = []  // 分页原始数据
    private var filteredTemplates: [PPTTemplate] = []  // 筛选/排序后展示
    private var currentPage    = 1
    private var isLoading      = false
    private var hasMore        = true
    private var loadGeneration = 0  // 防旧回调覆盖
    private var selectedCategory: String = ""
    private var selectedStyle:    String = ""
    private var selectedColor:    String = ""
    private var themeFirst:       Bool   = false

    private var categoryOptions: [(name: String, value: String)] = [("全部场景", "")]
    private var styleOptions:    [(name: String, value: String)] = [("全部风格", "")]
    private var colorOptions:    [(name: String, value: String)] = [("全部颜色", "")]

    // MARK: - 导航栏自定义 Tab（下划线样式，嵌入 titleView）

    private let tabCenter    = UIButton(type: .system)
    private let tabRecent    = UIButton(type: .system)
    private let tabIndicator = UIView()
    private var indicatorCenterX: NSLayoutConstraint!

    // MARK: - 分类 + 筛选（使用与 TemplatesViewController 统一的 FilterChipButton）

    private let categoryView   = CategorySelectorView()
    private let filterView     = UIView()
    private let styleFilterBtn = FilterChipButton(title: "风格")
    private let colorFilterBtn = FilterChipButton(title: "颜色")
    private let themeFilterBtn = FilterChipButton(title: "贴合主题")

    // MARK: - 模板网格

    private var collectionView: UICollectionView!
    private weak var footerView: SelectorFooterView?

    // MARK: - 底部合成PPT栏

    private let bottomBar  = UIView()
    private let composeBtn = UIButton(type: .custom)
    private var composeGrad: CAGradientLayer?
    private var bottomGradLayer: CAGradientLayer?  // 渐变淡入遮罩

    // MARK: - 空状态（"最近使用" tab）

    private let emptyLabel = UILabel()

    // MARK: - Init

    init(taskId: String, markdown: String) {
        self.taskId   = taskId
        self.markdown = markdown
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()
        setupNavBar()
        setupCategoryView()
        setupFilterView()
        setupCollectionView()
        setupBottomBar()
        setupEmptyLabel()
        loadFilterOptions()
        loadTemplates(reset: true)
        // 换模板模式：修改按钮标题
        if onTemplateSelected != nil {
            composeBtn.setTitle("使用此模板", for: .normal)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        composeGrad?.frame   = composeBtn.bounds
        bottomGradLayer?.frame = bottomBar.bounds
    }

    // MARK: - 导航栏

    private func setupNavBar() {
        // 系统 chevron.left 关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.leftBarButtonItem?.tintColor = .appTextPrimary

        // 自定义 titleView：两个 tab 按钮 + 下划线指示器
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        [tabCenter, tabRecent].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        tabCenter.setTitle("模板中心", for: .normal)
        tabCenter.setTitleColor(.appPrimary, for: .normal)
        tabCenter.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        tabCenter.tag = 0

        tabRecent.setTitle("最近使用", for: .normal)
        tabRecent.setTitleColor(.appTextSecondary, for: .normal)
        tabRecent.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        tabRecent.tag = 1

        tabIndicator.backgroundColor    = .appPrimary
        tabIndicator.layer.cornerRadius = 1.5
        tabIndicator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tabIndicator)

        indicatorCenterX = tabIndicator.centerXAnchor.constraint(equalTo: tabCenter.centerXAnchor)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 200),
            container.heightAnchor.constraint(equalToConstant: 36),

            tabCenter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabCenter.topAnchor.constraint(equalTo: container.topAnchor),
            tabCenter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tabCenter.widthAnchor.constraint(equalToConstant: 96),

            tabRecent.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabRecent.topAnchor.constraint(equalTo: container.topAnchor),
            tabRecent.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tabRecent.widthAnchor.constraint(equalToConstant: 96),

            tabIndicator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            indicatorCenterX,
            tabIndicator.widthAnchor.constraint(equalToConstant: 28),
            tabIndicator.heightAnchor.constraint(equalToConstant: 3),
        ])

        navigationItem.titleView = container

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    @objc private func tabTapped(_ sender: UIButton) {
        let isCenter = sender.tag == 0
        tabCenter.setTitleColor(isCenter ? .appPrimary : .appTextSecondary, for: .normal)
        tabRecent.setTitleColor(isCenter ? .appTextSecondary : .appPrimary, for: .normal)

        indicatorCenterX.isActive = false
        indicatorCenterX = tabIndicator.centerXAnchor.constraint(
            equalTo: isCenter ? tabCenter.centerXAnchor : tabRecent.centerXAnchor)
        indicatorCenterX.isActive = true
        UIView.animate(withDuration: 0.2) { self.navigationItem.titleView?.layoutIfNeeded() }

        collectionView.isHidden = !isCenter
        emptyLabel.isHidden     = isCenter
    }

    // MARK: - 分类视图

    private func setupCategoryView() {
        categoryView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(categoryView)
        categoryView.onCategorySelected = { [weak self] value in
            self?.selectedCategory = value
            self?.loadTemplates(reset: true)
        }
        NSLayoutConstraint.activate([
            categoryView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            categoryView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    // MARK: - 筛选栏（FilterChipButton 样式与 TemplatesViewController 统一）

    private func setupFilterView() {
        filterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterView)

        [styleFilterBtn, colorFilterBtn, themeFilterBtn].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            filterView.addSubview($0)
        }
        styleFilterBtn.addTarget(self, action: #selector(styleBtnTapped), for: .touchUpInside)
        colorFilterBtn.addTarget(self, action: #selector(colorBtnTapped), for: .touchUpInside)
        themeFilterBtn.addTarget(self, action: #selector(themeBtnTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            filterView.topAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: 4),
            filterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterView.heightAnchor.constraint(equalToConstant: 44),

            styleFilterBtn.leadingAnchor.constraint(equalTo: filterView.leadingAnchor, constant: 16),
            styleFilterBtn.centerYAnchor.constraint(equalTo: filterView.centerYAnchor),

            colorFilterBtn.leadingAnchor.constraint(equalTo: styleFilterBtn.trailingAnchor, constant: 8),
            colorFilterBtn.centerYAnchor.constraint(equalTo: filterView.centerYAnchor),

            themeFilterBtn.trailingAnchor.constraint(equalTo: filterView.trailingAnchor, constant: -16),
            themeFilterBtn.centerYAnchor.constraint(equalTo: filterView.centerYAnchor),
        ])
    }

    // MARK: - CollectionView（两列网格）

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeGridLayout())
        collectionView.backgroundColor = .clear
        collectionView.isSkeletonable  = true
        collectionView.register(TemplateCell.self, forCellWithReuseIdentifier: TemplateCell.reuseID)
        collectionView.register(SelectorFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: SelectorFooterView.reuseID)
        collectionView.dataSource    = self
        collectionView.delegate      = self
        collectionView.contentInset  = UIEdgeInsets(top: 12, left: 0, bottom: 140, right: 0)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: filterView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeGridLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                               heightDimension: .fractionalHeight(1.0))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(160))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets     = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
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

    // MARK: - 底部合成PPT栏

    private func setupBottomBar() {
        // 完全透明容器，叠加在 collectionView 上方
        bottomBar.backgroundColor = .clear
        bottomBar.isUserInteractionEnabled = true
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        // 渐变遮罩：顶部完全透明 → 底部不透明，实现自然过渡（无分割线）
        let gradBg = CAGradientLayer()
        gradBg.colors     = [UIColor.appBackgroundPrimary.withAlphaComponent(0).cgColor,
                             UIColor.appBackgroundPrimary.withAlphaComponent(0.92).cgColor,
                             UIColor.appBackgroundPrimary.cgColor]
        gradBg.locations  = [0, 0.45, 1]
        gradBg.startPoint = CGPoint(x: 0.5, y: 0)
        gradBg.endPoint   = CGPoint(x: 0.5, y: 1)
        bottomBar.layer.insertSublayer(gradBg, at: 0)
        bottomGradLayer = gradBg

        composeBtn.setTitle("合成PPT", for: .normal)
        composeBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        composeBtn.setTitleColor(.white, for: .normal)
        composeBtn.layer.cornerRadius = 26
        composeBtn.clipsToBounds      = true
        composeBtn.addTarget(self, action: #selector(composeTapped), for: .touchUpInside)
        composeBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(composeBtn)

        let grad = CAGradientLayer()
        grad.colors     = [UIColor.appGradientStart.cgColor,
                           UIColor.appGradientMid.cgColor,
                           UIColor.appGradientEnd.cgColor]
        grad.locations  = [0, 0.5, 1]
        grad.startPoint = CGPoint(x: 0, y: 0.5)
        grad.endPoint   = CGPoint(x: 1, y: 0.5)
        composeBtn.layer.insertSublayer(grad, at: 0)
        composeGrad = grad

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            composeBtn.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 32),
            composeBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            composeBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            composeBtn.heightAnchor.constraint(equalToConstant: 56),
            composeBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - 空状态标签（"最近使用" tab）

    private func setupEmptyLabel() {
        emptyLabel.text          = "暂无最近使用的模板"
        emptyLabel.textColor     = .appTextTertiary
        emptyLabel.font          = .systemFont(ofSize: 15)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden      = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - 缓存 Key

    private func currentCacheKey() -> String {
        TemplateCache.templatesKey(
            category: selectedCategory,
            style:    selectedStyle,
            color:    selectedColor,
            page:     1)
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

    // MARK: - API：分页加载模板（带缓存，stale-while-revalidate）

    private func loadTemplates(reset: Bool) {
        if reset {
            loadGeneration += 1
            currentPage       = 1
            isLoading         = false
            allTemplates      = []
            filteredTemplates = []
            hasMore           = true
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
                allTemplates = cached
                hasMore      = cached.count >= 20
                currentPage  = 2
                applySort()
                if TemplateCache.shared.isAging(key: key) {
                    scheduleBackgroundRefresh(for: key)
                }
                return
            case .stale(let data):
                guard let cached = data as? [PPTTemplate] else { break }
                hideSkeleton()
                allTemplates = cached
                hasMore      = cached.count >= 20
                currentPage  = 2
                applySort()
                scheduleBackgroundRefresh(for: key)
                return
            case .miss:
                break
            }

            // 缓存未命中：发起网络请求
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
                if case .success(let newTemplates) = result {
                    self.allTemplates = newTemplates
                    self.hasMore      = newTemplates.count >= 20
                    self.currentPage  = 2
                    TemplateCache.shared.storeTemplates(key: key, templates: newTemplates)
                    self.applySort()
                }
            }

        } else {
            // 翻页：直接网络请求
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
                if case .success(let newTemplates) = result {
                    self.hasMore     = newTemplates.count >= 20
                    self.currentPage += 1
                    self.allTemplates.append(contentsOf: newTemplates)
                    self.applySort()
                }
            }
        }
    }

    private func scheduleBackgroundRefresh(for key: String) {
        let category = selectedCategory
        let style    = selectedStyle
        let color    = selectedColor
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            PPTAPIService.shared.fetchTemplates(
                category:   category.isEmpty ? nil : category,
                style:      style.isEmpty    ? nil : style,
                themeColor: color.isEmpty    ? nil : color,
                page:       1
            ) { [weak self] result in
                guard let self, case .success(let fresh) = result else { return }
                TemplateCache.shared.storeTemplates(key: key, templates: fresh)
                guard self.currentCacheKey() == key, self.currentPage == 2 else { return }
                self.allTemplates = fresh
                self.hasMore      = fresh.count >= 20
                self.applySort()
            }
        }
    }

    /// 对 allTemplates 应用"贴合主题"客户端排序（不需要 API）
    private func applySort() {
        var result = allTemplates
        if themeFirst {
            // 从 markdown 首行 "# 主题文字" 提取关键词，将匹配的模板排到前面
            let theme = markdown.components(separatedBy: "\n")
                .first { $0.hasPrefix("# ") }
                .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) } ?? ""
            if !theme.isEmpty {
                result.sort { a, _ in a.subject.localizedCaseInsensitiveContains(theme) }
            }
        }
        filteredTemplates = result
        collectionView.reloadData()
    }

    // MARK: - 骨架屏

    private func showSkeleton() {
        collectionView.showSkeleton(usingColor: .systemGray5, transition: .crossDissolve(0.25))
    }

    private func hideSkeleton() {
        guard collectionView.sk.isSkeletonActive else { return }
        collectionView.hideSkeleton(reloadDataAfter: false, transition: .crossDissolve(0.25))
    }

    // MARK: - 筛选 Actions

    @objc private func styleBtnTapped() {
        let options = styleOptions.map { $0.name }
        let current = styleOptions.firstIndex { $0.value == selectedStyle } ?? 0
        let picker  = FilterPickerViewController(title: "风格", options: options, selectedIndex: current)
        picker.onSelect = { [weak self] index in
            guard let self, index < self.styleOptions.count else { return }
            let sel = self.styleOptions[index]
            self.selectedStyle = sel.value
            self.styleFilterBtn.setFilterTitle(sel.name, active: !sel.value.isEmpty)
            self.loadTemplates(reset: true)
        }
        present(picker, animated: false)
    }

    @objc private func colorBtnTapped() {
        let options  = colorOptions.map { $0.name }
        let current  = colorOptions.firstIndex { $0.value == selectedColor } ?? 0
        let swatches: [UIColor?] = colorOptions.map { TemplatesViewController.uiColor(forValue: $0.value) }
        let picker   = FilterPickerViewController(title: "颜色", options: options,
                                                  selectedIndex: current, colorSwatches: swatches)
        picker.onSelect = { [weak self] index in
            guard let self, index < self.colorOptions.count else { return }
            let sel = self.colorOptions[index]
            self.selectedColor = sel.value
            self.colorFilterBtn.setFilterTitle(sel.name, active: !sel.value.isEmpty)
            self.loadTemplates(reset: true)
        }
        present(picker, animated: false)
    }

    /// 贴合主题：纯客户端排序，将 subject 包含大纲主题词的模板排到前面
    @objc private func themeBtnTapped() {
        themeFirst.toggle()
        themeFilterBtn.setFilterTitle("贴合主题", active: themeFirst)
        applySort()
    }

    // MARK: - 合成PPT

    @objc private func composeTapped() {
        guard let template = selectedTemplate else {
            let msg = onTemplateSelected != nil ? "点击一个模板后再使用" : "点击一个模板后再合成PPT"
            let alert = UIAlertController(title: "请先选择模板", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }

        // 换模板模式：直接回调 templateId，不走 generatePptx
        if let onSelect = onTemplateSelected {
            dismiss(animated: true) { onSelect(template.id) }
            return
        }

        setComposeLoading(true)

        PPTAPIService.shared.generatePptx(
            taskId:     taskId,
            templateId: template.id,
            markdown:   markdown
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let pptId):
                print("✅ generatePptx 成功，pptId=\(pptId)，正在加载详情...")
                self.loadAndShowPPT(pptId: pptId)
            case .failure(let error):
                self.setComposeLoading(false)
                let alert = UIAlertController(title: "合成失败",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    // 从 markdown 提取主题标题（# 开头的第一行）
    private func subjectFromMarkdown() -> String {
        for line in markdown.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("# ") { return String(t.dropFirst(2)) }
        }
        return "未命名作品"
    }

    private func setComposeLoading(_ loading: Bool) {
        composeBtn.isEnabled = !loading
        if loading {
            composeBtn.setTitle("", for: .normal)
            let s = UIActivityIndicatorView(style: .medium)
            s.color = .white
            s.tag   = 888
            s.startAnimating()
            s.translatesAutoresizingMaskIntoConstraints = false
            composeBtn.addSubview(s)
            NSLayoutConstraint.activate([
                s.centerXAnchor.constraint(equalTo: composeBtn.centerXAnchor),
                s.centerYAnchor.constraint(equalTo: composeBtn.centerYAnchor),
            ])
        } else {
            composeBtn.subviews.first(where: { $0.tag == 888 })?.removeFromSuperview()
            composeBtn.setTitle(onTemplateSelected != nil ? "使用此模板" : "合成PPT", for: .normal)
        }
    }

    /// generatePptx 成功后调用：加载 PPT 详情并跳转预览页
    private func loadAndShowPPT(pptId: String) {
        PPTAPIService.shared.loadPPT(pptId: pptId) { [weak self] result in
            guard let self else { return }
            self.setComposeLoading(false)
            switch result {
            case .success(let info):
                print("✅ loadPPT 成功，status=\(info.status ?? "-")，fileUrl=\(info.fileUrl ?? "-")")
                // 自动保存 PPT 记录（fileUrl 非空时才有意义）
                if let fileUrl = info.fileUrl, !fileUrl.isEmpty {
                    let record = PPTRecord(
                        id:       info.pptId,
                        taskId:   info.taskId ?? taskId,
                        subject:  info.subject ?? self.subjectFromMarkdown(),
                        fileUrl:  fileUrl,
                        coverUrl: info.coverUrl,
                        savedAt:  Date()
                    )
                    WorksStore.shared.savePPT(record)
                }
                let previewVC = PPTPreviewViewController(pptInfo: info, source: .templateFlow)
                self.navigationController?.pushViewController(previewVC, animated: true)
            case .failure(let error):
                print("❌ loadPPT 失败：\(error.localizedDescription)")
                // loadPPT 失败时仍展示预览页（用空 fileUrl，提示用户）
                let stub = PPTInfo(pptId: pptId, taskId: nil, subject: nil,
                                   fileUrl: nil, coverUrl: nil, status: nil, total: nil, createTime: nil)
                let previewVC = PPTPreviewViewController(pptInfo: stub, source: .templateFlow)
                self.navigationController?.pushViewController(previewVC, animated: true)
            }
        }
    }
}

// MARK: - SkeletonCollectionViewDataSource + UICollectionViewDataSource

extension TemplateSelectorViewController: SkeletonCollectionViewDataSource {

    func collectionSkeletonView(_ skeletonView: UICollectionView,
                                numberOfItemsInSection section: Int) -> Int { 6 }

    func collectionSkeletonView(_ skeletonView: UICollectionView,
                                cellIdentifierForItemAt indexPath: IndexPath) -> ReusableCellIdentifier {
        TemplateCell.reuseID
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        filteredTemplates.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TemplateCell.reuseID, for: indexPath) as! TemplateCell
        let tmpl = filteredTemplates[indexPath.item]
        cell.configure(with: tmpl, mode: .grid)
        cell.setSelectedState(selectedTemplate?.id == tmpl.id)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: SelectorFooterView.reuseID,
            for: indexPath) as! SelectorFooterView
        footerView = footer
        footer.configure(showEnd: !hasMore && !filteredTemplates.isEmpty)
        return footer
    }
}

// MARK: - UICollectionViewDelegate

extension TemplateSelectorViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let prev   = selectedTemplate
        selectedTemplate = filteredTemplates[indexPath.item]

        var paths = [indexPath]
        if let prevId  = prev?.id,
           let prevIdx = filteredTemplates.firstIndex(where: { $0.id == prevId }) {
            paths.append(IndexPath(item: prevIdx, section: 0))
        }
        collectionView.reloadItems(at: paths)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY  = scrollView.contentOffset.y
        let contentH = scrollView.contentSize.height
        let frameH   = scrollView.frame.height
        if offsetY > contentH - frameH - 200 { loadTemplates(reset: false) }
    }
}

// MARK: - Footer

private class SelectorFooterView: UICollectionReusableView {

    static let reuseID = "SelectorFooterView"
    private let label  = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.font          = .systemFont(ofSize: 13)
        label.textColor     = .appTextTertiary
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
    func configure(showEnd: Bool) { label.text = showEnd ? "— 到底了 —" : nil }
}
