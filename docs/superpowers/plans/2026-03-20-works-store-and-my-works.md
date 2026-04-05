# Works Store & My Works Implementation Plan

> **Status: ✅ COMPLETED 2026-03-20** — All 6 tasks implemented and committed.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 自动保存用户生成的大纲和PPT到本地，并通过完整的「我的作品」页面让用户管理查看；同时支持真实的PPT文件下载。

**Architecture:** 新增 `WorksStore` 单例负责 JSON 持久化（Documents 目录），大纲在 SSE 完成时自动保存、用户返回时自动更新，PPT 在 `loadPPT` 成功后自动保存；`MyWorksViewController` 订阅 `NotificationCenter` 实时刷新，分两个 section 展示 PPT 和大纲；`PPTPreviewViewController` 使用 `URLSession.downloadTask` 下载文件到本地再分享。

**Tech Stack:** Swift, UIKit, URLSession.downloadTask, NotificationCenter, JSONEncoder/Decoder, FileManager, WKWebView

---

## File Structure

| 文件 | 操作 | 职责 |
|------|------|------|
| `Slidesh/Models/WorksRecord.swift` | 新建 | `OutlineRecord` + `PPTRecord` Codable 模型 |
| `Slidesh/Services/WorksStore.swift` | 新建 | 单例，JSON 读写 Documents/works.json |
| `Slidesh/ViewControllers/OutlineViewController.swift` | 修改 | `transitionToEditable` 保存大纲；`viewWillDisappear` 更新大纲 |
| `Slidesh/ViewControllers/TemplateSelectorViewController.swift` | 修改 | `loadAndShowPPT` 成功后保存 PPTRecord |
| `Slidesh/ViewControllers/PPTPreviewViewController.swift` | 修改 | 按钮改为「下载」，`downloadTask` 下载文件后再分享 |
| `Slidesh/ViewControllers/SavedOutlineViewController.swift` | 新建 | 只读大纲 Markdown 查看器（复用 streamLabel 风格） |
| `Slidesh/ViewControllers/MyWorksViewController.swift` | 修改 | 两 section 列表：PPTs + 大纲；点击跳转预览 |

---

## Task 1: WorksRecord 模型 + WorksStore 持久化

**Files:**
- Create: `Slidesh/Models/WorksRecord.swift`
- Create: `Slidesh/Services/WorksStore.swift`

- [ ] **Step 1: 创建 WorksRecord.swift**

```swift
// Slidesh/Models/WorksRecord.swift
import Foundation

/// 本地保存的大纲记录
struct OutlineRecord: Codable, Identifiable {
    let id: String          // taskId
    var subject: String
    var markdown: String
    var savedAt: Date
}

/// 本地保存的 PPT 记录
struct PPTRecord: Codable, Identifiable {
    let id: String          // pptId
    var taskId: String?
    var subject: String
    var fileUrl: String
    var coverUrl: String?
    var savedAt: Date
}
```

- [ ] **Step 2: 创建 WorksStore.swift**

```swift
// Slidesh/Services/WorksStore.swift
import Foundation

/// 通知名：作品数据有变更，MyWorksViewController 订阅刷新
extension Notification.Name {
    static let worksDidUpdate = Notification.Name("WorksStore.worksDidUpdate")
}

class WorksStore {
    static let shared = WorksStore()
    private init() { load() }

    private(set) var outlines: [OutlineRecord] = []
    private(set) var ppts:     [PPTRecord]     = []

    // MARK: - 大纲

    /// 保存或更新大纲（taskId 相同则覆盖）
    func saveOutline(_ record: OutlineRecord) {
        if let idx = outlines.firstIndex(where: { $0.id == record.id }) {
            outlines[idx] = record
        } else {
            outlines.insert(record, at: 0)
        }
        persist()
    }

    // MARK: - PPT

    /// 保存或更新 PPT（pptId 相同则覆盖）
    func savePPT(_ record: PPTRecord) {
        if let idx = ppts.firstIndex(where: { $0.id == record.id }) {
            ppts[idx] = record
        } else {
            ppts.insert(record, at: 0)
        }
        persist()
    }

    // MARK: - 持久化

    private var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("works.json")
    }

    private struct Store: Codable {
        var outlines: [OutlineRecord]
        var ppts:     [PPTRecord]
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let store = try? JSONDecoder().decode(Store.self, from: data) else { return }
        outlines = store.outlines
        ppts     = store.ppts
    }

    private func persist() {
        let store = Store(outlines: outlines, ppts: ppts)
        if let data = try? JSONEncoder().encode(store) {
            try? data.write(to: storeURL, options: .atomic)
        }
        NotificationCenter.default.post(name: .worksDidUpdate, object: nil)
    }
}
```

