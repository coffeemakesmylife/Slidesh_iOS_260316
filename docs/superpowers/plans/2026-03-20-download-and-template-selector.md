# 下载大纲 & 挑选PPT模板 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 实现大纲下载（Markdown/纯文本）和 PPT 模板选择流程（先同步用户编辑→updateContent SSE→弹出模板选择器→选模板→合成PPT）。

**Architecture:** 下载使用 UIActivityViewController 分享临时文件；模板选择流程分三步：①收集 tableView 单元格编辑→重建 markdown，②调用 updateContent SSE 同步到服务端，③present TemplateSelectorViewController（全新独立 VC，复用 CategorySelectorView/TemplateCell）。TemplateSelectorViewController 包含 tab 栏、搜索框、分类筛选、模板网格、底部"合成PPT"按钮，选中模板后调用 generatePptx。

**Tech Stack:** UIKit, Kingfisher（封面图加载），PPTAPIService（SSE + JSON），现有 CategorySelectorView / FilterPickerViewController / TemplateCell。

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| 修改 | `Slidesh/Services/PPTAPIService.swift` | 新增 `updateContent`（SSE）、`generatePptx`（JSON POST）、私有 `postJSON` 辅助方法 |
| 修改 | `Slidesh/ViewControllers/OutlineViewController.swift` | 新增 cell 编辑回调→sections 同步、`reconstructMarkdown()`、`downloadTapped()` 实现、`templateTapped()` 实现（loading→updateContent→present selector） |
| 修改 | `Slidesh/Views/TemplateCell.swift` | 新增选中态高亮边框（`setSelectedState(_:)`） |
| 新建 | `Slidesh/ViewControllers/TemplateSelectorViewController.swift` | 完整模板选择器 VC：tab、搜索、分类、筛选、网格、底部合成按钮 |

---

## Task 1: PPTAPIService — 新增 updateContent 与 generatePptx

**Files:**
- Modify: `Slidesh/Services/PPTAPIService.swift`（在 `generateContent` 之后插入）

### 背景
- `updateContent` 是 SSE 接口（与 generateContent 完全相同的流式协议），将用户当前编辑的 markdown 同步到服务端。`question` 字段可选，本次传空（仅同步，不要求 AI 修改）。
- `generatePptx` 是普通 JSON POST，返回标准 `{code, newslist}` 格式，newslist 为 pptId 字符串。
- 现有 `post()` 辅助方法只支持 form-encoded body；需新增 `postJSON()` 支持 JSON body。

- [x] **Step 1: 在 `generateContent` 后插入 `updateContent`**

```swift
/// 同步用户编辑后的大纲到服务端（SSE），仅需 onComplete/onError，不关心增量 chunk
@discardableResult
func updateContent(
    taskId:     String,
    markdown:   String,
    question:   String?  = nil,
    onComplete: @escaping (String) -> Void,
    onError:    @escaping (Error)  -> Void
) -> URLSessionDataTask {
    let uuid = AppDelegate.getCurrentUserId() ?? "temp"
    var body: [String: Any] = [
        "taskId":   taskId,
        "markdown": markdown,
        "appId":    appId,
        "uuid":     uuid,
    ]
    if let q = question, !q.isEmpty { body["question"] = q }

    guard let url      = URL(string: baseURL + "/v1/api/ai/ppt/v2/updateContent"),
          let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
        DispatchQueue.main.async { onError(APIError.invalidURL) }
        return URLSession.shared.dataTask(with: URLRequest(url: URL(string: "about:blank")!))
    }
    var request = URLRequest(url: url, timeoutInterval: 120)
    request.httpMethod = "POST"
    request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.httpBody = bodyData

    let decrypt: (String) -> String? = { [weak self] encrypted in
        guard let self else { return nil }
        let decoded = encrypted.removingPercentEncoding ?? encrypted
        return RSAHelper.decryptString(decoded, publicKey: self.publicKey)
    }
    // onChunk 丢弃，只关注完成事件
    let delegate = SSEDelegate(decrypt: decrypt, onChunk: { _ in }, onComplete: onComplete, onError: onError)
    let session  = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    let task     = session.dataTask(with: request)
    task.resume()
    return task
}
```

