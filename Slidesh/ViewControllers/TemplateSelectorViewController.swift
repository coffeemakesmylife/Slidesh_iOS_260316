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

    // MARK: - 数据状态

    private var selectedTemplate:  PPTTemplate?
    private var allTemplates:      [PPTTemplate] = []  // 分页原始数据
    private var filteredTemplates: [PPTTemplate] = []  // 搜索过滤后展示
    private var currentPage    = 1
    private var isLoading      = false
    private var hasMore        = true
    private var loadGeneration = 0  // 防旧回调覆盖
    private var selectedCategory: String = ""
    private var selectedStyle:    String = ""
    private var selectedColor:    String = ""
    private var searchKeyword:    String = ""
    private var themeFirst:       Bool   = false

    private var categoryOptions: [(name: String, value: String)] = [("全部场景", "")]
    private var styleOptions:    [(name: String, value: String)] = [("全部风格", "")]
    private var colorOptions:    [(name: String, value: String)] = [("全部颜色", "")]

    // MARK: - Tab 栏

    private let tabBar       = UIView()
    private let tabCenter    = UIButton(type: .system)
    private let tabRecent    = UIButton(type: .system)
    private let tabIndicator = UIView()
    private var indicatorCenterX: NSLayoutConstraint!

    // MARK: - 搜索栏

    private let searchContainer = UIView()
    private let searchField     = UITextField()
    private let searchBtn       = UIButton(type: .system)

    // MARK: - 分类 + 筛选

    private let categoryView = CategorySelectorView()
    private let filterView   = UIView()
    private let styleBtn     = UIButton(type: .system)
    private let colorBtn     = UIButton(type: .system)
    private let themeBtn     = UIButton(type: .system)

    // MARK: - 模板网格

    private var collectionView: UICollectionView!
    private weak var footerView: SelectorFooterView?

    // MARK: - 底部合成按钮

    private let bottomBar  = UIView()
    private let composeBtn = UIButton(type: .custom)
    private var composeGrad: CAGradientLayer?

    // MARK: - 空状态

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
        setupTabBar()
        setupSearchBar()
        setupCategoryView()
        setupFilterView()
        setupCollectionView()
        setupBottomBar()
        setupEmptyLabel()
        loadFilterOptions()
        loadTemplates(reset: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        composeGrad?.frame = composeBtn.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        // 刷新 CGColor 属性，使其跟随深浅色切换
        searchContainer.layer.borderColor = UIColor.appCardBorder.resolvedColor(with: traitCollection).cgColor
    }

    // MARK: - 导航栏

    private func setupNavBar() {
        title = "挑选PPT模板"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"), style: .plain,
            target: self, action: #selector(closeTapped))
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Tab 栏

    private func setupTabBar() {
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        [tabCenter, tabRecent].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            $0.translatesAutoresizingMaskIntoConstraints = false
            tabBar.addSubview($0)
        }
        tabCenter.setTitle("模板中心", for: .normal)
        tabCenter.setTitleColor(.appPrimary, for: .normal)
        tabCenter.addTarget(self, action: #selector(switchTab(_:)), for: .touchUpInside)
        tabCenter.tag = 0

        tabRecent.setTitle("最近使用", for: .normal)
        tabRecent.setTitleColor(.appTextSecondary, for: .normal)
        tabRecent.addTarget(self, action: #selector(switchTab(_:)), for: .touchUpInside)
        tabRecent.tag = 1

        tabIndicator.backgroundColor    = .appPrimary
        tabIndicator.layer.cornerRadius = 1.5
        tabIndicator.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(tabIndicator)

        // indicatorCenterX 需要动态更新以实现 tab 切换动画
        indicatorCenterX = tabIndicator.centerXAnchor.constraint(equalTo: tabCenter.centerXAnchor)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 44),

            tabCenter.topAnchor.constraint(equalTo: tabBar.topAnchor),
            tabCenter.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            tabCenter.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            tabCenter.widthAnchor.constraint(equalTo: tabBar.widthAnchor, multiplier: 0.5),

            tabRecent.topAnchor.constraint(equalTo: tabBar.topAnchor),
            tabRecent.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            tabRecent.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            tabRecent.widthAnchor.constraint(equalTo: tabBar.widthAnchor, multiplier: 0.5),

            tabIndicator.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            indicatorCenterX,
            tabIndicator.widthAnchor.constraint(equalToConstant: 28),
            tabIndicator.heightAnchor.constraint(equalToConstant: 3),
        ])
    }

    @objc private func switchTab(_ sender: UIButton) {
        let isCenter = sender.tag == 0
        tabCenter.setTitleColor(isCenter ? .appPrimary : .appTextSecondary, for: .normal)
        tabRecent.setTitleColor(isCenter ? .appTextSecondary : .appPrimary, for: .normal)

        indicatorCenterX.isActive = false
        indicatorCenterX = tabIndicator.centerXAnchor.constraint(
            equalTo: isCenter ? tabCenter.centerXAnchor : tabRecent.centerXAnchor)
        indicatorCenterX.isActive = true
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }

        // "最近使用"暂无本地存储，只显示空态
        collectionView.isHidden = !isCenter
        emptyLabel.isHidden     = isCenter
    }

    // MARK: - 搜索栏

    private func setupSearchBar() {
        searchContainer.backgroundColor    = .appCardBackground
        searchContainer.layer.cornerRadius = 22
        searchContainer.layer.borderColor  = UIColor.appCardBorder.resolvedColor(with: traitCollection).cgColor
        searchContainer.layer.borderWidth  = 1
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        let magnifier = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        magnifier.tintColor = .appTextTertiary
        magnifier.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(magnifier)

        searchField.placeholder   = "请输入模板关键词"
        searchField.font          = .systemFont(ofSize: 14)
        searchField.textColor     = .appTextPrimary
        searchField.backgroundColor = .clear
        searchField.returnKeyType = .search
        searchField.delegate      = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)

        searchBtn.setTitle("搜索", for: .normal)
        searchBtn.setTitleColor(.appPrimary, for: .normal)
        searchBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        searchBtn.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        searchBtn.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchBtn)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 12),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 44),

            magnifier.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            magnifier.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            magnifier.widthAnchor.constraint(equalToConstant: 16),
            magnifier.heightAnchor.constraint(equalToConstant: 16),

            searchBtn.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            searchBtn.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: magnifier.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchBtn.leadingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
        ])
    }

    @objc private func searchTapped() {
        searchKeyword = searchField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        view.endEditing(true)
        applySearch()
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
            categoryView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 10),
            categoryView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    // MARK: - 筛选栏

    private func setupFilterView() {
        filterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterView)

        styleBtn.setTitle("风格  ▾", for: .normal)
        styleBtn.setTitleColor(.appTextSecondary, for: .normal)
        styleBtn.titleLabel?.font = .systemFont(ofSize: 13)
        styleBtn.addTarget(self, action: #selector(styleBtnTapped), for: .touchUpInside)
        styleBtn.translatesAutoresizingMaskIntoConstraints = false
        filterView.addSubview(styleBtn)

        colorBtn.setTitle("颜色  ▾", for: .normal)
        colorBtn.setTitleColor(.appTextSecondary, for: .normal)
        colorBtn.titleLabel?.font = .systemFont(ofSize: 13)
        colorBtn.addTarget(self, action: #selector(colorBtnTapped), for: .touchUpInside)
        colorBtn.translatesAutoresizingMaskIntoConstraints = false
        filterView.addSubview(colorBtn)

        themeBtn.setTitle("贴合主题  ▾", for: .normal)
        themeBtn.setTitleColor(.appTextSecondary, for: .normal)
        themeBtn.titleLabel?.font = .systemFont(ofSize: 13)
        themeBtn.addTarget(self, action: #selector(themeBtnTapped), for: .touchUpInside)
        themeBtn.translatesAutoresizingMaskIntoConstraints = false
        filterView.addSubview(themeBtn)

        NSLayoutConstraint.activate([
            filterView.topAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: 4),
            filterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterView.heightAnchor.constraint(equalToConstant: 44),

            styleBtn.leadingAnchor.constraint(equalTo: filterView.leadingAnchor, constant: 16),
            styleBtn.centerYAnchor.constraint(equalTo: filterView.centerYAnchor),

            colorBtn.leadingAnchor.constraint(equalTo: styleBtn.trailingAnchor, constant: 12),
            colorBtn.centerYAnchor.constraint(equalTo: filterView.centerYAnchor),

            themeBtn.trailingAnchor.constraint(equalTo: filterView.trailingAnchor, constant: -16),
            themeBtn.centerYAnchor.constraint(equalTo: filterView.centerYAnchor),
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
        collectionView.contentInset  = UIEdgeInsets(top: 12, left: 0, bottom: 100, right: 0)
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
        bottomBar.backgroundColor = .appCardBackground
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        let sep = UIView()
        sep.backgroundColor = .appSeparator
        sep.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(sep)

        composeBtn.setTitle("合成PPT  →", for: .normal)
        composeBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        composeBtn.setTitleColor(.white, for: .normal)
        composeBtn.layer.cornerRadius = 22
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

            sep.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            composeBtn.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            composeBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            composeBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            composeBtn.heightAnchor.constraint(equalToConstant: 50),
            composeBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - 空状态标签（"最近使用"tab）

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

    // MARK: - API：筛选选项

    private func loadFilterOptions() {
        PPTAPIService.shared.fetchOptions { [weak self] result in
            guard let self, case .success(let options) = result else { return }
            let categories = options.filter { $0.type.lowercased() == "category" }
            let styles     = options.filter { $0.type.lowercased() == "style" }
            let colors     = options.filter { $0.type.lowercased() == "themecolor" }
            self.categoryOptions = [("全部场景", "")] + categories.map { ($0.name, $0.value) }
            self.styleOptions    = [("全部风格", "")] + styles.map    { ($0.name, $0.value) }
            self.colorOptions    = [("全部颜色", "")] + colors.map    { ($0.name, $0.value) }
            self.categoryView.configure(with: self.categoryOptions)
        }
    }

    // MARK: - API：分页加载模板

    private func loadTemplates(reset: Bool) {
        if reset {
            loadGeneration += 1
            currentPage       = 1
            isLoading         = false
            allTemplates      = []
            filteredTemplates = []
            hasMore           = true
            showSkeleton()
        }
        guard !isLoading, (reset || hasMore) else { return }
        isLoading = true
        let gen = loadGeneration

        PPTAPIService.shared.fetchTemplates(
            category:   selectedCategory.isEmpty ? nil : selectedCategory,
            style:      selectedStyle.isEmpty    ? nil : selectedStyle,
            themeColor: selectedColor.isEmpty    ? nil : selectedColor,
            page:       currentPage
        ) { [weak self] result in
            guard let self, self.loadGeneration == gen else { return }
            self.isLoading = false
            self.hideSkeleton()
            if case .success(let newTemplates) = result {
                self.allTemplates.append(contentsOf: newTemplates)
                self.hasMore     = newTemplates.count >= 20
                self.currentPage += 1
                self.applySearch()
            }
        }
    }

    /// 对 allTemplates 应用搜索关键词和贴合主题排序，结果写入 filteredTemplates
    private func applySearch() {
        var result = allTemplates
        if !searchKeyword.isEmpty {
            result = result.filter { $0.subject.localizedCaseInsensitiveContains(searchKeyword) }
        }
        if themeFirst {
            // 从 markdown 第一行 "# 主题" 提取主题词
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

    // MARK: - 筛选器 Actions

    @objc private func styleBtnTapped() {
        let options = styleOptions.map { $0.name }
        let current = styleOptions.firstIndex { $0.value == selectedStyle } ?? 0
        let picker  = FilterPickerViewController(title: "风格", options: options, selectedIndex: current)
        picker.onSelect = { [weak self] index in
            guard let self, index < self.styleOptions.count else { return }
            let sel = self.styleOptions[index]
            self.selectedStyle = sel.value
            let title = sel.value.isEmpty ? "风格  ▾" : "\(sel.name)  ▾"
            self.styleBtn.setTitle(title, for: .normal)
            self.styleBtn.setTitleColor(sel.value.isEmpty ? .appTextSecondary : .appPrimary, for: .normal)
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
            let title = sel.value.isEmpty ? "颜色  ▾" : "\(sel.name)  ▾"
            self.colorBtn.setTitle(title, for: .normal)
            self.colorBtn.setTitleColor(sel.value.isEmpty ? .appTextSecondary : .appPrimary, for: .normal)
            self.loadTemplates(reset: true)
        }
        present(picker, animated: false)
    }

    @objc private func themeBtnTapped() {
        themeFirst.toggle()
        let title = themeFirst ? "贴合主题  ✓" : "贴合主题  ▾"
        themeBtn.setTitle(title, for: .normal)
        themeBtn.setTitleColor(themeFirst ? .appPrimary : .appTextSecondary, for: .normal)
        applySearch()
    }

    // MARK: - 合成PPT

    @objc private func composeTapped() {
        guard let template = selectedTemplate else {
            let alert = UIAlertController(title: "请先选择模板",
                                          message: "点击一个模板后再合成PPT",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }

        setComposeLoading(true)

        PPTAPIService.shared.generatePptx(
            taskId:     taskId,
            templateId: template.id,
            markdown:   markdown
        ) { [weak self] result in
            guard let self else { return }
            self.setComposeLoading(false)
            switch result {
            case .success(let pptId):
                let msg   = pptId.isEmpty ? "PPT 已生成" : "PPT 已生成\nID: \(pptId)"
                let alert = UIAlertController(title: "合成成功", message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                self.present(alert, animated: true)
            case .failure(let error):
                let alert = UIAlertController(title: "合成失败",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
        }
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
            composeBtn.setTitle("合成PPT  →", for: .normal)
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
        let prev     = selectedTemplate
        let tapped   = filteredTemplates[indexPath.item]
        selectedTemplate = tapped

        // 仅刷新受影响的两个 cell，避免全量 reloadData 闪烁
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

// MARK: - UITextFieldDelegate

extension TemplateSelectorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTapped(); return true
    }
}

// MARK: - Footer

private class SelectorFooterView: UICollectionReusableView {

    static let reuseID = "SelectorFooterView"

    private let label = UILabel()

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