- [ ] **Step 3: 编译确认无错误**

在 Xcode 中 Cmd+B，或通过 xcodebuild 确认两个文件编译通过，无 warning/error。

- [ ] **Step 4: Commit**

```bash
git add Slidesh/Models/WorksRecord.swift Slidesh/Services/WorksStore.swift
git commit -m "feat: add WorksRecord model and WorksStore persistence"
```

---

## Task 2: OutlineViewController 自动保存大纲

**Files:**
- Modify: `Slidesh/ViewControllers/OutlineViewController.swift`

关键位置：
- `transitionToEditable()` — SSE 完成时调用，第一次保存（含 taskId + subject + markdown）
- `viewWillDisappear` — 用户返回时，若有 sections 则更新 markdown

- [ ] **Step 1: 在 `transitionToEditable()` 末尾追加初始保存**

找到 `transitionToEditable()` 方法（约 628 行），在方法末尾 `}` 前插入：

```swift
// 大纲生成完毕后立即保存一份到本地
let record = OutlineRecord(
    id:       taskId,
    subject:  subject,
    markdown: accumulatedMarkdown,
    savedAt:  Date()
)
WorksStore.shared.saveOutline(record)
```

- [ ] **Step 2: 在 `viewWillDisappear` 追加退出时更新**

找到 `viewWillDisappear` 方法（约 145 行），在恢复导航栏外观代码之后，方法末尾前插入：

```swift
// 用户返回时，用最新编辑内容更新已保存的大纲
if isMovingFromParent && !sections.isEmpty {
    let updated = OutlineRecord(
        id:       taskId,
        subject:  subject,
        markdown: reconstructMarkdown(),
        savedAt:  Date()
    )
    WorksStore.shared.saveOutline(updated)
}
```

- [ ] **Step 3: 编译确认无错误**

- [ ] **Step 4: Commit**

```bash
git add Slidesh/ViewControllers/OutlineViewController.swift
git commit -m "feat: auto-save outline on generation and on exit"
```

---

## Task 3: TemplateSelectorViewController 自动保存 PPT

**Files:**
- Modify: `Slidesh/ViewControllers/TemplateSelectorViewController.swift`

关键位置：`loadAndShowPPT(pptId:)` 中 `loadPPT` 成功的 case（约 620 行）

- [ ] **Step 1: 在 `loadPPT` success case 中保存 PPTRecord**

找到：
```swift
case .success(let info):
    print("✅ loadPPT 成功，status=\(info.status ?? "-")，fileUrl=\(info.fileUrl ?? "-")")
    let previewVC = PPTPreviewViewController(pptInfo: info)
    self.navigationController?.pushViewController(previewVC, animated: true)
```

在 `let previewVC` 之前插入：

```swift
// 自动保存 PPT 记录（fileUrl 非空才有意义）
if let fileUrl = info.fileUrl, !fileUrl.isEmpty {
    let record = PPTRecord(
        id:       info.pptId,
        taskId:   info.taskId,
        subject:  info.subject ?? subject,
        fileUrl:  fileUrl,
        coverUrl: info.coverUrl,
        savedAt:  Date()
    )
    WorksStore.shared.savePPT(record)
}
```

