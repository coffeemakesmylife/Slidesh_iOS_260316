# ConvertViewController 完整功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 ConvertViewController 中所有 7 个格式转换工具的完整功能，包括文件选择、格式选择、上传转换、结果预览。

**Architecture:** 新增 `ConvertAPIService`（网络层）、`ConvertJobViewController`（任务状态机）、`FormatPickerSheet`（格式选择底部面板），对 `ConvertViewController` 做最小改动以串联流程。

**Tech Stack:** Swift/UIKit, URLSession multipart/form-data, QLPreviewController, UIDocumentPickerViewController, UniformTypeIdentifiers

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `Slidesh/ViewControllers/ConvertViewController.swift` | 修改 | 新增 `ConvertToolKind` 枚举；`ConvertToolItem` 补全 4 个新字段；替换 `didSelectItemAt` 逻辑 |
| `Slidesh/Services/ConvertAPIService.swift` | 新建 | multipart 上传、进度回调、newslist 解析、结果文件下载 |
| `Slidesh/ViewControllers/FormatPickerSheet.swift` | 新建 | 自定义格式选择底部面板，列表行样式 |
| `Slidesh/ViewControllers/ConvertJobViewController.swift` | 新建 | 转换任务状态机 VC（idle/fileSelected/converting/success/error） |

---

## Task 1: 扩展 ConvertToolItem 数据模型

**Files:**
- Modify: `Slidesh/ViewControllers/ConvertViewController.swift`

### 背景

`ConvertToolItem` 目前只有 `title`, `subTitle`, `icon`, `colorName`, `isFeatured`。需要新增 `kind`（决定调哪个 API）、`formatOptions`（格式选项列表）、`acceptedExtensions`（文件选择器过滤）、`allowsMultiple`（合并 PDF 多选）。

- [ ] **Step 1: 在文件顶部（`ConvertSection` 枚举前）新增 `ConvertToolKind` 枚举**

在 `ConvertViewController.swift` 第 10 行之前插入：

```swift
// 每个转换工具对应的 API 类型
enum ConvertToolKind: String, Sendable {
    case pdfToWord      // 精选卡，固定输出 WORD
    case pdfConvert     // PDF 多格式
    case mergePDF       // 合并 PDF
    case wordConvert
    case excelConvert
    case pptConvert
    case fileToImage
}
```

- [ ] **Step 2: 给 `ConvertToolItem` 添加 4 个新字段**

将 `ConvertToolItem` struct 改为：

```swift
struct ConvertToolItem: Hashable, Sendable {
    let id            = UUID()
    let title:          String
    let subTitle:       String
    let icon:           String
    let colorName:      String
    let isFeatured:     Bool
    // 新增字段
    let kind:           ConvertToolKind
    let formatOptions:  [String]   // 空 = 无格式选择步骤
    let acceptedExtensions: [String] // 用于 UTType 文件过滤
    let allowsMultiple: Bool       // 合并PDF为true

    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
    nonisolated static func == (l: ConvertToolItem, r: ConvertToolItem) -> Bool { l.id == r.id }

    static let all: [ConvertSection: [ConvertToolItem]] = [
        .featured: [
            ConvertToolItem(title: "PDF 转 Word",
                            subTitle: "保持排版，精准转换，支持多种 OCR 识别",
                            icon: "doc.text.fill", colorName: "appPrimary", isFeatured: true,
                            kind: .pdfToWord, formatOptions: [],
                            acceptedExtensions: ["pdf"], allowsMultiple: false),
        ],
        .pdfTools: [
            ConvertToolItem(title: "PDF 转换器", subTitle: "转为 Word/Excel/PPT/HTML",
                            icon: "book.pages.fill", colorName: "systemRed", isFeatured: false,
                            kind: .pdfConvert,
                            formatOptions: ["WORD", "XML", "EXCEL", "PPT", "PNG", "HTML"],
                            acceptedExtensions: ["pdf"], allowsMultiple: false),
            ConvertToolItem(title: "合并 PDF", subTitle: "支持两份或多份文件合并",
                            icon: "plus.square.fill.on.square.fill", colorName: "systemBlue", isFeatured: false,
                            kind: .mergePDF, formatOptions: [],
                            acceptedExtensions: ["pdf"], allowsMultiple: true),
        ],
        .officeTools: [
            ConvertToolItem(title: "Word 转换", subTitle: "转为 PDF/HTML/PNG",
                            icon: "doc.richtext.fill", colorName: "systemIndigo", isFeatured: false,
                            kind: .wordConvert, formatOptions: ["PDF", "HTML", "PNG"],
                            acceptedExtensions: ["doc", "docx"], allowsMultiple: false),
            ConvertToolItem(title: "Excel 转换", subTitle: "转为 PDF/HTML/PNG",
                            icon: "tablecells.fill", colorName: "systemGreen", isFeatured: false,
                            kind: .excelConvert, formatOptions: ["PDF", "HTML", "PNG"],
                            acceptedExtensions: ["xls", "xlsx"], allowsMultiple: false),
            ConvertToolItem(title: "PPT 转换", subTitle: "转为 PDF/HTML/PNG",
                            icon: "tv.fill", colorName: "systemOrange", isFeatured: false,
                            kind: .pptConvert, formatOptions: ["PDF", "HTML", "PNG"],
                            acceptedExtensions: ["ppt", "pptx"], allowsMultiple: false),
        ],
        .utility: [
            ConvertToolItem(title: "文件转图片", subTitle: "将文档每一页提取为图片",
                            icon: "photo.on.rectangle.angled.fill", colorName: "systemTeal", isFeatured: false,
                            kind: .fileToImage, formatOptions: [],
                            acceptedExtensions: ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx"],
                            allowsMultiple: false),
        ],
    ]
}
```

- [ ] **Step 3: 构建项目，确认无编译错误**

在 Xcode 或通过 xcodebuild 构建，确认 `ConvertToolItem` 所有字段都正确初始化，没有"missing argument"错误。

