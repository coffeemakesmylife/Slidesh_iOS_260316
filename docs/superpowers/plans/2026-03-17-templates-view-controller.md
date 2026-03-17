# TemplatesViewController Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善 TemplatesViewController，实现分类横向滚动、风格/颜色筛选、网格/列表双布局切换的模板浏览界面。

**Architecture:** ViewController 持有三个独立 View 组件（CategorySelectorView、FilterAndToggleBar、TemplateCollectionView），通过闭包回调向上传递事件。TemplateCell 内部根据 LayoutMode 枚举切换约束，避免两套 Cell 类。Mock 数据通过 TemplateModel struct 提供。

**Tech Stack:** UIKit, UICollectionView, UICollectionViewCompositionalLayout, SnapKit (已有), CAGradientLayer

---

## 文件结构

| 路径 | 操作 | 职责 |
|------|------|------|
| `Slidesh/Models/TemplateModel.swift` | 新建 | 模板数据模型 + Mock 数据 |
| `Slidesh/Views/CategorySelectorView.swift` | 新建 | 分类横向滚动选择器 |
| `Slidesh/Views/FilterAndToggleBar.swift` | 新建 | 风格/颜色筛选 + 网格/列表切换 |
| `Slidesh/Views/TemplateCell.swift` | 新建 | 网格/列表双形态 CollectionView Cell |
| `Slidesh/ViewControllers/TemplatesViewController.swift` | 修改 | 主控制器，组合所有组件，管理状态 |

---

## Chunk 1: 数据模型与 Mock 数据

### Task 1: 创建 TemplateModel

**Files:**
- Create: `Slidesh/Models/TemplateModel.swift`

- [ ] **Step 1: 创建模型文件**

```swift
// Slidesh/Models/TemplateModel.swift

import UIKit

// 布局模式（定义在此处，被 TemplateCell / FilterAndToggleBar / TemplatesViewController 共用）
enum LayoutMode {
    case grid
    case list
}

// 模板分类
enum TemplateCategory: String, CaseIterable {
    case all       = "全部场景"
    case report    = "总结汇报"
    case education = "教育培训"
    case medical   = "医学医疗"
    case other     = "其他"
}

// 模板风格
enum TemplateStyle: String, CaseIterable {
    case all        = "全部风格"
    case business   = "商务"
    case creative   = "创意"
    case minimalist = "简约"
    case tech       = "科技"
}

// 模板颜色主题
enum TemplateColor: String, CaseIterable {
    case all    = "全部颜色"
    case blue   = "蓝色"
    case red    = "红色"
    case green  = "绿色"
    case purple = "紫色"
    case orange = "橙色"
}

// 模板数据模型
struct TemplateModel {
    let id: String
    let name: String
    let description: String
    let category: TemplateCategory
    let style: TemplateStyle
    let color: TemplateColor
    /// 渐变颜色对，用于预览图占位渲染
    let gradientColors: [UIColor]
    let usageCount: Int
}

// MARK: - Mock 数据

extension TemplateModel {
    static let mockData: [TemplateModel] = [
        .init(id: "1", name: "季度总结报告", description: "适合企业季度业绩汇报，专业简洁",
              category: .report, style: .business, color: .blue,
              gradientColors: [UIColor(red: 0.039, green: 0.094, blue: 0.260, alpha: 1),
                               UIColor(red: 0.471, green: 0.710, blue: 0.953, alpha: 1)],
              usageCount: 3842),

        .init(id: "2", name: "项目进度汇报", description: "清晰展示里程碑与进度",
              category: .report, style: .business, color: .green,
              gradientColors: [UIColor(red: 0.05, green: 0.45, blue: 0.30, alpha: 1),
                               UIColor(red: 0.40, green: 0.85, blue: 0.60, alpha: 1)],
              usageCount: 2156),

        .init(id: "3", name: "课程教学课件", description: "生动活泼，适合课堂讲解",
              category: .education, style: .creative, color: .orange,
              gradientColors: [UIColor(red: 0.80, green: 0.35, blue: 0.05, alpha: 1),
                               UIColor(red: 0.98, green: 0.75, blue: 0.30, alpha: 1)],
              usageCount: 5621),

        .init(id: "4", name: "培训方案设计", description: "系统化培训内容结构",
              category: .education, style: .minimalist, color: .purple,
              gradientColors: [UIColor(red: 0.35, green: 0.10, blue: 0.70, alpha: 1),
                               UIColor(red: 0.75, green: 0.50, blue: 0.98, alpha: 1)],
              usageCount: 1890),

        .init(id: "5", name: "临床病例分析", description: "规范医疗数据展示格式",
              category: .medical, style: .business, color: .blue,
              gradientColors: [UIColor(red: 0.10, green: 0.30, blue: 0.70, alpha: 1),
                               UIColor(red: 0.40, green: 0.70, blue: 0.95, alpha: 1)],
              usageCount: 987),

        .init(id: "6", name: "科技产品发布", description: "未来感十足，科技感强",
              category: .other, style: .tech, color: .blue,
              gradientColors: [UIColor(red: 0.02, green: 0.02, blue: 0.15, alpha: 1),
                               UIColor(red: 0.10, green: 0.60, blue: 0.90, alpha: 1)],
              usageCount: 4320),

        .init(id: "7", name: "年度工作总结", description: "全面回顾年度成果与规划",
              category: .report, style: .business, color: .red,
              gradientColors: [UIColor(red: 0.65, green: 0.10, blue: 0.10, alpha: 1),
                               UIColor(red: 0.98, green: 0.45, blue: 0.45, alpha: 1)],
              usageCount: 6102),

        .init(id: "8", name: "创意头脑风暴", description: "激发创意，碰撞想法",
              category: .other, style: .creative, color: .orange,
              gradientColors: [UIColor(red: 0.85, green: 0.42, blue: 0.02, alpha: 1),
                               UIColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1)],
              usageCount: 2780),

        .init(id: "9", name: "医疗健康科普", description: "通俗易懂的医学知识传播",
              category: .medical, style: .creative, color: .green,
              gradientColors: [UIColor(red: 0.05, green: 0.55, blue: 0.40, alpha: 1),
                               UIColor(red: 0.30, green: 0.90, blue: 0.65, alpha: 1)],
              usageCount: 1543),

        .init(id: "10", name: "极简商务报告", description: "少即是多，留白设计哲学",
              category: .report, style: .minimalist, color: .purple,
              gradientColors: [UIColor(red: 0.28, green: 0.08, blue: 0.55, alpha: 1),
                               UIColor(red: 0.65, green: 0.45, blue: 0.92, alpha: 1)],
              usageCount: 3310),
    ]
}
```