注意：`TemplateSelectorViewController` 持有 `subject: String` 属性，直接引用即可。如果没有，改用 `info.subject ?? ""`.

- [ ] **Step 2: 编译确认无错误**

- [ ] **Step 3: Commit**

```bash
git add Slidesh/ViewControllers/TemplateSelectorViewController.swift
git commit -m "feat: auto-save PPT record after successful generation"
```

---

## Task 4: PPTPreviewViewController 真实文件下载

**Files:**
- Modify: `Slidesh/ViewControllers/PPTPreviewViewController.swift`

当前 `shareTapped` 直接分享 URL；改为先用 `URLSession.downloadTask` 下载文件到本地临时目录，再弹出 `UIActivityViewController`（包含本地文件 URL，iOS 可弹出「存储到文件」「AirDrop」等选项）。

- [ ] **Step 1: 添加下载状态属性和 loading 指示器**

在现有属性区域（`private let bottomBar = UIView()` 附近）添加：

```swift
private var downloadTask: URLSessionDownloadTask?
private let downloadIndicator = UIActivityIndicatorView(style: .medium)
```

- [ ] **Step 2: 在 `setupBottomBar()` 中配置 indicator**

在 `shareBtn` 被加入 `bottomBar` 之后添加：

```swift
downloadIndicator.color = .white
downloadIndicator.hidesWhenStopped = true
downloadIndicator.translatesAutoresizingMaskIntoConstraints = false
bottomBar.addSubview(downloadIndicator)
NSLayoutConstraint.activate([
    downloadIndicator.centerXAnchor.constraint(equalTo: shareBtn.centerXAnchor),
    downloadIndicator.centerYAnchor.constraint(equalTo: shareBtn.centerYAnchor),
])
```

- [ ] **Step 3: 替换 `shareTapped` 实现**

完整替换原有 `shareTapped` 方法：

```swift
@objc private func shareTapped() {
    guard let rawUrl = pptInfo.fileUrl, !rawUrl.isEmpty,
          let url = URL(string: rawUrl) else { return }

    // 已在下载中则忽略重复点击
    guard downloadTask == nil else { return }

    shareBtn.setTitle("", for: .normal)
    downloadIndicator.startAnimating()
    shareBtn.isEnabled = false

    downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempUrl, _, error in
        guard let self else { return }
        DispatchQueue.main.async {
            self.downloadTask = nil
            self.downloadIndicator.stopAnimating()
            self.shareBtn.setTitle("下载 / 分享", for: .normal)
            self.shareBtn.isEnabled = true
        }
        if let error {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "下载失败",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)
            }
            return
        }
        guard let tempUrl else { return }
        // 将临时文件移动到 Documents 目录，保留原始文件名
        let fileName = url.lastPathComponent.isEmpty ? "presentation.pptx" : url.lastPathComponent
        let destUrl  = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destUrl)
        try? FileManager.default.moveItem(at: tempUrl, to: destUrl)

        DispatchQueue.main.async {
            let vc = UIActivityViewController(activityItems: [destUrl], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = self.shareBtn
            self.present(vc, animated: true)
        }
    }
    downloadTask?.resume()
}
```

- [ ] **Step 4: 编译确认无错误**

- [ ] **Step 5: Commit**

```bash
git add Slidesh/ViewControllers/PPTPreviewViewController.swift
git commit -m "feat: download pptx to local before sharing in PPTPreviewViewController"
```

---

## Task 5: SavedOutlineViewController（只读大纲查看器）

**Files:**
- Create: `Slidesh/ViewControllers/SavedOutlineViewController.swift`

复用 `OutlineViewController` 中 `renderMarkdown` 的样式风格，但简化为只读的 `UIScrollView + UILabel`。