- [ ] **Step 4: Commit**

```bash
git add Slidesh/ViewControllers/ConvertViewController.swift
git commit -m "feat: add ConvertToolKind enum and extend ConvertToolItem with kind/format/extensions fields"
```

---

## Task 2: 创建 ConvertAPIService

**Files:**
- Create: `Slidesh/Services/ConvertAPIService.swift`

### 背景

负责将本地文件以 multipart/form-data 上传到服务端转换 API，通过 URLSession delegate 追踪上传进度，解析响应，下载结果文件到临时目录。

**newslist 结构待确认**：API 文档仅给出顶层类型（string 或 object），未定义内部字段。实现时必须打印原始值，实际字段名联调后补全。

- [ ] **Step 1: 创建文件并实现基础骨架**

创建 `Slidesh/Services/ConvertAPIService.swift`：

```swift
//
//  ConvertAPIService.swift
//  Slidesh
//
//  格式转换网络服务：multipart/form-data 上传 + 进度回调 + 结果下载
//

import Foundation
import UniformTypeIdentifiers

final class ConvertAPIService: NSObject {

    static let shared = ConvertAPIService()
    private override init() {}

    private let baseURL = "http://43.156.217.34:8080"

    // 当前上传任务，用于取消
    private var uploadTask: URLSessionUploadTask?
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: ((Result<[URL], Error>) -> Void)?

    // MARK: - 公开接口

    /// 执行一次格式转换
    /// - Parameters:
    ///   - tool: 工具类型，决定 API 端点
    ///   - files: 本地文件 URL 数组（合并 PDF 传多个，其余传 1 个）
    ///   - outputFormat: 目标格式字符串，如 "PDF"/"WORD"（无格式选项的工具传 nil）
    ///   - onUploadProgress: 上传进度回调 0.0~1.0，主线程
    ///   - completion: 成功返回本地临时文件 URL 数组，失败返回 Error，主线程
    func convert(
        tool: ConvertToolKind,
        files: [URL],
        outputFormat: String?,
        onUploadProgress: @escaping (Double) -> Void,
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        guard !files.isEmpty else {
            DispatchQueue.main.async { completion(.failure(APIError.noData)) }
            return
        }

        let (path, bodyData) = buildRequest(tool: tool, files: files, outputFormat: outputFormat)

        guard let url = URL(string: baseURL + path) else {
            DispatchQueue.main.async { completion(.failure(APIError.invalidURL)) }
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // 重新构建带 boundary 的 body
        let (_, finalBody) = buildRequest(tool: tool, files: files, outputFormat: outputFormat, boundary: boundary)

        self.progressHandler  = onUploadProgress
        self.completionHandler = completion

        // 使用 delegate session 获取上传进度
        let config  = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        uploadTask  = session.uploadTask(with: request, from: finalBody)
        uploadTask?.resume()
    }

    /// 取消当前任务
    func cancel() {
        uploadTask?.cancel()
        uploadTask = nil
    }

    // MARK: - 私有：构建请求

    private func buildRequest(
        tool: ConvertToolKind,
        files: [URL],
        outputFormat: String?,
        boundary: String = "Boundary-placeholder"
    ) -> (path: String, body: Data) {
        var path = ""
        var body = Data()
        let crlf = "\r\n"

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("\(value)\(crlf)".data(using: .utf8)!)
        }

        func appendFile(_ name: String, fileURL: URL) {
            guard let data = try? Data(contentsOf: fileURL) else { return }
            let filename = fileURL.lastPathComponent
            let mime     = mimeType(for: fileURL)
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(crlf)".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(data)
            body.append(crlf.data(using: .utf8)!)
        }

        switch tool {
        case .pdfToWord:
            path = "/v1/api/document/pdf/pdftofile"
            appendField("type", "WORD")
            appendFile("file", fileURL: files[0])

        case .pdfConvert:
            path = "/v1/api/document/pdf/pdftofile"
            appendField("type", outputFormat ?? "WORD")
            appendFile("file", fileURL: files[0])

        case .mergePDF:
            if files.count == 2 {
                path = "/v1/api/document/pdf/mergetwopdf"
                appendFile("file1", fileURL: files[0])
                appendFile("file2", fileURL: files[1])
            } else {
                path = "/v1/api/document/pdf/mergemorepdf"
                // TODO: confirm multipart key name for mergemorepdf ("file" vs "files")
                for fileURL in files {
                    appendFile("files", fileURL: fileURL)
                }
            }

        case .wordConvert:
            path = "/v1/api/document/word/wordtofile"
            appendField("type", outputFormat ?? "PDF")
            appendFile("file", fileURL: files[0])

        case .excelConvert:
            path = "/v1/api/document/excel/exceltofile"
            appendField("type", outputFormat ?? "PDF")
            appendFile("file", fileURL: files[0])

        case .pptConvert:
            path = "/v1/api/document/ppt/ppttofile"
            appendField("type", outputFormat ?? "PDF")
            appendFile("file", fileURL: files[0])

        case .fileToImage:
            path = "/v1/api/document/images/filetoimages"
            appendFile("file", fileURL: files[0])
        }

        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return (path, body)
    }

    // MARK: - 私有：响应解析

    private func handleResponse(_ data: Data, completion: @escaping (Result<[URL], Error>) -> Void) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            DispatchQueue.main.async { completion(.failure(APIError.noData)) }
            return
        }

        // 业务错误码检查
        if let code = json["code"] as? Int, code != 0 && code != 200 {
            let msg = json["msg"] as? String ?? "服务器错误（code: \(code)）"
            DispatchQueue.main.async { completion(.failure(APIError.serverError(msg))) }
            return
        }

        let newslist = json["newslist"]
        // TODO: confirm newslist schema with real server
        // 打印原始值，联调时确认实际结构
        #if DEBUG
        print("[ConvertAPI] newslist raw: \(String(describing: newslist))")
        #endif

        // 尝试将 newslist 解析为下载 URL
        let urlStrings: [String]
        if let s = newslist as? String, !s.isEmpty {
            urlStrings = [s]
        } else if let obj = newslist as? [String: Any] {
            // TODO: confirm actual field name after testing with real server
            let candidate = (obj["url"] ?? obj["fileUrl"] ?? obj["downloadUrl"] ?? obj["path"]) as? String
            // fileToImage 可能是数组字段
            let listCandidate = (obj["urls"] ?? obj["list"] ?? obj["images"]) as? [String]
            if let list = listCandidate, !list.isEmpty {
                urlStrings = list
            } else if let single = candidate, !single.isEmpty {
                urlStrings = [single]
            } else {
                #if DEBUG
                print("[ConvertAPI] Could not extract URL from object: \(obj)")
                #endif
                DispatchQueue.main.async { completion(.failure(APIError.serverError("转换结果解析失败，请重试"))) }
                return
            }
        } else if let arr = newslist as? [String] {
            urlStrings = arr
        } else {
            DispatchQueue.main.async { completion(.failure(APIError.serverError("转换结果解析失败，请重试"))) }
            return
        }

        // 下载所有结果文件
        downloadFiles(from: urlStrings, completion: completion)
    }

    // 串行下载，全部完成后回调
    private func downloadFiles(from urlStrings: [String], completion: @escaping (Result<[URL], Error>) -> Void) {
        var localURLs: [URL] = []
        var remaining = urlStrings

        func downloadNext() {
            guard !remaining.isEmpty else {
                DispatchQueue.main.async { completion(.success(localURLs)) }
                return
            }
            let urlString = remaining.removeFirst()
            guard let url = URL(string: urlString) else {
                downloadNext(); return
            }
            URLSession.shared.downloadTask(with: url) { tmpURL, _, error in
                if let error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                guard let tmpURL else {
                    DispatchQueue.main.async { completion(.failure(APIError.noData)) }
                    return
                }
                // 移动到持久临时目录，避免被系统立即回收
                let destURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent.isEmpty ? UUID().uuidString : url.lastPathComponent)
                try? FileManager.default.removeItem(at: destURL)
                try? FileManager.default.moveItem(at: tmpURL, to: destURL)
                localURLs.append(destURL)
                downloadNext()
            }.resume()
        }
        downloadNext()
    }

    // MARK: - 私有：MIME type

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":  return "application/pdf"
        case "doc":  return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":  return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":  return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default:     return "application/octet-stream"
        }
    }
}

// MARK: - URLSessionTaskDelegate（上传进度）

extension ConvertAPIService: URLSessionTaskDelegate, URLSessionDataDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let handler = progressHandler
        DispatchQueue.main.async { handler?(progress) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 积累响应数据
        if responseData == nil { responseData = Data() }
        responseData?.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            responseData = nil
            progressHandler = nil
        }
        let completion = completionHandler
        completionHandler = nil

        if let error {
            // 取消不触发错误回调
            if (error as NSError).code == NSURLErrorCancelled { return }
            DispatchQueue.main.async { completion?(.failure(error)) }
            return
        }
        guard let data = responseData else {
            DispatchQueue.main.async { completion?(.failure(APIError.noData)) }
            return
        }
        handleResponse(data) { result in
            completion?(result)
        }
    }
}

// 响应数据缓冲（通过关联对象存储，避免实例变量声明在 extension）
private var responseDataKey = "responseDataKey"
extension ConvertAPIService {
    fileprivate var responseData: Data? {
        get { objc_getAssociatedObject(self, &responseDataKey) as? Data }
        set { objc_setAssociatedObject(self, &responseDataKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
```

