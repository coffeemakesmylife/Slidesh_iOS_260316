# Skeleton Loading & Template Cache Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add SkeletonView placeholder animation on load/filter-switch, plus stale-while-revalidate cache for templates and filter options.

**Architecture:** New `TemplateCache` service (memory NSCache + disk JSON); `PPTTemplate`/`PPTOption` get dict serialization helpers; `TemplateCell` gains `isSkeletonable`; `TemplatesViewController` conforms to `SkeletonCollectionViewDataSource` and routes all first-page loads through the cache.

**Tech Stack:** SkeletonView (already in Podfile), NSCache, FileManager + JSONSerialization, Bundle version + Locale for cache key scoping.

**Spec:** `docs/superpowers/specs/2026-03-17-skeleton-cache-design.md`

---

## Chunk 1: Model serialization + TemplateCache service

### Task 1: Add dict serialization to model structs

**Files:**
- Modify: `Slidesh/Models/TemplateModel.swift`

TemplateCache needs to convert `[PPTTemplate]` ↔ `[[String: Any]]` for disk storage. Add an `init?(dictionary:)` and `asDictionary` to `PPTTemplate`. `PPTOption` is handled inline in the cache (no struct change needed).

**Note on coexistence with PPTAPIService:** `PPTAPIService.parseTemplates` parses the raw decrypted API response and is not touched (spec: "No change"). `PPTAPIService.parseTemplates` is **private**, so `TemplateCache` cannot call it. Instead, `TemplateCache` stores `[[String: Any]]` (the same dictionary format parseTemplates consumes) and reconstructs models via `PPTTemplate.init?(dictionary:)`. The stored data format on disk is identical to what parseTemplates would receive — no duplication of parsing logic, just a separate entry point that is necessary because parseTemplates is inaccessible.

- [ ] **Step 1: Add the serialization extension to TemplateModel.swift**

Append this block at the bottom of the file (after the existing `PPTOption` struct):

```swift
// MARK: - 缓存序列化辅助（供 TemplateCache 磁盘存取使用）

extension PPTTemplate {
    /// 从字典还原模型（字段与 API 响应一致）
    init?(dictionary: [String: Any]) {
        guard let id       = dictionary["id"]       as? String,
              let coverUrl = dictionary["coverUrl"]  as? String,
              let subject  = dictionary["subject"]   as? String
        else { return nil }
        self.id         = id
        self.type       = dictionary["type"]       as? Int    ?? 1
        self.coverUrl   = coverUrl
        self.category   = dictionary["category"]   as? String ?? ""
        self.style      = dictionary["style"]      as? String ?? ""
        self.themeColor = dictionary["themeColor"] as? String ?? ""
        self.subject    = subject
        self.num        = dictionary["num"]        as? Int    ?? 0
        self.createTime = dictionary["createTime"] as? String ?? ""
    }

    /// 序列化为字典（JSONSerialization 兼容）
    var asDictionary: [String: Any] {
        [
            "id":         id,
            "type":       type,
            "coverUrl":   coverUrl,
            "category":   category,
            "style":      style,
            "themeColor": themeColor,
            "subject":    subject,
            "num":        num,
            "createTime": createTime,
        ]
    }
}
```

- [ ] **Step 2: Build the project to confirm no compile errors**

In Xcode: Product → Build (⌘B). Expected: Build Succeeded.

---

### Task 2: Create TemplateCache service

**Files:**
- Create: `Slidesh/Services/TemplateCache.swift`

The cache has two levels: NSCache (memory) and JSON files on disk. All disk writes are serialized. TTL: templates = 10 min, options = 24 h. Background refresh triggers at ≥ 80 % TTL.

**Cache key design:** `appVersion` = `CFBundleShortVersionString` (e.g. `"1.0"`); `lang` = `Locale.preferredLanguages.first ?? "zh"` (e.g. `"zh-Hans"`). Both are in the `TemplateCache` private static vars. **Orphan cleanup split logic:** `filename(for:)` keeps `_` in the safe character set, so the key `options_1.0_zh-Hans` becomes filename `options_1.0_zh-Hans.json`. Splitting the base on `_` yields `["options", "1.0", "zh-Hans"]`; `components[1]` is therefore the version segment. This is correct because `type` is constrained to values without underscores (`"options"`, `"templates"`). **isAging** is a computed property on `CacheEntry` (`age >= ttl * 0.8`), recalculated on every call — no stored boolean. **Eviction** in `evictIfNeeded` deletes the single file with the oldest `contentModificationDate` (LRU by modification date).