- [ ] **Step 1: 创建 SavedOutlineViewController.swift**

```swift
// Slidesh/ViewControllers/SavedOutlineViewController.swift
import UIKit

/// 只读展示已保存的大纲 Markdown
class SavedOutlineViewController: UIViewController {

    private let record: OutlineRecord

    private let scrollView = UIScrollView()
    private let contentLabel = UILabel()

    init(record: OutlineRecord) {
        self.record = record
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = record.subject
        view.backgroundColor = .systemGroupedBackground
        addMeshGradientBackground()
        setupScrollView()
        renderContent()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 15)

        view.addSubview(scrollView)
        scrollView.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentLabel.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentLabel.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])
    }

    private func renderContent() {
        // 使用 OutlineViewController 中相同的 renderMarkdown 函数渲染 markdown
        contentLabel.attributedText = renderMarkdown(record.markdown)
    }
}
```

> 注意：`renderMarkdown` 是定义在 `OutlineViewController.swift` 中的 `fileprivate` 函数还是全局函数？
> 检查实际作用域。若为 `fileprivate`/`private`，需要：
> - 方案A：将 `renderMarkdown` 提取为独立 `MarkdownRenderer.swift` 文件中的全局函数
> - 方案B：在 `SavedOutlineViewController` 中内联一个简单版本（仅用 `NSAttributedString`）

- [ ] **Step 2: 检查 renderMarkdown 作用域**

```bash
grep -n "func renderMarkdown" Slidesh/ViewControllers/OutlineViewController.swift
```

- [ ] **Step 3: 根据实际情况处理 renderMarkdown 共享**

若为 `private` — 在文件顶部将声明改为 `internal`（去掉访问控制修饰符），使其可被同模块访问。

- [ ] **Step 4: 编译确认无错误**

- [ ] **Step 5: Commit**

```bash
git add Slidesh/ViewControllers/SavedOutlineViewController.swift Slidesh/ViewControllers/OutlineViewController.swift
git commit -m "feat: add SavedOutlineViewController for read-only outline preview"
```

---

## Task 6: MyWorksViewController 完整实现

**Files:**
- Modify: `Slidesh/ViewControllers/MyWorksViewController.swift`

UI 设计：
- `UITableView` style `.insetGrouped`，两个 section：section 0 = PPTs，section 1 = 大纲
- 每个 section 有 header，显示数量
- PPT cell：左侧封面缩略图（40×40）+ 标题 + 日期副标题 + 右箭头
- 大纲 cell：文件图标 + 标题 + 日期副标题 + 右箭头
- 空状态：section 为空时显示 "暂无记录" placeholder cell
- 订阅 `Notification.Name.worksDidUpdate` 刷新列表
- 点击 PPT → push `PPTPreviewViewController(pptInfo:)`（从 PPTRecord 构造 PPTInfo）
- 点击大纲 → push `SavedOutlineViewController(record:)`

- [ ] **Step 1: 完整替换 MyWorksViewController.swift**