- [ ] **Step 2: 构建，确认无编译错误**

- [ ] **Step 3: Commit**

```bash
git add Slidesh/Services/ConvertAPIService.swift
git commit -m "feat: add ConvertAPIService with multipart upload, progress tracking, and result download"
```

---

## Task 3: 创建 FormatPickerSheet

**Files:**
- Create: `Slidesh/ViewControllers/FormatPickerSheet.swift`

### 背景

自定义格式选择底部面板。以 `overFullScreen` 方式呈现，半透明遮罩，面板从底部滑入。列表行风格与 `ToolCell` 一致（`appCardBackground`，圆角，彩色图标）。

- [ ] **Step 1: 创建文件**

创建 `Slidesh/ViewControllers/FormatPickerSheet.swift`：

```swift
//
//  FormatPickerSheet.swift
//  Slidesh
//
//  自定义格式选择底部面板
//

import UIKit

final class FormatPickerSheet: UIViewController {

    // 格式选中后回调，参数为格式字符串如 "PDF"/"WORD"
    var onSelect: ((String) -> Void)?

    private let formats: [String]
    private let panelView  = UIView()
    private let stackView  = UIStackView()
    private let cancelBtn  = UIButton(type: .system)

    init(formats: [String]) {
        self.formats = formats
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 面板从底部滑入
        panelView.transform = CGAffineTransform(translationX: 0, y: panelView.bounds.height + 200)
        UIViewPropertyAnimator(duration: 0.35, dampingRatio: 0.85) {
            self.panelView.transform = .identity
        }.startAnimation()
    }

    private func setupUI() {
        // 半透明遮罩（点击背景关闭）
        view.backgroundColor = .appOverlay
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss(_:)))
        view.addGestureRecognizer(tap)

        // 面板容器
        panelView.backgroundColor    = .appBackgroundTertiary
        panelView.layer.cornerRadius = 24
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)
        panelView.addGestureRecognizer(UITapGestureRecognizer()) // 阻止点击穿透

        // 拖动条
        let handle = UIView()
        handle.backgroundColor    = .appTextSecondary.withAlphaComponent(0.4)
        handle.layer.cornerRadius = 2
        handle.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(handle)

        // 标题
        let titleLabel = UILabel()
        titleLabel.text      = "选择输出格式"
        titleLabel.font      = .systemFont(ofSize: 18, weight: .heavy)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(titleLabel)

        // 格式列表
        stackView.axis    = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(stackView)

        for format in formats {
            stackView.addArrangedSubview(makeFormatRow(format))
        }

        // 取消按钮
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.setTitleColor(.appTextSecondary, for: .normal)
        cancelBtn.titleLabel?.font   = .systemFont(ofSize: 16, weight: .medium)
        cancelBtn.backgroundColor    = .appCardBackground
        cancelBtn.layer.cornerRadius = 16
        cancelBtn.layer.borderWidth  = 1
        cancelBtn.layer.borderColor  = UIColor.appCardBorder.cgColor
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        panelView.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            handle.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 4),

            titleLabel.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -20),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),

            cancelBtn.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 12),
            cancelBtn.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            cancelBtn.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
            cancelBtn.heightAnchor.constraint(equalToConstant: 52),
            cancelBtn.bottomAnchor.constraint(equalTo: panelView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func makeFormatRow(_ format: String) -> UIView {
        let container = UIView()
        container.backgroundColor    = .appCardBackground.withAlphaComponent(0.7)
        container.layer.cornerRadius = 16
        container.layer.borderWidth  = 1
        container.layer.borderColor  = UIColor.appCardBorder.cgColor
        container.heightAnchor.constraint(equalToConstant: 64).isActive = true

        // 图标背景
        let iconBg = UIView()
        iconBg.layer.cornerRadius = 12
        let (symbol, color) = iconInfo(for: format)
        iconBg.backgroundColor   = color.withAlphaComponent(0.15)
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconBg)

        let iconView = UIImageView(image: UIImage(systemName: symbol))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor   = color
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // 格式名
        let nameLabel = UILabel()
        nameLabel.text      = format
        nameLabel.font      = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = .appTextPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        // 扩展名说明
        let extLabel = UILabel()
        extLabel.text      = extensionHint(for: format)
        extLabel.font      = .systemFont(ofSize: 12)
        extLabel.textColor = .appTextSecondary
        extLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(extLabel)

        // 箭头
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor   = .appTextSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chevron)

        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            iconBg.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),

            extLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            extLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            chevron.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
        ])

        // 点击手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFormatTap(_:)))
        container.addGestureRecognizer(tap)
        container.tag = formats.firstIndex(of: format) ?? 0
        container.isUserInteractionEnabled = true

        return container
    }

    @objc private func handleFormatTap(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, index < formats.count else { return }
        let selected = formats[index]
        dismissWithAnimation { [weak self] in
            self?.onSelect?(selected)
        }
    }

    @objc private func didTapCancel() {
        dismissWithAnimation(completion: nil)
    }

    @objc private func dismiss(_ gesture: UITapGestureRecognizer) {
        // 只响应遮罩区域，不响应面板内点击
        let loc = gesture.location(in: view)
        guard !panelView.frame.contains(loc) else { return }
        dismissWithAnimation(completion: nil)
    }

    private func dismissWithAnimation(completion: (() -> Void)?) {
        UIViewPropertyAnimator(duration: 0.25, curve: .easeIn) {
            self.panelView.transform = CGAffineTransform(translationX: 0, y: self.panelView.bounds.height + 200)
            self.view.backgroundColor = .clear
        }.startAnimation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.dismiss(animated: false, completion: completion)
        }
    }

    // MARK: - 格式图标/颜色/提示

    private func iconInfo(for format: String) -> (symbol: String, color: UIColor) {
        switch format.uppercased() {
        case "WORD":  return ("doc.richtext.fill",    .systemIndigo)
        case "PDF":   return ("book.pages.fill",       .systemRed)
        case "EXCEL": return ("tablecells.fill",        .systemGreen)
        case "PPT":   return ("tv.fill",               .systemOrange)
        case "PNG":   return ("photo.fill",             .systemPurple)
        case "HTML":  return ("globe",                  .systemTeal)
        case "XML":   return ("chevron.left.forwardslash.chevron.right", .systemBrown)
        default:      return ("doc.fill",              .appPrimary)
        }
    }

    private func extensionHint(for format: String) -> String {
        switch format.uppercased() {
        case "WORD":  return ".docx 文档格式"
        case "PDF":   return ".pdf 便携文档"
        case "EXCEL": return ".xlsx 表格格式"
        case "PPT":   return ".pptx 演示文稿"
        case "PNG":   return ".png 图片格式"
        case "HTML":  return ".html 网页格式"
        case "XML":   return ".xml 标记语言"
        default:      return format.lowercased()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 更新 CALayer 颜色
        cancelBtn.layer.borderColor = UIColor.appCardBorder.cgColor
    }
}
```

