//
//  PPTPreviewViewController.swift
//  Slidesh
//
//  PPT 预览页：WKWebView 加载 fileUrl，支持保存到本地 / 分享
//

import UIKit
import WebKit
import ZIPFoundation

class PPTPreviewViewController: UIViewController {

    private var pptInfo: PPTInfo
    private let canChangeTemplate: Bool

    // MARK: - 子视图

    private var webView: WKWebView!
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?

    private let bottomBar         = UIView()
    private let saveBtn           = UIButton(type: .custom)   // 保存到本地
    private let shareBtn          = UIButton(type: .custom)   // 分享（非换模板场景）
    private let changeTemplateBtn = UIButton(type: .custom)   // 换模板（换模板场景）
    private var saveBtnGrad:       CAGradientLayer?
    private var shareBtnGrad:      CAGradientLayer?

    // 下载任务（保存到本地 / 分享共用）
    private var downloadTask: URLSessionDownloadTask?
    private let saveIndicator  = UIActivityIndicatorView(style: .medium)
    private let shareIndicator = UIActivityIndicatorView(style: .medium)

    // 换模板加载遮罩
    private var loadingOverlay: UIView?

    // MARK: - Init

    init(pptInfo: PPTInfo, canChangeTemplate: Bool = false) {
        self.pptInfo = pptInfo
        self.canChangeTemplate = canChangeTemplate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackgroundPrimary
        setupNavBar()
        setupBottomBar()
        setupWebView()
        setupProgressBar()
        loadContent()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        saveBtnGrad?.frame  = saveBtn.bounds
        shareBtnGrad?.frame = shareBtn.bounds
        // 换模板按钮不用渐变，borderColor 跟随 trait 更新
        changeTemplateBtn.layer.borderColor = UIColor.appPrimary.withAlphaComponent(0.3).cgColor
    }

    // MARK: - 导航栏

    private func setupNavBar() {
        title = pptInfo.subject ?? "PPT 预览"

        // push 进来时系统 back button 自动显示；modal present 才显示 xmark
        if navigationController?.viewControllers.first == self {
            let closeBtn = UIBarButtonItem(
                image: UIImage(systemName: "xmark"),
                style: .plain, target: self, action: #selector(closeTapped))
            closeBtn.tintColor = .appTextPrimary
            navigationItem.leftBarButtonItem = closeBtn
        }

    }

    // MARK: - 底部栏

    private func setupBottomBar() {
        bottomBar.backgroundColor = .appCardBackground
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        sep.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(sep)

        view.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sep.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        // 保存到本地按钮（右）
        saveBtn.setTitle("保存到本地", for: .normal)
        saveBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.layer.cornerRadius = 26
        saveBtn.clipsToBounds = true
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        bottomBar.addSubview(saveBtn)
        saveBtnGrad = makeGradient(for: saveBtn, alpha: 1.0)

        // 左侧按钮：换模板场景用 changeTemplateBtn，否则用 shareBtn
        let leftBtn: UIButton
        if canChangeTemplate {
            changeTemplateBtn.setTitle("换模板", for: .normal)
            changeTemplateBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            changeTemplateBtn.setTitleColor(.appPrimary, for: .normal)
            changeTemplateBtn.backgroundColor = .appCardBackground
            changeTemplateBtn.layer.cornerRadius = 26
            changeTemplateBtn.layer.borderWidth = 1.5
            changeTemplateBtn.layer.borderColor = UIColor.appPrimary.withAlphaComponent(0.3).cgColor
            changeTemplateBtn.clipsToBounds = true
            changeTemplateBtn.translatesAutoresizingMaskIntoConstraints = false
            changeTemplateBtn.addTarget(self, action: #selector(changeTemplateTapped), for: .touchUpInside)
            bottomBar.addSubview(changeTemplateBtn)
            leftBtn = changeTemplateBtn
        } else {
            shareBtn.setTitle("分享", for: .normal)
            shareBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            shareBtn.setTitleColor(.white, for: .normal)
            shareBtn.layer.cornerRadius = 26
            shareBtn.clipsToBounds = true
            shareBtn.translatesAutoresizingMaskIntoConstraints = false
            shareBtn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
            bottomBar.addSubview(shareBtn)
            shareBtnGrad = makeGradient(for: shareBtn, alpha: 0.8)
            leftBtn = shareBtn
        }

        NSLayoutConstraint.activate([
            leftBtn.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            leftBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            leftBtn.heightAnchor.constraint(equalToConstant: 52),
            leftBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            saveBtn.topAnchor.constraint(equalTo: leftBtn.topAnchor),
            saveBtn.leadingAnchor.constraint(equalTo: leftBtn.trailingAnchor, constant: 12),
            saveBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            saveBtn.heightAnchor.constraint(equalTo: leftBtn.heightAnchor),
            saveBtn.widthAnchor.constraint(equalTo: leftBtn.widthAnchor),
        ])

        // loading 指示器：saveIndicator 始终需要，shareIndicator 仅在非换模板场景
        let indicators: [(UIActivityIndicatorView, UIButton)] = canChangeTemplate
            ? [(saveIndicator, saveBtn)]
            : [(saveIndicator, saveBtn), (shareIndicator, shareBtn)]
        for (indicator, btn) in indicators {
            indicator.color = .white
            indicator.hidesWhenStopped = true
            indicator.translatesAutoresizingMaskIntoConstraints = false
            bottomBar.addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            ])
        }
    }