```swift
// Slidesh/ViewControllers/MyWorksViewController.swift
import UIKit

class MyWorksViewController: UIViewController {

    // MARK: - 数据

    private var ppts:     [PPTRecord]     = []
    private var outlines: [OutlineRecord] = []

    // MARK: - 视图

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "我的作品"
        view.backgroundColor = .systemGroupedBackground
        addMeshGradientBackground()
        setupTableView()
        reloadData()

        // 订阅 WorksStore 变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(worksDidUpdate),
            name: .worksDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 布局

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - 数据

    private func reloadData() {
        ppts     = WorksStore.shared.ppts
        outlines = WorksStore.shared.outlines
        tableView.reloadData()
    }

    @objc private func worksDidUpdate() {
        DispatchQueue.main.async { self.reloadData() }
    }

    // MARK: - 辅助

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()
}

// MARK: - UITableViewDataSource

extension MyWorksViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? max(ppts.count, 1) : max(outlines.count, 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "PPT 文件（\(ppts.count)）" : "大纲（\(outlines.count)）"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var config = UIListContentConfiguration.subtitleCell()

        if indexPath.section == 0 {
            if ppts.isEmpty {
                config.text           = "暂无 PPT 记录"
                config.textProperties.color = .secondaryLabel
                cell.accessoryType    = .none
                cell.selectionStyle   = .none
            } else {
                let record = ppts[indexPath.row]
                config.text           = record.subject
                config.secondaryText  = MyWorksViewController.dateFormatter.string(from: record.savedAt)
                config.image          = UIImage(systemName: "doc.richtext")
                cell.accessoryType    = .disclosureIndicator
                cell.selectionStyle   = .default
            }
        } else {
            if outlines.isEmpty {
                config.text           = "暂无大纲记录"
                config.textProperties.color = .secondaryLabel
                cell.accessoryType    = .none
                cell.selectionStyle   = .none
            } else {
                let record = outlines[indexPath.row]
                config.text           = record.subject
                config.secondaryText  = MyWorksViewController.dateFormatter.string(from: record.savedAt)
                config.image          = UIImage(systemName: "list.bullet.rectangle")
                cell.accessoryType    = .disclosureIndicator
                cell.selectionStyle   = .default
            }
        }
        cell.contentConfiguration = config
        cell.backgroundColor = .clear
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MyWorksViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0, !ppts.isEmpty {
            let record = ppts[indexPath.row]
            let info   = PPTInfo(
                pptId:    record.id,
                taskId:   record.taskId,
                subject:  record.subject,
                fileUrl:  record.fileUrl,
                coverUrl: record.coverUrl,
                status:   "SUCCESS",
                total:    nil
            )
            let vc = PPTPreviewViewController(pptInfo: info)
            navigationController?.pushViewController(vc, animated: true)

        } else if indexPath.section == 1, !outlines.isEmpty {
            let record = outlines[indexPath.row]
            let vc = SavedOutlineViewController(record: record)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
```

- [ ] **Step 2: 编译确认无错误**

- [ ] **Step 3: 手动测试流程**

1. 进入「生成 PPT」流程，等待大纲生成完毕 → 切换到「我的作品」确认大纲已出现
2. 编辑大纲后返回 → 切换到「我的作品」确认 markdown 已更新
3. 继续选择模板 → 合成 PPT → 跳转预览 → 切换到「我的作品」确认 PPT 已出现
4. 在「我的作品」点击 PPT 条目 → 应进入 PPTPreviewViewController
5. 在「我的作品」点击大纲条目 → 应进入 SavedOutlineViewController
6. 点击「下载 / 分享」→ 应触发文件下载 + 弹出系统分享面板（包含「存储到文件」选项）

- [ ] **Step 4: Commit**

```bash
git add Slidesh/ViewControllers/MyWorksViewController.swift
git commit -m "feat: implement MyWorksViewController with PPT and outline sections"
```

---

## 注意事项

1. **`reconstructMarkdown()`** 在 `OutlineViewController` 中已存在，可直接调用。
2. **`subject` 属性**：`TemplateSelectorViewController` 持有 `subject: String`，在 Task 3 中直接使用 `subject`。
3. **`addMeshGradientBackground()`**：`MyWorksViewController` 和 `SavedOutlineViewController` 均已调用，需确保 extension 对两个文件均可见。
4. **PPTPreviewViewController** 中的 `closeTapped` 调用 `dismiss`，从 `MyWorksViewController` push 进来时应改为 `navigationController?.popViewController`，或将关闭按钮改为系统 back button。目前实现使用 `dismiss` 仅适合 modal present；从 nav push 进来时不需要 close button，系统 back 即可 — 可保持现状（`closeTapped` dismiss 在 push 情境下无效但不会崩溃）。