- [ ] **Step 2: 构建，确认无编译错误**

- [ ] **Step 3: Commit**

```bash
git add Slidesh/ViewControllers/FormatPickerSheet.swift
git commit -m "feat: add FormatPickerSheet custom bottom panel for output format selection"
```

---

## Task 4: 创建 ConvertJobViewController

**Files:**
- Create: `Slidesh/ViewControllers/ConvertJobViewController.swift`

### 背景

单次转换任务页面，push 进入。管理 5 个状态（idle/fileSelected/converting/success/error），状态切换时更新 UI。成功后 present QLPreviewController。

**注意**：`resolveToolColor(_:)` 在 `ConvertViewController.swift` 中以 `private` 级别定义，`ConvertJobViewController` 无法访问。Task 4 在文件内定义一个同名的 `internal` 级别版本（或直接内联颜色解析逻辑）。

- [ ] **Step 1: 创建文件**

创建 `Slidesh/ViewControllers/ConvertJobViewController.swift`：

```swift
//
//  ConvertJobViewController.swift
//  Slidesh
//
//  格式转换任务页：选文件 → 上传 → 预览结果
//

import UIKit
import UniformTypeIdentifiers
import QuickLook

final class ConvertJobViewController: UIViewController {

    // MARK: - 初始化参数

    private let tool:         ConvertToolItem
    private var outputFormat: String?    // 已选格式（有格式选项时由调用方传入）

    init(tool: ConvertToolItem, outputFormat: String? = nil) {
        self.tool         = tool
        self.outputFormat = outputFormat
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 状态

    private enum State {
        case idle
        case fileSelected(files: [URL])
        case converting
        case success(resultURLs: [URL])
        case error(message: String, lastFiles: [URL])
    }

    private var state: State = .idle {
        didSet { updateUI(for: state) }
    }

    // MARK: - UI 元素

    private let scrollView   = UIScrollView()
    private let contentView  = UIView()

    // 顶部图标区
    private let iconBg       = UIView()
    private let iconView     = UIImageView()

    // 标题/副标题
    private let titleLabel   = UILabel()
    private let subLabel     = UILabel()

    // 文件卡片（fileSelected 显示）
    private let fileCardView = UIView()
    private let fileIconView = UIImageView()
    private let fileNameLabel = UILabel()
    private let fileSizeLabel = UILabel()
    private let formatBadge  = UILabel()
    // 合并PDF文件列表
    private let fileListStack = UIStackView()

    // 进度区（converting 显示）
    private let progressContainer = UIView()
    private let progressBg        = UIView()
    private let progressFill      = GradientProgressView()
    private let progressLabel     = UILabel()

    // 状态图标（success/error）
    private let statusIconView = UIImageView()

    // 按钮区
    private let primaryBtn    = GradientButton()
    private let secondaryBtn  = UIButton(type: .system)

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = tool.title
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()
        setupUI()
        state = .idle
    }

    // MARK: - UI 搭建

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        setupIconArea()
        setupTitleArea()
        setupFileCard()
        setupProgressArea()
        setupStatusIcon()
        setupButtons()
    }

    private func setupIconArea() {
        iconBg.layer.cornerRadius = 28
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBg)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconBg.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 32),
            iconBg.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 80),
            iconBg.heightAnchor.constraint(equalToConstant: 80),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
        ])

        let color = resolveToolColor(tool.colorName)
        iconBg.backgroundColor = color.withAlphaComponent(0.15)
        iconView.image  = UIImage(systemName: tool.icon)
        iconView.tintColor = color
    }

    private func setupTitleArea() {
        titleLabel.font          = .systemFont(ofSize: 22, weight: .heavy)
        titleLabel.textColor     = .appTextPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subLabel.font          = .systemFont(ofSize: 14)
        subLabel.textColor     = .appTextSecondary
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 0
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        titleLabel.text = tool.title
    }

    private func setupFileCard() {
        fileCardView.backgroundColor    = .appCardBackground.withAlphaComponent(0.7)
        fileCardView.layer.cornerRadius = 20
        fileCardView.layer.borderWidth  = 1
        fileCardView.layer.borderColor  = UIColor.appCardBorder.cgColor
        fileCardView.isHidden = true
        fileCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fileCardView)

        fileIconView.image       = UIImage(systemName: "doc.fill")
        fileIconView.tintColor   = .appPrimary
        fileIconView.contentMode = .scaleAspectFit
        fileIconView.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileIconView)

        fileNameLabel.font      = .systemFont(ofSize: 15, weight: .semibold)
        fileNameLabel.textColor = .appTextPrimary
        fileNameLabel.numberOfLines = 2
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileNameLabel)

        fileSizeLabel.font      = .systemFont(ofSize: 12)
        fileSizeLabel.textColor = .appTextSecondary
        fileSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileSizeLabel)

        formatBadge.font            = .systemFont(ofSize: 12, weight: .bold)
        formatBadge.textColor       = .white
        formatBadge.backgroundColor = .appPrimary
        formatBadge.layer.cornerRadius = 8
        formatBadge.clipsToBounds   = true
        formatBadge.textAlignment   = .center
        formatBadge.isHidden        = true
        formatBadge.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(formatBadge)

        fileListStack.axis    = .vertical
        fileListStack.spacing = 8
        fileListStack.isHidden = true
        fileListStack.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileListStack)

        NSLayoutConstraint.activate([
            fileCardView.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 24),
            fileCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            fileCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            fileIconView.topAnchor.constraint(equalTo: fileCardView.topAnchor, constant: 16),
            fileIconView.leadingAnchor.constraint(equalTo: fileCardView.leadingAnchor, constant: 16),
            fileIconView.widthAnchor.constraint(equalToConstant: 36),
            fileIconView.heightAnchor.constraint(equalToConstant: 36),

            fileNameLabel.topAnchor.constraint(equalTo: fileCardView.topAnchor, constant: 16),
            fileNameLabel.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 12),
            fileNameLabel.trailingAnchor.constraint(equalTo: formatBadge.leadingAnchor, constant: -8),

            fileSizeLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 4),
            fileSizeLabel.leadingAnchor.constraint(equalTo: fileNameLabel.leadingAnchor),

            formatBadge.centerYAnchor.constraint(equalTo: fileCardView.topAnchor, constant: 32),
            formatBadge.trailingAnchor.constraint(equalTo: fileCardView.trailingAnchor, constant: -16),
            formatBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            formatBadge.heightAnchor.constraint(equalToConstant: 24),

            fileListStack.topAnchor.constraint(equalTo: fileIconView.bottomAnchor, constant: 12),
            fileListStack.leadingAnchor.constraint(equalTo: fileCardView.leadingAnchor, constant: 16),
            fileListStack.trailingAnchor.constraint(equalTo: fileCardView.trailingAnchor, constant: -16),
            fileListStack.bottomAnchor.constraint(equalTo: fileCardView.bottomAnchor, constant: -16),
        ])

        // 单文件模式：fileSizeLabel 底部撑起 fileCardView
        fileSizeLabel.bottomAnchor.constraint(lessThanOrEqualTo: fileCardView.bottomAnchor, constant: -16).isActive = true
    }

    private func setupProgressArea() {
        progressContainer.isHidden = true
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressContainer)

        progressBg.backgroundColor    = .appCardBackground.withAlphaComponent(0.6)
        progressBg.layer.cornerRadius = 8
        progressBg.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressBg)

        progressFill.layer.cornerRadius = 8
        progressFill.clipsToBounds      = true
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBg.addSubview(progressFill)

        progressLabel.font      = .systemFont(ofSize: 14)
        progressLabel.textColor = .appTextSecondary
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressLabel)

        NSLayoutConstraint.activate([
            progressContainer.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 32),
            progressContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            progressBg.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressBg.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBg.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressBg.heightAnchor.constraint(equalToConstant: 16),

            progressFill.topAnchor.constraint(equalTo: progressBg.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBg.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBg.bottomAnchor),

            progressLabel.topAnchor.constraint(equalTo: progressBg.bottomAnchor, constant: 12),
            progressLabel.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressLabel.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
        ])
    }

    private var progressFillWidth: NSLayoutConstraint?

    private func setupStatusIcon() {
        statusIconView.contentMode = .scaleAspectFit
        statusIconView.isHidden    = true
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusIconView)

        NSLayoutConstraint.activate([
            statusIconView.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 32),
            statusIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 64),
            statusIconView.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    private func setupButtons() {
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(primaryBtn)
        primaryBtn.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        secondaryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        secondaryBtn.setTitleColor(.appTextSecondary, for: .normal)
        secondaryBtn.backgroundColor    = .appCardBackground.withAlphaComponent(0.7)
        secondaryBtn.layer.cornerRadius = 16
        secondaryBtn.layer.borderWidth  = 1
        secondaryBtn.layer.borderColor  = UIColor.appCardBorder.cgColor
        secondaryBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(secondaryBtn)
        secondaryBtn.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)

        NSLayoutConstraint.activate([
            primaryBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            primaryBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            primaryBtn.heightAnchor.constraint(equalToConstant: 54),

            secondaryBtn.topAnchor.constraint(equalTo: primaryBtn.bottomAnchor, constant: 12),
            secondaryBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secondaryBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            secondaryBtn.heightAnchor.constraint(equalToConstant: 48),
            secondaryBtn.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])

        // primaryBtn 顶部约束需在状态更新时动态调整，先连接到 statusIconView
        primaryBtn.topAnchor.constraint(equalTo: statusIconView.bottomAnchor, constant: 32).isActive = true
    }

    // MARK: - 状态更新

    private func updateUI(for state: State) {
        // 隐藏所有动态区域
        fileCardView.isHidden      = true
        progressContainer.isHidden = true
        statusIconView.isHidden    = true
        isModalInPresentation      = false

        switch state {
        case .idle:
            let hint = tool.allowsMultiple
                ? "请选择 2 个或更多 PDF 文件"
                : "支持：\(tool.acceptedExtensions.joined(separator: "、"))"
            subLabel.text = hint
            primaryBtn.setTitle(tool.allowsMultiple ? "选择多个文件（至少 2 个）" : "选择文件", for: .normal)
            secondaryBtn.isHidden = true

        case .fileSelected(let files):
            fileCardView.isHidden = false
            subLabel.text = nil
            if tool.allowsMultiple {
                // 合并PDF：显示文件列表
                fileIconView.isHidden = true
                fileNameLabel.isHidden = true
                fileSizeLabel.isHidden = true
                fileListStack.isHidden = false
                rebuildFileList(files: files)
            } else {
                fileIconView.isHidden  = false
                fileNameLabel.isHidden = false
                fileSizeLabel.isHidden = false
                fileListStack.isHidden = true
                fileNameLabel.text = files[0].lastPathComponent
                fileSizeLabel.text = fileSizeString(url: files[0])
                if let fmt = outputFormat {
                    formatBadge.text    = "→ \(fmt)"
                    formatBadge.isHidden = false
                }
            }
            primaryBtn.setTitle("开始转换", for: .normal)
            primaryBtn.isEnabled = !tool.allowsMultiple || files.count >= 2
            secondaryBtn.isHidden = false
            secondaryBtn.setTitle("重新选择", for: .normal)

        case .converting:
            progressContainer.isHidden = false
            isModalInPresentation      = true
            subLabel.text              = nil
            setUploadProgress(0)
            progressLabel.text = "正在上传..."
            primaryBtn.setTitle("取消", for: .normal)
            secondaryBtn.isHidden = true

        case .success:
            statusIconView.isHidden = false
            statusIconView.image     = UIImage(systemName: "checkmark.circle.fill")
            statusIconView.tintColor = .appSuccess
            subLabel.text = "转换完成！"
            primaryBtn.setTitle("预览结果", for: .normal)
            secondaryBtn.isHidden = false
            secondaryBtn.setTitle("再转一个", for: .normal)

        case .error(let message, _):
            statusIconView.isHidden = false
            statusIconView.image     = UIImage(systemName: "exclamationmark.circle.fill")
            statusIconView.tintColor = .appError
            subLabel.text = message
            primaryBtn.setTitle("重试", for: .normal)
            secondaryBtn.isHidden = false
            secondaryBtn.setTitle("重新选择文件", for: .normal)
        }
    }

    private func setUploadProgress(_ value: Double) {
        // 移除旧约束
        progressFillWidth?.isActive = false
        if value >= 1.0 {
            // 上传完成，切换为不确定进度动画
            progressLabel.text = "转换中..."
            progressFillWidth = progressFill.widthAnchor.constraint(
                equalTo: progressBg.widthAnchor, multiplier: 0.6)
            progressFillWidth?.isActive = true
            animateIndeterminateProgress()
        } else {
            progressFillWidth = progressFill.widthAnchor.constraint(
                equalTo: progressBg.widthAnchor, multiplier: max(0.05, value))
            progressFillWidth?.isActive = true
            progressLabel.text = "正在上传... \(Int(value * 100))%"
        }
    }

    private func animateIndeterminateProgress() {
        UIView.animate(withDuration: 0.8, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction]) {
            self.progressFill.alpha = 0.5
        }
    }

    // MARK: - 文件列表（合并PDF）

    private func rebuildFileList(files: [URL]) {
        fileListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, file) in files.enumerated() {
            let row = makeFileRow(file: file, index: i, total: files.count)
            fileListStack.addArrangedSubview(row)
        }
        // 刷新「开始转换」按钮
        if case .fileSelected(let f) = state {
            primaryBtn.isEnabled = f.count >= 2
        }
    }

    private func makeFileRow(file: URL, index: Int, total: Int) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "doc.fill"))
        icon.tintColor = .appPrimary
        icon.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(icon)

        let name = UILabel()
        name.text      = file.lastPathComponent
        name.font      = .systemFont(ofSize: 14)
        name.textColor = .appTextPrimary
        name.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(name)

        let del = UIButton(type: .system)
        del.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        del.tintColor = .appError.withAlphaComponent(0.7)
        del.tag = index
        del.addTarget(self, action: #selector(deleteFile(_:)), for: .touchUpInside)
        del.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(del)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),

            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            name.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            name.trailingAnchor.constraint(equalTo: del.leadingAnchor, constant: -8),

            del.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            del.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            del.widthAnchor.constraint(equalToConstant: 24),
        ])
        return row
    }

    @objc private func deleteFile(_ sender: UIButton) {
        guard case .fileSelected(var files) = state else { return }
        files.remove(at: sender.tag)
        state = .fileSelected(files: files)
    }

    // MARK: - 按钮动作

    // 取消转换时用于恢复到 fileSelected 的文件列表
    private var lastConvertedFiles: [URL] = []

    @objc private func didTapPrimary() {
        switch state {
        case .idle:
            openFilePicker()
        case .fileSelected(let files):
            startConversion(files: files)
        case .converting:
            // 必须先保存 files，state = .converting 之前已存入 lastConvertedFiles
            ConvertAPIService.shared.cancel()
            state = lastConvertedFiles.isEmpty ? .idle : .fileSelected(files: lastConvertedFiles)
        case .success(let urls):
            showPreview(urls: urls)
        case .error(_, let files):
            startConversion(files: files)
        }
    }

    @objc private func didTapSecondary() {
        switch state {
        case .fileSelected:
            state = .idle
            openFilePicker()
        case .success:
            state = .idle
        case .error:
            state = .idle
        default:
            break
        }
    }

    // MARK: - 文件选择

    private func openFilePicker() {
        let types = tool.acceptedExtensions.compactMap { UTType(filenameExtension: $0) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types.isEmpty ? [.item] : types)
        picker.allowsMultipleSelection = tool.allowsMultiple
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - 转换

    private func startConversion(files: [URL]) {
        lastConvertedFiles = files   // 保存，以便取消时恢复
        state = .converting
        ConvertAPIService.shared.convert(
            tool: tool.kind,
            files: files,
            outputFormat: outputFormat,
            onUploadProgress: { [weak self] progress in
                self?.setUploadProgress(progress)
            },
            completion: { [weak self] result in
                guard let self else { return }
                progressFill.layer.removeAllAnimations()
                progressFill.alpha = 1
                switch result {
                case .success(let urls):
                    state = .success(resultURLs: urls)
                case .failure(let error):
                    state = .error(message: error.localizedDescription, lastFiles: files)
                }
            }
        )
    }

    // MARK: - 预览

    private func showPreview(urls: [URL]) {
        let ql = QLPreviewController()
        ql.dataSource = self
        ql.currentPreviewItemIndex = 0
        // 存储 URL 供 dataSource 访问
        previewURLs = urls
        present(ql, animated: true)
    }

    private var previewURLs: [URL] = []

    // MARK: - 辅助

    private func fileSizeString(url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - UIDocumentPickerDelegate

extension ConvertJobViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // 申请安全访问权限
        let accessible = urls.filter { $0.startAccessingSecurityScopedResource() }
        state = .fileSelected(files: accessible.isEmpty ? urls : accessible)
    }
}

// MARK: - QLPreviewControllerDataSource

extension ConvertJobViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewURLs.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURLs[index] as NSURL
    }
}

// MARK: - GradientButton（渐变主按钮）

final class GradientButton: UIButton {
    private let gradLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradLayer.colors     = [UIColor.appGradientStart.cgColor,
                                UIColor.appGradientMid.cgColor,
                                UIColor.appGradientEnd.cgColor]
        gradLayer.locations  = [0.0, 0.55, 1.0]
        gradLayer.startPoint = CGPoint(x: 0, y: 0)
        gradLayer.endPoint   = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradLayer, at: 0)
        layer.cornerRadius = 16
        clipsToBounds = true
        setTitleColor(.white, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradLayer.frame = bounds
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1.0 : 0.5 }
    }
}

// MARK: - GradientProgressView（渐变进度条）

final class GradientProgressView: UIView {
    private let gradLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradLayer.colors     = [UIColor.appGradientStart.cgColor, UIColor.appGradientEnd.cgColor]
        gradLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradLayer, at: 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradLayer.frame = bounds
    }
}
```