- [x] **Step 2: 在私有方法区新增 `postJSON` 辅助方法**

```swift
/// JSON body 的通用 POST，解密逻辑与 post() 一致
private func postJSON(
    path:       String,
    body:       [String: Any],
    completion: @escaping (Result<Any, Error>) -> Void
) {
    guard let url      = URL(string: baseURL + path),
          let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
        DispatchQueue.main.async { completion(.failure(APIError.invalidURL)) }
        return
    }
    var request = URLRequest(url: url, timeoutInterval: 60)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = bodyData

    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
        if let error {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }
        guard let data, let self else {
            DispatchQueue.main.async { completion(.failure(APIError.noData)) }
            return
        }
        if let decrypted = self.decryptResponse(data) {
            DispatchQueue.main.async { completion(.success(decrypted)) }
        } else {
            DispatchQueue.main.async { completion(.failure(APIError.decryptFailed)) }
        }
    }.resume()
}
```

- [x] **Step 3: 在公开接口区新增 `generatePptx`**

```swift
/// 生成 PPT 文件，taskId + templateId + markdown → pptId，回调在主线程
func generatePptx(
    taskId:     String,
    templateId: String,
    markdown:   String,
    completion: @escaping (Result<String, Error>) -> Void
) {
    let uuid = AppDelegate.getCurrentUserId() ?? "temp"
    let body: [String: Any] = [
        "taskId":     taskId,
        "templateId": templateId,
        "markdown":   markdown,
        "appId":      appId,
        "uuid":       uuid,
    ]
    postJSON(path: "/v1/api/ai/ppt/v2/generatePptx", body: body) { result in
        switch result {
        case .success(let raw):
            // newslist 可能是字符串 pptId，也可能是含 pptId 字段的字典
            let pptId = (raw as? String)
                ?? ((raw as? [String: Any])?["pptId"] as? String)
                ?? ""
            completion(.success(pptId))
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

- [x] **Step 4: 构建验证（Xcode Build）**

在 Xcode 中 Cmd+B，确认无编译错误。

- [x] **Step 5: Commit**

```bash
git add Slidesh/Services/PPTAPIService.swift
git commit -m "feat: PPTAPIService 新增 updateContent/generatePptx 接口"
```

---

## Task 2: TemplateCell — 新增选中态高亮

**Files:**
- Modify: `Slidesh/Views/TemplateCell.swift`

### 背景
模板选择器需要用户点击后在封面图上显示选中边框（品牌主色，2pt 宽度）。`contentView` 已有 `cornerRadius=16`，只需改 `borderColor/borderWidth` 即可。使用公开方法 `setSelectedState(_:)` 而不是重写 `isSelected`，避免干扰骨架屏逻辑。

- [x] **Step 1: 在 `TemplateCell` 中新增选中态方法**

在 `TemplateCell` 公开接口区（`configure` 之后）插入：

```swift
/// 控制选中边框高亮，供 TemplateSelectorViewController 在 didSelectItem 时调用
func setSelectedState(_ selected: Bool) {
    contentView.layer.borderColor = selected
        ? UIColor.appPrimary.cgColor
        : UIColor.clear.cgColor
    contentView.layer.borderWidth = selected ? 2 : 0
}
```

- [x] **Step 2: 在 `prepareForReuse` 中重置选中态**

在现有 `prepareForReuse` 末尾追加：

```swift
setSelectedState(false)
```

- [x] **Step 3: 构建验证**

Cmd+B 确认无误。

- [x] **Step 4: Commit**

```bash
git add Slidesh/Views/TemplateCell.swift
git commit -m "feat: TemplateCell 新增选中态边框高亮"
```

---

## Task 3: OutlineViewController — 编辑同步 & 重建 markdown

**Files:**
- Modify: `Slidesh/ViewControllers/OutlineViewController.swift`

### 背景
当前 `OutlineHeaderCell` / `OutlineBulletCell` 的 UITextView 没有回调，用户编辑后数据不会写回 `sections`。需要：
1. 给两个 Cell 添加 `onTitleChanged` / `onTextChanged` 闭包属性，并让其 textView 充当 UITextViewDelegate。
2. 在 `cellForRowAt` 里绑定闭包，将改动写回对应 `sections[section].title` / `sections[section].bullets[row-1].text`。
3. 新增 `reconstructMarkdown()` 从 sections 重建 markdown 字符串（跳过 `.toc` section，toc 由 AI 自动生成）。

- [x] **Step 1: 给 `OutlineHeaderCell` 添加 UITextViewDelegate 和回调**

在 `OutlineHeaderCell` 类定义中添加属性和 delegate：

```swift
var onTitleChanged: ((String) -> Void)?
```

在 `init` 里设置：
```swift
titleView.delegate = self
```

在类内新增 extension（注意 `private class` 需要在同一文件中用 `extension`）：

```swift
extension OutlineHeaderCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        onTitleChanged?(textView.text ?? "")
    }
}
```

- [x] **Step 2: 给 `OutlineBulletCell` 添加 UITextViewDelegate 和回调**

```swift
var onTextChanged: ((String) -> Void)?
```

init 中：
```swift
textView.delegate = self
```

```swift
extension OutlineBulletCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        onTextChanged?(textView.text ?? "")
    }
}
```

- [x] **Step 3: 在 `OutlineViewController.cellForRowAt` 里绑定回调**

在 `cellForRowAt` 中，配置 cell 后紧跟绑定（注意使用 `indexPath.section` / `indexPath.row`，此时 sections 已稳定不会插删）：

```swift
// header cell
cell.onTitleChanged = { [weak self] text in
    guard let self, indexPath.section < self.sections.count else { return }
    self.sections[indexPath.section].title = text
}