- [ ] **Step 1: Create the file**

Create `Slidesh/Services/TemplateCache.swift` with the following complete content:

```swift
//
//  TemplateCache.swift
//  Slidesh
//
//  版本/语言感知的模板缓存服务（内存 + 磁盘两级，stale-while-revalidate）
//

import Foundation

// MARK: - 缓存查询结果

enum CacheFetchResult {
    case fresh(Any)  // 未过期；调用方用 isAging(key:) 判断是否触发后台刷新
    case stale(Any)  // 已过期但有旧数据；调用方立即展示并前台刷新
    case miss        // 无缓存
}

// MARK: - 缓存条目（NSCache value 必须是 AnyObject）

private final class CacheEntry: NSObject {
    let data:      Any
    let timestamp: TimeInterval
    let ttl:       TimeInterval

    init(data: Any, timestamp: TimeInterval, ttl: TimeInterval) {
        self.data      = data
        self.timestamp = timestamp
        self.ttl       = ttl
    }

    var age:       TimeInterval { Date().timeIntervalSince1970 - timestamp }
    var isExpired: Bool         { age >= ttl }
    var isAging:   Bool         { age >= ttl * 0.8 }
}

// MARK: - TemplateCache

final class TemplateCache {

    static let shared = TemplateCache()
    private init() {}

    static let templatesTTL: TimeInterval = 10 * 60          // 10 分钟
    static let optionsTTL:   TimeInterval = 24 * 60 * 60     // 24 小时

    private let memory    = NSCache<NSString, CacheEntry>()
    // 所有磁盘写操作通过串行队列，防止并发冲突
    private let diskQueue = DispatchQueue(label: "com.slidesh.cache.disk", qos: .utility)

    // MARK: - Key 生成

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private static var lang: String {
        Locale.preferredLanguages.first ?? "zh"
    }

    /// type 只允许 "options"（无下划线），不含筛选/页码后缀
    static func optionsKey() -> String {
        "options_\(appVersion)_\(lang)"
    }

    /// type 只允许 "templates"（无下划线）；未选中的筛选传空字符串，位置固定
    static func templatesKey(category: String, style: String,
                             color: String, page: Int = 1) -> String {
        "templates_\(appVersion)_\(lang)_\(category)_\(style)_\(color)_p\(page)"
    }

    // MARK: - 模板读写

    func fetchTemplates(key: String) -> CacheFetchResult {
        switch fetchRaw(key: key) {
        case .fresh(let data):
            guard let t = decodeTemplates(data) else { return .miss }
            return .fresh(t)
        case .stale(let data):
            guard let t = decodeTemplates(data) else { return .miss }
            return .stale(t)
        case .miss:
            return .miss
        }
    }

    func storeTemplates(key: String, templates: [PPTTemplate]) {
        store(key: key, data: templates.map { $0.asDictionary }, ttl: Self.templatesTTL)
    }

    // MARK: - 筛选选项读写

    func fetchOptions(key: String) -> CacheFetchResult {
        switch fetchRaw(key: key) {
        case .fresh(let data):
            guard let o = decodeOptions(data) else { return .miss }
            return .fresh(o)
        case .stale(let data):
            guard let o = decodeOptions(data) else { return .miss }
            return .stale(o)
        case .miss:
            return .miss
        }
    }

    func storeOptions(key: String, options: [PPTOption]) {
        let encoded = options.map { ["name": $0.name, "type": $0.type, "value": $0.value] }
        store(key: key, data: encoded, ttl: Self.optionsTTL)
    }

    /// 缓存是否接近过期（≥80% TTL），供调用方决定是否触发后台刷新
    func isAging(key: String) -> Bool {
        memory.object(forKey: key as NSString)?.isAging ?? false
    }

    // MARK: - 孤立文件清理（App 启动时调用）

    func cleanupOrphanedFiles() {
        let currentVersion = Self.appVersion
        diskQueue.async { [weak self] in
            guard let dir   = self?.cacheDir,
                  let files = try? FileManager.default.contentsOfDirectory(
                      at: dir, includingPropertiesForKeys: nil,
                      options: .skipsHiddenFiles)
            else { return }

            for file in files {
                // Key 格式：{type}_{appVersion}_{lang}...
                // type 不含下划线，index 1 即版本号，做精确匹配
                let base       = file.deletingPathExtension().lastPathComponent
                let components = base.split(separator: "_",
                                            omittingEmptySubsequences: false).map(String.init)
                if components.count < 2 || components[1] != currentVersion {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - 私有：内部通用 fetch

    private func fetchRaw(key: String) -> CacheFetchResult {
        // 1. 内存命中
        if let entry = memory.object(forKey: key as NSString) {
            if !entry.isExpired { return .fresh(entry.data) }
            memory.removeObject(forKey: key as NSString)
        }
        // 2. 磁盘命中
        if let entry = loadFromDisk(key: key) {
            memory.setObject(entry, forKey: key as NSString)
            return entry.isExpired ? .stale(entry.data) : .fresh(entry.data)
        }
        return .miss
    }

    private func store(key: String, data: Any, ttl: TimeInterval) {
        let entry = CacheEntry(data: data,
                               timestamp: Date().timeIntervalSince1970,
                               ttl: ttl)
        memory.setObject(entry, forKey: key as NSString)
        diskQueue.async { [weak self] in
            self?.writeToDisk(key: key, entry: entry)
        }
    }

    // MARK: - 磁盘 I/O

    private var cacheDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PPTTemplateCache")
    }

    private func ensureCacheDir() -> URL? {
        guard let dir = cacheDir else { return nil }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 只允许 [A-Za-z0-9._-]，其余替换为 -
    private func filename(for key: String) -> String {
        let safe = key.unicodeScalars.map { scalar -> Character in
            let c = Character(scalar)
            return (c.isLetter || c.isNumber || c == "." || c == "_" || c == "-") ? c : "-"
        }
        return String(safe) + ".json"
    }

    private func writeToDisk(key: String, entry: CacheEntry) {
        guard let dir = ensureCacheDir(),
              JSONSerialization.isValidJSONObject(entry.data) else { return }

        evictIfNeeded(dir: dir)

        let envelope: [String: Any] = [
            "timestamp": entry.timestamp,
            "ttl":       entry.ttl,
            "data":      entry.data,
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: envelope) else { return }
        try? bytes.write(to: dir.appendingPathComponent(filename(for: key)))
    }

    private func loadFromDisk(key: String) -> CacheEntry? {
        guard let dir  = cacheDir else { return nil }
        let fileURL    = dir.appendingPathComponent(filename(for: key))
        guard let bytes     = try? Data(contentsOf: fileURL),
              let envelope  = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let timestamp = envelope["timestamp"] as? TimeInterval,
              let ttl       = envelope["ttl"]       as? TimeInterval,
              let data      = envelope["data"]
        else { return nil }
        return CacheEntry(data: data, timestamp: timestamp, ttl: ttl)
    }

    /// 超过 50 个文件时删除最旧的（已在 diskQueue 上调用）
    private func evictIfNeeded(dir: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles),
              files.count >= 50 else { return }

        let oldest = files.min {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            return a < b
        }
        if let oldest { try? fm.removeItem(at: oldest) }
    }

    // MARK: - 解码辅助

    private func decodeTemplates(_ data: Any) -> [PPTTemplate]? {
        guard let arr = data as? [[String: Any]] else { return nil }
        return arr.compactMap { PPTTemplate(dictionary: $0) }
    }

    private func decodeOptions(_ data: Any) -> [PPTOption]? {
        guard let arr = data as? [[String: Any]] else { return nil }
        return arr.compactMap { dict -> PPTOption? in
            guard let name  = dict["name"]  as? String,
                  let type  = dict["type"]  as? String,
                  let value = dict["value"] as? String else { return nil }
            return PPTOption(name: name, type: type, value: value)
        }
    }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode: right-click `Services` group → Add Files → select `TemplateCache.swift`. Ensure "Add to target: Slidesh" is checked.

- [ ] **Step 3: Build to confirm no compile errors**

Product → Build (⌘B). Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git add Slidesh/Models/TemplateModel.swift Slidesh/Services/TemplateCache.swift
git commit -m "Add TemplateCache service and PPTTemplate dict serialization"
```