- [ ] **Step 2: 构建，确认无编译错误**

如有编译错误，根据错误信息修正（常见：progressFillWidth 初始化时机、状态切换中访问关联值需要正确匹配 case）。

- [ ] **Step 3: Commit**

```bash
git add Slidesh/ViewControllers/ConvertJobViewController.swift
git commit -m "feat: add ConvertJobViewController with idle/fileSelected/converting/success/error state machine"
```

---

## Task 5: 串联 ConvertViewController 交互流程

**Files:**
- Modify: `Slidesh/ViewControllers/ConvertViewController.swift`
- Modify: `Slidesh/ViewControllers/ConvertJobViewController.swift`（添加 `prefillFiles` 方法）

### 背景

替换 `didSelectItemAt` 中的 "功能开发中" alert，改为：有格式选项 → FormatPickerSheet → 文件选择 → push ConvertJobViewController；无格式选项 → 直接文件选择 → push ConvertJobViewController。

- [ ] **Step 1: 给 ConvertViewController 添加所需 import 和属性**

在 `ConvertViewController.swift` 文件顶部添加：

```swift
import UniformTypeIdentifiers
```

并在 `ConvertViewController` 类中添加属性（用于在文件选择回调中关联工具和格式）：

```swift
private var pendingTool:   ConvertToolItem?
private var pendingFormat: String?
```