// bullet cell
cell.onTextChanged = { [weak self] text in
    guard let self,
          indexPath.section < self.sections.count,
          indexPath.row - 1 < self.sections[indexPath.section].bullets.count
    else { return }
    self.sections[indexPath.section].bullets[indexPath.row - 1].text = text
}
```

- [x] **Step 4: 新增 `reconstructMarkdown()`**

```swift
/// 从 sections 重建 markdown（跳过 .toc，由 AI 自动生成）
func reconstructMarkdown() -> String {
    view.endEditing(true)   // 提交当前正在编辑的文本到 textView.text
    var md = ""
    for section in sections {
        switch section.kind {
        case .toc: continue
        case .theme:
            md += "# \(section.title)\n\n"
        case .chapter:
            md += "## \(section.title)\n"
            for bullet in section.bullets {
                switch bullet.level {
                case .h3:   md += "### \(bullet.text)\n"
                case .h4:   md += "#### \(bullet.text)\n"
                case .body: md += "\(bullet.text)\n"
                }
            }
            md += "\n"
        }
    }
    return md
}
```

- [x] **Step 5: 构建验证**

Cmd+B，确认无误。

- [x] **Step 6: Commit**

```bash
git add Slidesh/ViewControllers/OutlineViewController.swift
git commit -m "feat: OutlineViewController 编辑回调同步 sections，新增 reconstructMarkdown"
```

---

## Task 4: OutlineViewController — 下载大纲

**Files:**
- Modify: `Slidesh/ViewControllers/OutlineViewController.swift`

### 背景
用户点击"下载大纲"→弹出 UIAlertController（ActionSheet）选择格式：
- **Markdown (.md)**：直接将 `reconstructMarkdown()` 写入临时 .md 文件，用 UIActivityViewController 分享。
- **纯文本 (.txt)**：将 sections 转换为可读层级文本（带缩进前缀），写入临时 .txt 文件分享。

iPad 需要设置 `popoverPresentationController.sourceView`，否则 ActionSheet 崩溃。

- [x] **Step 1: 实现 `downloadTapped()`**

```swift
@objc private func downloadTapped() {
    let sheet = UIAlertController(title: "下载大纲", message: "选择导出格式", preferredStyle: .actionSheet)
    sheet.addAction(UIAlertAction(title: "Markdown 格式 (.md)", style: .default) { [weak self] _ in
        self?.exportMarkdown()
    })
    sheet.addAction(UIAlertAction(title: "纯文本格式 (.txt)", style: .default) { [weak self] _ in
        self?.exportPlainText()
    })
    sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
    // iPad 必须设置 sourceView，否则 ActionSheet 崩溃
    if let popover = sheet.popoverPresentationController {
        popover.sourceView = bottomBar
        popover.sourceRect = bottomBar.bounds
    }
    present(sheet, animated: true)
}
```

- [x] **Step 2: 实现 `exportMarkdown()`**

```swift
private func exportMarkdown() {
    let md = reconstructMarkdown()
    let fileName = "outline_\(taskId).md"
    let tmpURL   = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    do {
        try md.write(to: tmpURL, atomically: true, encoding: .utf8)
    } catch {
        showExportError(error); return
    }
    let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
    vc.popoverPresentationController?.sourceView = bottomBar
    present(vc, animated: true)
}
```

- [x] **Step 3: 实现 `exportPlainText()`**

```swift
private func exportPlainText() {
    var lines: [String] = []
    for section in sections {
        switch section.kind {
        case .theme:
            lines.append("【\(section.title)】\n")
        case .toc:
            lines.append("目录：")
            section.bullets.forEach { lines.append("  \($0.text)") }
            lines.append("")
        case .chapter:
            lines.append("\n▌ \(section.title)")
            for bullet in section.bullets {
                switch bullet.level {
                case .h3:   lines.append("  • \(bullet.text)")
                case .h4:   lines.append("    ○ \(bullet.text)")
                case .body: lines.append("      \(bullet.text)")
                }
            }
        }
    }
    let text     = lines.joined(separator: "\n")
    let fileName = "outline_\(taskId).txt"
    let tmpURL   = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    do {
        try text.write(to: tmpURL, atomically: true, encoding: .utf8)
    } catch {
        showExportError(error); return
    }
    let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
    vc.popoverPresentationController?.sourceView = bottomBar
    present(vc, animated: true)
}