- [ ] **Step 2: 在 Xcode 中确认文件加入 Target，Build 验证无报错**

- [ ] **Step 3: Commit**

```bash
git add Slidesh/Models/TemplateModel.swift
git commit -m "新增 TemplateModel 及 Mock 数据"
```

---

## Chunk 2: CategorySelectorView

### Task 2: 横向分类选择器

**Files:**
- Create: `Slidesh/Views/CategorySelectorView.swift`

- [ ] **Step 1: 创建文件**

```swift
// Slidesh/Views/CategorySelectorView.swift

import UIKit

// 横向滚动分类选择器，选中时标签背景变为主色，文字变白
class CategorySelectorView: UIView {

    var onCategorySelected: ((TemplateCategory) -> Void)?
    private(set) var selectedCategory: TemplateCategory = .all

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        TemplateCategory.allCases.forEach { category in
            let btn = makeButton(title: category.rawValue)
            btn.tag = TemplateCategory.allCases.firstIndex(of: category) ?? 0
            btn.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
            buttons.append(btn)
        }

        updateButtonStates()
    }

    private func makeButton(title: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = .systemFont(ofSize: 14, weight: .medium); return a
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        config.cornerStyle = .capsule
        let btn = UIButton(configuration: config)
        // 颜色在 updateButtonStates() 中设置
        return btn
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let category = TemplateCategory.allCases[sender.tag]
        selectedCategory = category
        updateButtonStates()
        onCategorySelected?(category)
    }

    private func updateButtonStates() {
        for (index, btn) in buttons.enumerated() {
            let isSelected = TemplateCategory.allCases[index] == selectedCategory
            btn.configuration?.baseBackgroundColor = isSelected ? .appPrimary : .appPrimarySubtle
            btn.configuration?.baseForegroundColor = isSelected ? .white : .appPrimary
        }
    }
}
```