- [ ] **Step 2: 替换 didSelectItemAt 实现**

将现有的 `didSelectItemAt` 方法替换为：

```swift
func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    UISelectionFeedbackGenerator().selectionChanged()

    if item.formatOptions.isEmpty {
        // 无格式选项：直接选文件
        pendingTool   = item
        pendingFormat = nil
        openDocumentPicker(for: item)
    } else {
        // 有格式选项：先弹格式选择面板
        let sheet = FormatPickerSheet(formats: item.formatOptions)
        sheet.onSelect = { [weak self] format in
            guard let self else { return }
            self.pendingTool   = item
            self.pendingFormat = format
            self.openDocumentPicker(for: item)
        }
        present(sheet, animated: false)
    }
}

private func openDocumentPicker(for item: ConvertToolItem) {
    let types = item.acceptedExtensions.compactMap { UTType(filenameExtension: $0) }
    let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: types.isEmpty ? [.item] : types)
    picker.allowsMultipleSelection = item.allowsMultiple
    picker.delegate = self
    present(picker, animated: true)
}
```

- [ ] **Step 3: 添加 UIDocumentPickerDelegate 扩展**

在文件末尾添加：

```swift
// MARK: - UIDocumentPickerDelegate

extension ConvertViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let tool = pendingTool else { return }
        let accessible = urls.filter { $0.startAccessingSecurityScopedResource() }
        let finalURLs  = accessible.isEmpty ? urls : accessible
        let jobVC = ConvertJobViewController(tool: tool, outputFormat: pendingFormat)
        // 预填已选文件，直接进入 fileSelected 状态
        jobVC.prefillFiles(finalURLs)
        navigationController?.pushViewController(jobVC, animated: true)
        pendingTool   = nil
        pendingFormat = nil
    }
}
```