private func showExportError(_ error: Error) {
    let alert = UIAlertController(title: "导出失败", message: error.localizedDescription, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "确定", style: .default))
    present(alert, animated: true)
}
```

- [x] **Step 4: 构建并手动测试**

Cmd+B 后在模拟器跑，进入大纲页 → 点"下载大纲" → 验证两种格式都能正常弹出分享面板。

- [x] **Step 5: Commit**

```bash
git add Slidesh/ViewControllers/OutlineViewController.swift
git commit -m "feat: 下载大纲支持 Markdown 和纯文本两种格式导出"
```

---

## Task 5: OutlineViewController — 挑选PPT模板（updateContent + present selector）

**Files:**
- Modify: `Slidesh/ViewControllers/OutlineViewController.swift`

### 背景
`templateTapped()` 流程：
1. `reconstructMarkdown()` 收集当前编辑。
2. 在 `templateBtn` 上显示 loading spinner，禁用按钮。
3. 调用 `PPTAPIService.shared.updateContent`，等待 SSE onComplete。
4. 恢复按钮，present `TemplateSelectorViewController`（套一层 UINavigationController）。
5. 若 updateContent 报错：恢复按钮，依然 present（不阻断流程，但使用本地 markdown）。

需要在类属性区声明 `private var updateTask: URLSessionDataTask?`，以便"换个大纲"时可取消。

- [x] **Step 1: 添加属性**

在 `sseTask` 声明下方添加：

```swift
private var updateTask: URLSessionDataTask?
```

- [x] **Step 2: 实现 `templateTapped()`**

```swift
@objc private func templateTapped() {
    guard !sections.isEmpty else { return }

    let currentMarkdown = reconstructMarkdown()
    setTemplateBtnLoading(true)

    updateTask = PPTAPIService.shared.updateContent(
        taskId:   taskId,
        markdown: currentMarkdown
    ) { [weak self] updatedMarkdown in
        guard let self else { return }
        self.accumulatedMarkdown = updatedMarkdown
        self.setTemplateBtnLoading(false)
        self.presentTemplateSelector()
    } onError: { [weak self] _ in
        guard let self else { return }
        // 更新失败不阻断，使用本地 markdown
        self.setTemplateBtnLoading(false)
        self.presentTemplateSelector()
    }
}
```

- [x] **Step 3: 实现 `setTemplateBtnLoading` / `presentTemplateSelector`**

```swift
private func setTemplateBtnLoading(_ loading: Bool) {
    templateBtn.isEnabled = !loading
    if loading {
        templateBtn.setTitle("", for: .normal)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.tag   = 999
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        templateBtn.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: templateBtn.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: templateBtn.centerYAnchor),
        ])
    } else {
        templateBtn.subviews.first(where: { $0.tag == 999 })?.removeFromSuperview()
        templateBtn.setTitle("挑选PPT模板  →", for: .normal)
    }
}