- [ ] **Step 2: Build 验证无报错**

- [ ] **Step 3: Commit**

```bash
git add Slidesh/Views/CategorySelectorView.swift
git commit -m "新增 CategorySelectorView 横向分类选择器"
```

---

## Chunk 3: FilterAndToggleBar

### Task 3: 筛选栏 + 布局切换

**Files:**
- Create: `Slidesh/Views/FilterAndToggleBar.swift`

- [ ] **Step 1: 创建文件**

```swift
// Slidesh/Views/FilterAndToggleBar.swift

import UIKit

// 筛选栏：左侧风格/颜色筛选按钮，右侧网格/列表切换（LayoutMode 定义在 TemplateModel.swift）
class FilterAndToggleBar: UIView {

    var onStyleFilter: (() -> Void)?
    var onColorFilter: (() -> Void)?
    var onLayoutToggle: ((LayoutMode) -> Void)?

    private(set) var layoutMode: LayoutMode = .grid

    // 对外暴露，让 VC 可更新选中文字
    let styleButton  = FilterChipButton(title: "风格")
    let colorButton  = FilterChipButton(title: "颜色")
    private let toggleButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let leftStack = UIStackView(arrangedSubviews: [styleButton, colorButton])
        leftStack.axis = .horizontal
        leftStack.spacing = 8

        toggleButton.setImage(UIImage(systemName: "square.grid.2x2"), for: .normal)
        toggleButton.tintColor = .appTextSecondary
        toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)

        [leftStack, toggleButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            toggleButton.widthAnchor.constraint(equalToConstant: 36),
            toggleButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        styleButton.addTarget(self, action: #selector(styleTapped), for: .touchUpInside)
        colorButton.addTarget(self, action: #selector(colorTapped), for: .touchUpInside)
    }

    @objc private func styleTapped() { onStyleFilter?() }
    @objc private func colorTapped() { onColorFilter?() }

    @objc private func toggleTapped() {
        layoutMode = layoutMode == .grid ? .list : .grid
        let icon = layoutMode == .grid ? "square.grid.2x2" : "list.bullet"
        toggleButton.setImage(UIImage(systemName: icon), for: .normal)
        onLayoutToggle?(layoutMode)
    }

    // 更新筛选按钮选中状态标题
    func setStyleTitle(_ title: String, active: Bool) {
        styleButton.setFilterTitle(title, active: active)
    }

    func setColorTitle(_ title: String, active: Bool) {
        colorButton.setFilterTitle(title, active: active)
    }
}

// MARK: - FilterChipButton

// 带下箭头的筛选胶囊按钮
class FilterChipButton: UIControl {

    private let titleLabel  = UILabel()
    private let chevronView = UIImageView()
    private var isActive = false

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = 14
        layer.borderWidth = 1

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        chevronView.image = UIImage(systemName: "chevron.down",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        chevronView.contentMode = .scaleAspectFit

        let stack = UIStackView(arrangedSubviews: [titleLabel, chevronView])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        updateStyle()
    }

    func setFilterTitle(_ title: String, active: Bool) {
        titleLabel.text = title
        isActive = active
        updateStyle()
    }

    private func updateStyle() {
        let color: UIColor = isActive ? .appPrimary : .appTextSecondary
        titleLabel.textColor = color
        chevronView.tintColor = color
        layer.borderColor = isActive ? UIColor.appPrimary.cgColor : UIColor.appCardBorder.cgColor
        backgroundColor = isActive ? .appPrimarySubtle : .clear
    }
}
```

- [ ] **Step 2: Build 验证无报错**

- [ ] **Step 3: Commit**

```bash
git add Slidesh/Views/FilterAndToggleBar.swift
git commit -m "新增 FilterAndToggleBar 筛选栏与布局切换"
```

---

## Chunk 4: TemplateCell

### Task 4: 双形态模板 Cell

**Files:**
- Create: `Slidesh/Views/TemplateCell.swift`

- [ ] **Step 1: 创建文件**