    private func makeGradient(for btn: UIButton, alpha: CGFloat) -> CAGradientLayer {
        let g = CAGradientLayer()
        // 与 VIP 卡片渐变统一
        g.colors     = [UIColor.appGradientStart.withAlphaComponent(alpha).cgColor,
                        UIColor.appGradientMid.withAlphaComponent(alpha).cgColor,
                        UIColor.appGradientEnd.withAlphaComponent(alpha).cgColor]
        g.locations  = [0.0, 0.55, 1.0]
        g.startPoint = CGPoint(x: 0, y: 0.5)
        g.endPoint   = CGPoint(x: 1, y: 0.5)
        g.cornerRadius = 26
        btn.layer.insertSublayer(g, at: 0)
        return g
    }

    // MARK: - WebView

    private func setupWebView() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        webView.scrollView.contentInsetAdjustmentBehavior = .always
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
        ])
    }

    private func setupProgressBar() {
        progressBar.progressTintColor = .appPrimary
        progressBar.trackTintColor    = .clear
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            progressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2),
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, change in
            guard let self, let value = change.newValue else { return }
            DispatchQueue.main.async {
                self.progressBar.setProgress(Float(value), animated: true)
                self.progressBar.isHidden = value >= 1.0
            }
        }
    }

    // MARK: - 内容加载

    private func loadContent() {
        if pptInfo.status == "FAILURE" {
            showCenterMessage("PPT 生成失败，请重试")
            return
        }
        guard let rawUrl = pptInfo.fileUrl, !rawUrl.isEmpty else {
            showCenterMessage("PPT 文件地址为空")
            return
        }

        let viewerUrl: String
        let lower = rawUrl.lowercased()
        if lower.hasSuffix(".pptx") || lower.hasSuffix(".ppt") {
            let encoded = rawUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawUrl
            viewerUrl = "https://view.officeapps.live.com/op/embed.aspx?src=\(encoded)"
        } else {
            viewerUrl = rawUrl
        }

        guard let url = URL(string: viewerUrl) else {
            showCenterMessage("无效的 PPT 文件地址")
            return
        }
        print("📄 PPTPreview 加载：\(viewerUrl)")
        webView.load(URLRequest(url: url))
    }

    // MARK: - 下载（共用）

    /// 下载文件到 Documents 目录，完成后回调本地 URL
    private func downloadFile(
        indicator: UIActivityIndicatorView,
        activeBtn: UIButton,
        completion: @escaping (URL) -> Void
    ) {
        guard let rawUrl = pptInfo.fileUrl, !rawUrl.isEmpty,
              let url = URL(string: rawUrl) else { return }
        guard downloadTask == nil else { return }  // 已在下载中忽略

        setButtonsEnabled(false)
        activeBtn.setTitle("", for: .normal)
        indicator.startAnimating()

        downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] tempUrl, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.downloadTask = nil
                indicator.stopAnimating()
                self.setButtonsEnabled(true)
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
            // 用 PPT 标题作为文件名，去除文件系统非法字符
            let rawName = self.pptInfo.subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let safeName = rawName.isEmpty ? "presentation" :
                rawName.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined(separator: "_")
            let fileName = safeName + ".pptx"
            let destUrl  = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: destUrl)
            try? FileManager.default.moveItem(at: tempUrl, to: destUrl)
            DispatchQueue.main.async { completion(destUrl) }
        }
        downloadTask?.resume()
    }

    private func setButtonsEnabled(_ enabled: Bool) {
        saveBtn.isEnabled           = enabled
        shareBtn.isEnabled          = enabled
        changeTemplateBtn.isEnabled = enabled
        if enabled {
            saveBtn.setTitle("保存到本地", for: .normal)
            shareBtn.setTitle("分享", for: .normal)
        }
    }

    // MARK: - 辅助

    private func showCenterMessage(_ text: String) {
        let label = UILabel()
        label.text          = text
        label.textColor     = .appTextSecondary
        label.font          = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func changeTemplateTapped() {
        let selector = TemplateSelectorViewController(
            taskId:   pptInfo.taskId ?? "",
            markdown: "")
        selector.onTemplateSelected = { [weak self] templateId in
            self?.applyTemplate(templateId)
        }
        let nav = UINavigationController(rootViewController: selector)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    /// 调用 templates-update，成功后重新 load PPT 刷新 WebView
    private func applyTemplate(_ templateId: String) {
        let pptId = pptInfo.pptId
        guard !pptId.isEmpty else { return }

        setButtonsEnabled(false)
        showLoadingOverlay(message: "更换模板中…")

        PPTAPIService.shared.updateTemplate(pptId: pptId, templateId: templateId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.hideLoadingOverlay()
                self.setButtonsEnabled(true)
                let alert = UIAlertController(title: "换模板失败",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                self.present(alert, animated: true)

            case .success:
                // 重新加载 PPT 详情获取新 fileUrl
                PPTAPIService.shared.loadPPT(pptId: pptId) { [weak self] result in
                    guard let self else { return }
                    self.hideLoadingOverlay()
                    self.setButtonsEnabled(true)
                    if case .success(let newInfo) = result {
                        self.pptInfo = newInfo
                        self.title   = newInfo.subject ?? "PPT 预览"
                        self.loadContent()
                    }
                }
            }
        }
    }

    // MARK: - PPTX 缩略图注入

    /// 将封面图写入 PPTX ZIP（docProps/thumbnail.jpeg + _rels/.rels + [Content_Types].xml）
    /// 同时通过 URLResourceValues 写入文件级 thumbnail metadata，失败时回退原文件
    private func injectThumbnail(into pptxURL: URL, completion: @escaping (URL) -> Void) {
        guard let coverStr = pptInfo.coverUrl,
              let coverURL = URL(string: coverStr) else {
            completion(pptxURL)
            return
        }

        URLSession.shared.dataTask(with: coverURL) { [weak self] data, _, error in
            guard let self else { return }
            guard error == nil, let data,
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.85) else {
                DispatchQueue.main.async { completion(pptxURL) }
                return
            }

            let rawName = (self.pptInfo.subject ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let safeName = rawName.isEmpty ? "presentation" :
                rawName.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
                       .joined(separator: "_")
            let tmpThumb = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpeg")
            let tmpPPTX  = FileManager.default.temporaryDirectory
                .appendingPathComponent(safeName + ".pptx")

            do {
                try jpegData.write(to: tmpThumb)
                try? FileManager.default.removeItem(at: tmpPPTX)
                try FileManager.default.copyItem(at: pptxURL, to: tmpPPTX)

                guard let archive = Archive(url: tmpPPTX, accessMode: .update) else {
                    print("❌ [Thumbnail] Archive 打开失败，跳过 ZIP 注入")
                    try? FileManager.default.removeItem(at: tmpThumb)
                    try? FileManager.default.removeItem(at: tmpPPTX)
                    DispatchQueue.main.async { completion(pptxURL) }
                    return
                }

                // 1. 移除旧缩略图文件
                for name in ["docProps/thumbnail.jpeg", "docProps/thumbnail.jpg",
                             "docProps/thumbnail.png"] {
                    if let e = archive[name] { try archive.remove(e) }
                }
                // 2. 写入新封面图
                try archive.addEntry(with: "docProps/thumbnail.jpeg", fileURL: tmpThumb)
                try? FileManager.default.removeItem(at: tmpThumb)

                // 3. 更新 _rels/.rels：始终移除旧 thumbnail 关系并写入新的
                let thumbRel = "<Relationship Id=\"rIdThumb\" " +
                    "Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail\" " +
                    "Target=\"docProps/thumbnail.jpeg\"/>"
                if let relsEntry = archive["_rels/.rels"] {
                    var d = Data()
                    _ = try archive.extract(relsEntry) { d.append($0) }
                    if var s = String(data: d, encoding: .utf8) {
                        // 移除所有已有 thumbnail 行（无论指向哪个路径）
                        let lines = s.components(separatedBy: "\n")
                        s = lines.filter { !$0.contains("metadata/thumbnail") }
                                 .joined(separator: "\n")
                        s = s.replacingOccurrences(of: "</Relationships>",
                                                   with: "  \(thumbRel)\n</Relationships>")
                        if let updated = s.data(using: .utf8) {
                            let tmp = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString + ".rels")
                            try updated.write(to: tmp)
                            try archive.remove(relsEntry)
                            try archive.addEntry(with: "_rels/.rels", fileURL: tmp)
                            try? FileManager.default.removeItem(at: tmp)
                        }
                    }
                } else {
                    // _rels/.rels 不存在，从零创建
                    let content = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
                        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
                        "  \(thumbRel)\n</Relationships>"
                    if let d = content.data(using: .utf8) {
                        let tmp = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".rels")
                        try d.write(to: tmp)
                        try archive.addEntry(with: "_rels/.rels", fileURL: tmp)
                        try? FileManager.default.removeItem(at: tmp)
                    }
                }

                // 4. 更新 [Content_Types].xml，注册 jpeg MIME
                if let ctEntry = archive["[Content_Types].xml"] {
                    var d = Data()
                    _ = try archive.extract(ctEntry) { d.append($0) }
                    if var s = String(data: d, encoding: .utf8),
                       !s.contains("Extension=\"jpeg\"") && !s.contains("Extension=\"jpg\"") {
                        s = s.replacingOccurrences(
                            of: "</Types>",
                            with: "  <Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/>\n</Types>")
                        if let updated = s.data(using: .utf8) {
                            let tmp = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString + ".xml")
                            try updated.write(to: tmp)
                            try archive.remove(ctEntry)
                            try archive.addEntry(with: "[Content_Types].xml", fileURL: tmp)
                            try? FileManager.default.removeItem(at: tmp)
                        }
                    }
                }

                // 5. 通过文件级 URLResourceValues 写入缩略图（document picker 会读取此 metadata）
                if let thumbImage = UIImage(data: jpegData) {
                    var resValues = URLResourceValues()
                    resValues.thumbnailDictionaryKey = [.NSThumbnail1024x1024SizeKey: thumbImage]
                    try? tmpPPTX.setResourceValues(resValues)
                }

                DispatchQueue.main.async { completion(tmpPPTX) }

            } catch {
                print("❌ [Thumbnail] 注入异常: \(error)")
                try? FileManager.default.removeItem(at: tmpThumb)
                try? FileManager.default.removeItem(at: tmpPPTX)
                DispatchQueue.main.async { completion(pptxURL) }
            }
        }.resume()
    }

    // MARK: - 加载遮罩

    private func showLoadingOverlay(message: String) {
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)

        let card = UIView()
        card.backgroundColor    = .appCardBackground
        card.layer.cornerRadius = 18
        card.layer.shadowColor  = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowRadius  = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(card)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .appPrimary
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(spinner)

        let label = UILabel()
        label.text      = message
        label.font      = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .appTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            card.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 160),

            spinner.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            spinner.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            label.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])

        overlay.alpha = 0
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
        loadingOverlay = overlay
    }

    private func hideLoadingOverlay() {
        guard let overlay = loadingOverlay else { return }
        UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 },
                       completion: { _ in overlay.removeFromSuperview() })
        loadingOverlay = nil
    }

    /// 保存到本地：下载 → 注入封面缩略图 → UIDocumentPickerViewController
    @objc private func saveTapped() {
        downloadFile(indicator: saveIndicator, activeBtn: saveBtn) { [weak self] destUrl in
            guard let self else { return }
            self.injectThumbnail(into: destUrl) { finalUrl in
                let picker = UIDocumentPickerViewController(forExporting: [finalUrl], asCopy: true)
                picker.delegate = self
                picker.modalPresentationStyle = .formSheet
                self.present(picker, animated: true)
            }
        }
    }

    /// 分享：下载后弹出系统分享面板
    @objc private func shareTapped() {
        downloadFile(indicator: shareIndicator, activeBtn: shareBtn) { [weak self] destUrl in
            guard let self else { return }
            let vc = UIActivityViewController(activityItems: [destUrl], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = self.shareBtn
            self.present(vc, animated: true)
        }
    }
}

// MARK: - WKNavigationDelegate

extension PPTPreviewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        print("❌ PPTPreview 加载失败：\(error.localizedDescription)")
        showCenterMessage("加载失败，请检查网络\n\(error.localizedDescription)")
    }
}

// MARK: - UIDocumentPickerDelegate

extension PPTPreviewViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // 用户点击"保存"完成后弹出提示
        let alert = UIAlertController(
            title: "已保存到文件 App",
            message: "你可以在「文件」App 中找到「\(pptInfo.subject ?? "PPT")」。",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
}