private func presentTemplateSelector() {
    let selector = TemplateSelectorViewController(
        taskId:   taskId,
        markdown: accumulatedMarkdown
    )
    let nav = UINavigationController(rootViewController: selector)
    nav.modalPresentationStyle = .fullScreen
    present(nav, animated: true)
}
```

- [x] **Step 4: 构建验证**

Cmd+B。此时 `TemplateSelectorViewController` 还不存在，会报编译错误——正常，Task 6 再建。可临时注释掉 `presentTemplateSelector` 内的两行验证前面步骤。

- [x] **Step 5: Commit（在 Task 6 完成后一起提交也可）**

---

## Task 6: TemplateSelectorViewController（新文件）

**Files:**
- Create: `Slidesh/ViewControllers/TemplateSelectorViewController.swift`

### 布局说明（从上至下）

```
NavigationBar（透明，X 关闭，title="挑选PPT模板"）
─── tabBar（高 44：模板中心 | 最近使用，下划线指示器）
─── searchContainer（高 44，圆角，搜索图标 + 输入框 + 搜索按钮）
─── categoryView（高 40，CategorySelectorView 复用）
─── filterView（高 44：风格▾ 颜色▾ | 贴合主题▾）
─── collectionView（flex，网格 2 列，底部 paddingBottom=88）
─── bottomBar（safeArea 底部，高 88：合成PPT →，品牌渐变）
```

复用现有组件：`CategorySelectorView`、`FilterPickerViewController`、`TemplateCell`。

### 数据与状态

- `selectedTemplate: PPTTemplate?`：选中的模板
- 分页逻辑与 `TemplatesViewController` 完全相同（复制）
- 搜索：客户端过滤（对已加载 templates 按 subject 关键词过滤），不发起新请求
- "贴合主题"：简单实现，将 subject 含有当前 markdown 主题词的模板排到前面

- [x] **Step 1: 创建文件骨架 + 属性声明**

```swift
//  TemplateSelectorViewController.swift
//  模板选择器：tab + 搜索 + 分类 + 筛选 + 网格 + 合成PPT

import UIKit
import SkeletonView

class TemplateSelectorViewController: UIViewController {

    // MARK: - 参数
    private let taskId:   String
    private let markdown: String