```swift
// Slidesh/Views/TemplateCell.swift

import UIKit

// 模板 CollectionView Cell，支持网格/列表两种布局形态
class TemplateCell: UICollectionViewCell {

    static let reuseID = "TemplateCell"

    // MARK: - 子视图

    // 预览图（渐变色占位）
    private let previewView      = UIView()
    private let gradientLayer    = CAGradientLayer()

    private let nameLabel        = UILabel()
    private let descLabel        = UILabel()
    private let usageLabel       = UILabel()

    // 列表模式：右侧信息容器
    private let infoStack        = UIStackView()

    // 当前布局模式下的活跃约束组
    private var gridConstraints:  [NSLayoutConstraint] = []
    private var listConstraints:  [NSLayoutConstraint] = []
    private var currentMode: LayoutMode = .grid

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
    }

    // MARK: - 视图配置

    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        contentView.backgroundColor = .appCardBackground.withAlphaComponent(0.65)

        // 渐变预览
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        previewView.layer.addSublayer(gradientLayer)
        previewView.layer.cornerRadius = 12
        previewView.clipsToBounds = true
        previewView.translatesAutoresizingMaskIntoConstraints = false

        // 标题
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .appTextPrimary
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // 描述（列表模式使用）
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .appTextSecondary
        descLabel.numberOfLines = 2
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        // 使用次数（列表模式使用）
        usageLabel.font = .systemFont(ofSize: 11)
        usageLabel.textColor = .appTextTertiary
        usageLabel.translatesAutoresizingMaskIntoConstraints = false

        // 信息纵向堆叠（列表专用）
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.alignment = .leading
        infoStack.addArrangedSubview(nameLabel)
        infoStack.addArrangedSubview(descLabel)
        infoStack.addArrangedSubview(usageLabel)
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(previewView)
        contentView.addSubview(infoStack)
    }

    private func setupConstraints() {
        let p = contentView

        // 网格：预览图上方铺满，标题在下
        gridConstraints = [
            previewView.topAnchor.constraint(equalTo: p.topAnchor, constant: 10),
            previewView.leadingAnchor.constraint(equalTo: p.leadingAnchor, constant: 10),
            previewView.trailingAnchor.constraint(equalTo: p.trailingAnchor, constant: -10),
            previewView.heightAnchor.constraint(equalTo: p.widthAnchor, multiplier: 0.62),

            infoStack.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 8),
            infoStack.leadingAnchor.constraint(equalTo: p.leadingAnchor, constant: 10),
            infoStack.trailingAnchor.constraint(equalTo: p.trailingAnchor, constant: -10),
            infoStack.bottomAnchor.constraint(lessThanOrEqualTo: p.bottomAnchor, constant: -10),
        ]

        // 列表：预览图左侧固定宽，信息在右
        listConstraints = [
            previewView.topAnchor.constraint(equalTo: p.topAnchor, constant: 10),
            previewView.leadingAnchor.constraint(equalTo: p.leadingAnchor, constant: 12),
            previewView.bottomAnchor.constraint(equalTo: p.bottomAnchor, constant: -10),
            previewView.widthAnchor.constraint(equalToConstant: 90),

            infoStack.leadingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: 12),
            infoStack.trailingAnchor.constraint(equalTo: p.trailingAnchor, constant: -12),
            infoStack.centerYAnchor.constraint(equalTo: p.centerYAnchor),
        ]

        applyMode(.grid)
    }

    // MARK: - 公开接口

    func configure(with model: TemplateModel, mode: LayoutMode) {
        nameLabel.text = model.name
        descLabel.text = model.description
        usageLabel.text = "已使用 \(model.usageCount.formatted()) 次"

        let cgColors = model.gradientColors.map { $0.cgColor }
        gradientLayer.colors = cgColors

        if mode != currentMode {
            applyMode(mode)
        }

        // 列表模式：显示描述和使用量；网格模式：隐藏
        descLabel.isHidden  = (mode == .grid)
        usageLabel.isHidden = (mode == .grid)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = previewView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 重置模式，确保 configure() 每次都正确调用 applyMode()
        currentMode = .grid
        NSLayoutConstraint.deactivate(listConstraints)
        NSLayoutConstraint.activate(gridConstraints)
    }

    // MARK: - 约束切换

    private func applyMode(_ mode: LayoutMode) {
        currentMode = mode
        if mode == .grid {
            NSLayoutConstraint.deactivate(listConstraints)
            NSLayoutConstraint.activate(gridConstraints)
        } else {
            NSLayoutConstraint.deactivate(gridConstraints)
            NSLayoutConstraint.activate(listConstraints)
        }
    }
}
```