---

## Chunk 2: SkeletonView integration + ViewController wiring + AppDelegate cleanup

### Task 3: Enable SkeletonView on TemplateCell

**Files:**
- Modify: `Slidesh/Views/TemplateCell.swift`

Mark all visual subviews as skeletonable. SkeletonView requires every view in the hierarchy from the cell down to the leaf views to have `isSkeletonable = true`.

- [ ] **Step 1: Add `import SkeletonView` at the top of TemplateCell.swift**

After `import Kingfisher`, add:
```swift
import SkeletonView
```

- [ ] **Step 2: Mark subviews as skeletonable inside `setupViews()`**

At the very **first line** of `setupViews()` body — before `contentView.layer.cornerRadius = 16` and all other existing code — add:

```swift
// SkeletonView：从 cell 到叶子视图全链路开启
isSkeletonable            = true
contentView.isSkeletonable = true
outerStack.isSkeletonable  = true
infoStack.isSkeletonable   = true
previewImageView.isSkeletonable = true
nameLabel.isSkeletonable   = true
descLabel.isSkeletonable   = true
usageLabel.isSkeletonable  = true
```

- [ ] **Step 3: Build to confirm no compile errors**

Product → Build (⌘B). Expected: Build Succeeded.

---

### Task 4: Rewrite TemplatesViewController with cache + SkeletonView