    // MARK: - 数据状态
    private var selectedTemplate:  PPTTemplate?
    private var allTemplates:      [PPTTemplate] = []  // 原始分页数据
    private var filteredTemplates: [PPTTemplate] = []  // 搜索过滤后展示
    private var currentPage    = 1
    private var isLoading      = false
    private var hasMore        = true
    private var loadGeneration = 0
    private var selectedCategory: String = ""
    private var selectedStyle:    String = ""
    private var selectedColor:    String = ""
    private var searchKeyword:    String = ""
    private var themeFirst:       Bool   = false

    private var categoryOptions: [(name: String, value: String)] = [("全部场景", "")]
    private var styleOptions:    [(name: String, value: String)] = [("全部风格", "")]
    private var colorOptions:    [(name: String, value: String)] = [("全部颜色", "")]

    // MARK: - 子视图
    private let tabBar       = UIView()
    private let tabCenter    = UIButton(type: .system)
    private let tabRecent    = UIButton(type: .system)
    private let tabIndicator = UIView()

    private let searchContainer = UIView()
    private let searchField     = UITextField()
    private let searchBtn       = UIButton(type: .system)

    private let categoryView = CategorySelectorView()

    private let filterView = UIView()
    private let styleBtn   = UIButton(type: .system)
    private let colorBtn   = UIButton(type: .system)
    private let themeBtn   = UIButton(type: .system)

    private var collectionView: UICollectionView!
    private weak var footerView: TemplateSelectorFooter?

    private let bottomBar  = UIView()
    private let composeBtn = UIButton(type: .custom)
    private var composeGrad: CAGradientLayer?

    // 最近使用空状态
    private let emptyLabel = UILabel()

    // MARK: - Init
    init(taskId: String, markdown: String) {
        self.taskId   = taskId
        self.markdown = markdown
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
}
```

- [x] **Step 2: 实现 `viewDidLoad` 和 `viewDidLayoutSubviews`**

```swift
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
```

- [x] **Step 3: 实现导航栏**

```swift
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
```

- [x] **Step 4: 实现 Tab 栏**

```swift
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
        tabIndicator.centerXAnchor.constraint(equalTo: tabCenter.centerXAnchor),
        tabIndicator.widthAnchor.constraint(equalToConstant: 28),
        tabIndicator.heightAnchor.constraint(equalToConstant: 3),
    ])
}

@objc private func switchTab(_ sender: UIButton) {
    let isCenter = sender.tag == 0
    tabCenter.setTitleColor(isCenter ? .appPrimary : .appTextSecondary, for: .normal)
    tabRecent.setTitleColor(isCenter ? .appTextSecondary : .appPrimary, for: .normal)
    tabIndicator.snp_or_center(to: isCenter ? tabCenter : tabRecent) // 见下方实现
    updateTabIndicator(to: isCenter ? tabCenter : tabRecent)
    collectionView.isHidden = !isCenter
    emptyLabel.isHidden     = isCenter
    // 最近使用：暂无数据（本期不实现本地存储）
}

private func updateTabIndicator(to button: UIButton) {
    UIView.animate(withDuration: 0.2) {
        // 用 centerX 约束实现动画移动 indicator
        self.tabIndicator.center.x = button.center.x
    }
}
```

注意：`updateTabIndicator` 需要在 AutoLayout 约束系统中通过修改约束常量来实现动画，而不能直接设置 `center.x`（后者在约束系统中无效）。改为：

```swift
// 在 setupTabBar 里保存对 centerX 约束的引用
private var indicatorCenterX: NSLayoutConstraint!

// setupTabBar 中改为：
indicatorCenterX = tabIndicator.centerXAnchor.constraint(equalTo: tabCenter.centerXAnchor)
NSLayoutConstraint.activate([..., indicatorCenterX, ...])