- [ ] **Step 2: Build 验证无报错**

- [ ] **Step 3: Commit**

```bash
git add Slidesh/Views/TemplateCell.swift
git commit -m "新增 TemplateCell 双形态网格/列表 Cell"
```

---

## Chunk 5: TemplatesViewController 主控制器

### Task 5: 组装完整界面

**Files:**
- Modify: `Slidesh/ViewControllers/TemplatesViewController.swift`

- [ ] **Step 1: 替换 TemplatesViewController 全部内容**

```swift
// Slidesh/ViewControllers/TemplatesViewController.swift

import UIKit

class TemplatesViewController: UIViewController {

    // MARK: - 状态

    private var layoutMode: LayoutMode = .grid
    private var selectedCategory: TemplateCategory = .all
    private var selectedStyle: TemplateStyle = .all
    private var selectedColor: TemplateColor = .all

    private var filteredData: [TemplateModel] = TemplateModel.mockData

    // MARK: - 子视图

    private let categoryView   = CategorySelectorView()
    private let filterBar      = FilterAndToggleBar()
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
            filterBar.topAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: 8),
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
            let styleMatch    = selectedStyle == .all    || model.style == selectedStyle
            let colorMatch    = selectedColor == .all    || model.color == selectedColor
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

    // MARK: - 筛选弹窗（UIAlertController 实现选项列表）

    private func showStylePicker() {
        let alert = UIAlertController(title: "选择风格", message: nil, preferredStyle: .actionSheet)
        TemplateStyle.allCases.forEach { style in
            let action = UIAlertAction(title: style.rawValue, style: .default) { [weak self] _ in
                self?.selectedStyle = style
                let isActive = style != .all
                self?.filterBar.setStyleTitle(style.rawValue, active: isActive)
                self?.applyFilters()
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        // iPad 适配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterBar.styleButton
            popover.sourceRect = filterBar.styleButton.bounds
        }
        present(alert, animated: true)
    }

    private func showColorPicker() {
        let alert = UIAlertController(title: "选择颜色", message: nil, preferredStyle: .actionSheet)
        TemplateColor.allCases.forEach { color in
            let action = UIAlertAction(title: color.rawValue, style: .default) { [weak self] _ in
                self?.selectedColor = color
                let isActive = color != .all
                self?.filterBar.setColorTitle(color.rawValue, active: isActive)
                self?.applyFilters()
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterBar.colorButton
            popover.sourceRect = filterBar.colorButton.bounds
        }
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension TemplatesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
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
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let template = filteredData[indexPath.item]
        print("选中模板: \(template.name)")
        // TODO: 跳转模板详情页
    }
}
```

- [ ] **Step 2: Build，在模拟器运行，验证以下功能：**
  - 分类标签横向滚动，点击后高亮且过滤列表
  - 风格/颜色按钮弹出 ActionSheet 并更新筛选
  - 右侧切换按钮在网格/列表间切换，布局动画正常
  - 网格模式：2列，上方预览图，下方标题
  - 列表模式：左侧预览图，右侧标题+描述+使用次数

- [ ] **Step 3: Commit**

```bash
git add Slidesh/ViewControllers/TemplatesViewController.swift
git commit -m "完善 TemplatesViewController：分类选择、筛选、网格/列表切换"
```

---

## 验收标准

| 功能点 | 验证方式 |
|--------|---------|
| 分类标签 5 个，横向可滚动 | 手动滑动 |
| 点击分类高亮并过滤数据 | 切换各分类，列表更新 |
| 风格/颜色筛选叠加生效 | 先选分类再选风格，数量正确缩减 |
| 网格/列表布局切换有动画 | 点击右上切换按钮 |
| 网格模式 2 列，预览图正常显示渐变 | 视觉确认 |
| 列表模式显示描述和使用次数 | 视觉确认 |
| 深色/浅色主题均正常 | Settings 切换主题后返回确认 |