**Files:**
- Modify: `Slidesh/ViewControllers/TemplatesViewController.swift`

This is the largest change. Replace the entire file with the version below. Key differences from the current code:
- `import SkeletonView` added
- `loadGeneration` counter prevents stale completions (always mutated on main thread — all `PPTAPIService` callbacks already dispatch to main)
- `loadTemplates(reset:true)` immediately shows skeleton, checks cache, skips skeleton if cache hits
- `loadFilterOptions()` also routes through cache
- Conforms to `SkeletonCollectionViewDataSource` (replaces `UICollectionViewDataSource`; `SkeletonCollectionViewDataSource` inherits from `UICollectionViewDataSource` so the single conformance satisfies both the dataSource assignment in `setupCollectionView()` and SkeletonView's protocol requirements)
- `collectionView.isSkeletonable = true` in setup

- [ ] **Step 1: Replace TemplatesViewController.swift with the full new version**

```swift
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
                guard self.currentCacheKey() == key else { return }
                self.templates   = fresh
                self.hasMore     = fresh.count >= 20
                self.currentPage = 2
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

// MARK: - SkeletonCollectionViewDataSource + UICollectionViewDataSource

extension TemplatesViewController: SkeletonCollectionViewDataSource {

    // SkeletonView 在骨架屏期间调用此方法（不调用标准 numberOfItemsInSection）
    func collectionSkeletonView(_ skeletonView: UICollectionView,
                                numberOfCellsInSection section: Int) -> Int {
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
```

- [ ] **Step 2: Build to confirm no compile errors**

Product → Build (⌘B). Expected: Build Succeeded.

---

### Task 5: Add orphaned cache cleanup in AppDelegate

**Files:**
- Modify: `Slidesh/AppDelegate.swift`

On every app launch, delete cached files whose version segment doesn't match the current app version. This prevents unbounded disk growth after updates.

- [ ] **Step 1: Add cleanup call in `didFinishLaunchingWithOptions`**

In `AppDelegate.swift`, at the end of `didFinishLaunchingWithOptions` (just before `return true`), add:

```swift
// 清理旧版本遗留的缓存文件
TemplateCache.shared.cleanupOrphanedFiles()
```

- [ ] **Step 2: Build to confirm no compile errors**

Product → Build (⌘B). Expected: Build Succeeded.

- [ ] **Step 3: Commit all changes**

```bash
git add Slidesh/Views/TemplateCell.swift \
        Slidesh/ViewControllers/TemplatesViewController.swift \
        Slidesh/AppDelegate.swift
git commit -m "Add SkeletonView loading, template cache, orphan cleanup"
```

---

## Verification checklist (manual, on device/simulator)

- [ ] First launch: skeleton appears immediately, fades out when data loads
- [ ] Second launch (within 10 min): no skeleton, data shows instantly from cache
- [ ] Switch filter: skeleton appears, fades out when data loads
- [ ] Switch filter back: no skeleton if previously cached
- [ ] Scroll to bottom: pagination works, "— 到底了 —" appears at end
- [ ] Switch grid ↔ list: layout toggles correctly