// switchTab 中：
private func updateTabIndicator(to button: UIButton) {
    indicatorCenterX.isActive = false
    indicatorCenterX = tabIndicator.centerXAnchor.constraint(equalTo: button.centerXAnchor)
    indicatorCenterX.isActive = true
    UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
}
```

- [x] **Step 5: 实现搜索栏**

```swift
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

    searchField.placeholder     = "请输入模板关键词"
    searchField.font            = .systemFont(ofSize: 14)
    searchField.textColor       = .appTextPrimary
    searchField.backgroundColor = .clear
    searchField.returnKeyType   = .search
    searchField.delegate        = self
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
```

- [x] **Step 6: 实现分类视图 + 筛选栏**

```swift
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

private func setupFilterView() {
    filterView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(filterView)

    // 左侧：风格 + 颜色
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

    // 右侧：贴合主题（toggle 排序）
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
```

- [x] **Step 7: 实现 CollectionView（网格）**

与 `TemplatesViewController` 相同的两列网格布局，`estimatedHeight=160`，bottomInset=100（让最后一行不被底部栏遮挡）。

```swift
private func setupCollectionView() {
    let layout   = makeGridLayout()
    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.backgroundColor = .clear
    collectionView.isSkeletonable  = true
    collectionView.register(TemplateCell.self, forCellWithReuseIdentifier: TemplateCell.reuseID)
    collectionView.register(TemplateSelectorFooter.self,
        forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
        withReuseIdentifier: TemplateSelectorFooter.reuseID)
    collectionView.dataSource = self
    collectionView.delegate   = self
    collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 100, right: 0)
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
```

- [x] **Step 8: 实现底部"合成PPT"栏**

```swift
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
    composeBtn.clipsToBounds = true
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
```

- [x] **Step 9: 实现"合成PPT"按钮逻辑**

```swift
@objc private func composeTapped() {
    guard let template = selectedTemplate else {
        // 提示用户先选择模板
        let alert = UIAlertController(title: "请先选择模板", message: "点击一个模板后再合成PPT", preferredStyle: .alert)
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
            // 当前版本显示完成提示（后续可跳转 PPT 编辑器）
            let alert = UIAlertController(title: "合成成功",
                                          message: "PPT 已生成，ID: \(pptId)",
                                          preferredStyle: .alert)
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
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.tag   = 888
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        composeBtn.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: composeBtn.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: composeBtn.centerYAnchor),
        ])
    } else {
        composeBtn.subviews.first(where: { $0.tag == 888 })?.removeFromSuperview()
        composeBtn.setTitle("合成PPT  →", for: .normal)
    }
}
```

- [x] **Step 10: 实现筛选器 Actions（风格/颜色）**

```swift
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
    let swatches: [UIColor?] = colorOptions.map { TemplatesViewController.colorFromValue($0.value) }
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
```

注意：`TemplatesViewController.colorFromValue` 是 `private static`，需要改为 `internal static` 或在 TemplateSelectorViewController 中重复这段映射。建议将其提取到 AppColors 扩展或工具文件中，但为不违反 YAGNI，可在 TemplateSelectorViewController 内复制一份私有方法 `colorFromValue(_:)`。

- [x] **Step 11: 实现分页加载（与 TemplatesViewController 相同逻辑）**

```swift
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

private func loadTemplates(reset: Bool) {
    if reset {
        loadGeneration += 1
        currentPage = 1
        isLoading   = false
        allTemplates = []
        filteredTemplates = []
        hasMore = true
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
        if case .success(let new) = result {
            self.allTemplates.append(contentsOf: new)
            self.hasMore     = new.count >= 20
            self.currentPage += 1
            self.applySearch()
        }
    }
}

private func applySearch() {
    var result = allTemplates
    if !searchKeyword.isEmpty {
        result = result.filter { $0.subject.localizedCaseInsensitiveContains(searchKeyword) }
    }
    if themeFirst {
        // 从 markdown 提取主题词（第一行 # 后的文字）
        let theme = markdown
            .components(separatedBy: "\n").first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) } ?? ""
        if !theme.isEmpty {
            result.sort { a, _ in a.subject.localizedCaseInsensitiveContains(theme) }
        }
    }
    filteredTemplates = result
    collectionView.reloadData()
}