在 `ConvertJobViewController` 中添加一个 `prefillFiles` 方法（在 `ConvertJobViewController.swift` 的 public 区域）：

```swift
/// 由调用方在 push 前预填文件，直接进入 fileSelected 状态
func prefillFiles(_ files: [URL]) {
    // viewDidLoad 后才能设置 state，提前存储
    pendingPrefillFiles = files
}
private var pendingPrefillFiles: [URL]?
```

并在 `ConvertJobViewController.viewDidLoad` 末尾添加：

```swift
if let files = pendingPrefillFiles {
    pendingPrefillFiles = nil
    state = .fileSelected(files: files)
}
```

- [ ] **Step 4: 构建项目，确认无编译错误**

- [ ] **Step 5: 在模拟器上运行，手动测试主要流程**

测试清单（在 Xcode 模拟器中）：

1. **PDF 转 Word（精选卡）**：点击 → 文件选择器弹出（仅 PDF）→ 选一个 PDF → push ConvertJobVC（idle → fileSelected）→ 点「开始转换」→ converting 状态显示进度 → 等待响应
2. **PDF 转换器**：点击 → FormatPickerSheet 弹出 → 选 WORD → 文件选择器 → push ConvertJobVC
3. **合并 PDF**：点击 → 文件选择器（多选）→ 选 2 个或 3 个 PDF → push ConvertJobVC 显示文件列表 → 少于 2 个时「开始转换」置灰
4. **取消**：converting 状态下点「取消」→ 回到 fileSelected
5. **FormatPickerSheet**：底部滑入动画、点取消关闭、点格式行关闭并继续流程

- [ ] **Step 6: Commit**

```bash
git add Slidesh/ViewControllers/ConvertViewController.swift
git commit -m "feat: wire up ConvertViewController flow — format picker → file picker → ConvertJobViewController"
```

---

## Task 6: 将新文件加入 Xcode 项目

**Files:**
- Modify: `Slidesh.xcodeproj/project.pbxproj`

### 背景

直接创建的 `.swift` 文件不会自动加入 Xcode target。需要在 Xcode 中手动添加，或通过 `project.pbxproj` 编辑。

- [ ] **Step 1: 在 Xcode 中添加新文件到 target**

打开 `Slidesh.xcodeproj`，在 Project Navigator 中右键 `Services` 文件夹 → Add Files → 选 `ConvertAPIService.swift`；右键 `ViewControllers` 文件夹 → Add Files → 选 `FormatPickerSheet.swift` 和 `ConvertJobViewController.swift`。

确认每个文件都勾选了 `Slidesh` target。

- [ ] **Step 2: 构建，确认三个新文件都被编译（无 "use of unresolved identifier" 报错）**

- [ ] **Step 3: Commit**

```bash
git add Slidesh.xcodeproj/project.pbxproj
git commit -m "chore: add ConvertAPIService, FormatPickerSheet, ConvertJobViewController to Xcode target"
```

---

## 联调注意事项

完成以上任务后，需要用真实文件测试各接口并填补以下 TODO：

1. **newslist 实际结构**：运行任意转换，观察控制台 `[ConvertAPI] newslist raw:` 打印内容，确认 URL 字段名，更新 `ConvertAPIService.handleResponse` 中的解析逻辑
2. **mergemorepdf 字段名**：测试合并 3+ 个 PDF，如响应报参数错误，将 `"files"` 改为 `"file"` 重试
3. **文件访问权限**：`startAccessingSecurityScopedResource()` 需对应 `stopAccessingSecurityScopedResource()`，转换完成后释放（在 `ConvertAPIService.convert` 完成回调后调用）