private func showSkeleton() {
    collectionView.showSkeleton(usingColor: .systemGray5, transition: .crossDissolve(0.25))
}
private func hideSkeleton() {
    guard collectionView.sk.isSkeletonActive else { return }
    collectionView.hideSkeleton(reloadDataAfter: false, transition: .crossDissolve(0.25))
}
```

- [x] **Step 12: DataSource + Delegate**

```swift
extension TemplateSelectorViewController: SkeletonCollectionViewDataSource {
    func collectionSkeletonView(_ skeletonView: UICollectionView,
                                numberOfItemsInSection section: Int) -> Int { 6 }
    func collectionSkeletonView(_ skeletonView: UICollectionView,
                                cellIdentifierForItemAt indexPath: IndexPath) -> ReusableCellIdentifier {
        TemplateCell.reuseID
    }
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int { filteredTemplates.count }
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
            ofKind: kind, withReuseIdentifier: TemplateSelectorFooter.reuseID,
            for: indexPath) as! TemplateSelectorFooter
        footerView = footer
        footer.configure(showEnd: !hasMore && !filteredTemplates.isEmpty)
        return footer
    }
}

extension TemplateSelectorViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let prev = selectedTemplate
        selectedTemplate = filteredTemplates[indexPath.item]
        // 仅刷新受影响的两个 cell，避免全量 reloadData 造成闪烁
        var paths = [indexPath]
        if let prevId = prev?.id,
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

extension TemplateSelectorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTapped(); return true
    }
}
```

- [x] **Step 13: 空状态 + Footer 内部类**

```swift
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
```

```swift
// MARK: - Footer
private class TemplateSelectorFooter: UICollectionReusableView {
    static let reuseID = "TemplateSelectorFooter"
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
```

- [x] **Step 14: 构建验证**

Cmd+B，修复所有编译错误（常见：`TemplatesViewController.uiColor(forValue:)` 访问权限、SkeletonView import 等）。

- [x] **Step 15: 手动测试**

1. 进入大纲页（流式完成后） → 点"挑选PPT模板"
2. 验证 loading spinner 出现 → updateContent SSE 结束后 loading 消失 → TemplateSelectorViewController 弹出
3. 验证模板网格正常加载（有封面图、骨架屏）
4. 点击一个模板 → 验证选中高亮边框
5. 点"合成PPT" → 验证 loading → 成功/失败 alert
6. 测试搜索功能（输入关键词→搜索→列表过滤）
7. 测试"贴合主题"toggle

- [x] **Step 16: Commit**

```bash
git add Slidesh/ViewControllers/TemplateSelectorViewController.swift \
        Slidesh/ViewControllers/OutlineViewController.swift \
        Slidesh/Views/TemplateCell.swift \
        Slidesh/Services/PPTAPIService.swift
git commit -m "feat: 挑选PPT模板完整流程（updateContent→模板选择器→合成PPT）"
```

---

## 注意事项

1. **`TemplatesViewController.uiColor(forValue:)` 访问权限**：该方法是 `private static`，TemplateSelectorViewController 无法直接调用。需将其改为 `internal static`，或在 TemplateSelectorViewController 中复制一份私有实现。推荐改为 `internal static`（不破坏封装）。

2. **UITextView delegate 冲突**：两个 Cell 的 textView 当前没有 delegate。添加后需确认不会干扰现有的键盘处理（`beginEditing()` 仍正常工作）。

3. **IndexPath 捕获**：`cellForRowAt` 闭包捕获 `indexPath` 是安全的，因为大纲页完成生成后 sections 不再做增删。

4. **`TemplateSelectorViewController` 中的 `traitCollectionDidChange`**：searchContainer 的 `layer.borderColor` 使用了 `resolvedColor`，但在 trait 切换时不会自动更新。与 NewProjectViewController 一致，需要 override `traitCollectionDidChange` 刷新 CGColor（可在 Task 6 完成后补充）。
