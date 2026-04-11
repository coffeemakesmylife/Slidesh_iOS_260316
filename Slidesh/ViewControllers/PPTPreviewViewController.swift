//
//  PPTPreviewViewController.swift
//  Slidesh
//
//  PPT 预览页：WKWebView 加载 fileUrl，支持保存到本地 / 分享
//

import UIKit
import WebKit

/// PPT 预览来源，用于区分评分触发时机
enum PPTPreviewSource {
    case templateFlow   // 从模板流（TemplateSelectorViewController）进入 → T2
    case myWorks        // 从我的作品进入 → T7
    case other          // 其他来源，不触发评分
}

class PPTPreviewViewController: UIViewController {

    private var pptInfo: PPTInfo
    private let canChangeTemplate: Bool
    private let source: PPTPreviewSource

    // MARK: - 子视图

    private var webView: WKWebView!
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?

    private let bottomBar         = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let blurFadeMask      = CAGradientLayer()         // 顶部渐入遮罩
    private let saveBtn           = UIButton(type: .custom)   // 保存到本地
    private let shareBtn          = UIButton(type: .custom)   // 分享（非换模板场景）
    private let changeTemplateBtn = UIButton(type: .custom)   // 换模板（换模板场景）
    private var shareBtnContainer: UIView?
    private var shareBtnGrad:      CAGradientLayer?

    // 下载任务（保存到本地 / 分享共用）
    private var downloadTask: URLSessionDownloadTask?
    private let saveIndicator  = UIActivityIndicatorView(style: .medium)
    private let shareIndicator = UIActivityIndicatorView(style: .medium)

    // 换模板加载遮罩
    private var loadingOverlay: UIView?

    // MARK: - Init

    init(pptInfo: PPTInfo, canChangeTemplate: Bool = false, source: PPTPreviewSource = .other) {
        self.pptInfo = pptInfo
        self.canChangeTemplate = canChangeTemplate
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackgroundPrimary
        setupNavBar()
        setupWebView()
        setupBottomBar()
        setupProgressBar()
        loadContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 根据来源触发评分
        switch source {
        case .templateFlow: RatingManager.shared.trigger(from: .pptPreviewFromTemplate)
        case .myWorks:      RatingManager.shared.trigger(from: .pptPreviewFromMyWorks)
        case .other:        break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shareBtnGrad?.frame = shareBtnContainer?.bounds ?? .zero
        updateBlurFadeMask()
        changeTemplateBtn.layer.borderColor = UIColor.appPrimary.withAlphaComponent(0.3).cgColor
    }

    // MARK: - 导航栏

    private func setupNavBar() {
        title = pptInfo.subject ?? NSLocalizedString("PPT 预览", comment: "")

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
        // 毛玻璃底部栏，叠在 webView 上方
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        // 顶部渐入遮罩：从透明到不透明，滚动时内容自然模糊消失
        blurFadeMask.colors     = [UIColor.clear.cgColor, UIColor.black.cgColor]
        blurFadeMask.startPoint = CGPoint(x: 0.5, y: 0)
        blurFadeMask.endPoint   = CGPoint(x: 0.5, y: 1)
        bottomBar.layer.mask    = blurFadeMask

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 保存到本地按钮（主题色背景）
        saveBtn.setTitle(NSLocalizedString("保存到本地", comment: ""), for: .normal)
        saveBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.backgroundColor = .appPrimary
        saveBtn.layer.cornerRadius = 26
        saveBtn.clipsToBounds = true
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        bottomBar.contentView.addSubview(saveBtn)

        // 左侧：换模板场景用 changeTemplateBtn（无渐变），否则用 shareBtn 容器
        let leftView: UIView
        if canChangeTemplate {
            changeTemplateBtn.setTitle(NSLocalizedString("换模板", comment: ""), for: .normal)
            changeTemplateBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            changeTemplateBtn.setTitleColor(.appPrimary, for: .normal)
            changeTemplateBtn.backgroundColor = .appCardBackground
            changeTemplateBtn.layer.cornerRadius = 26
            changeTemplateBtn.layer.borderWidth = 1.5
            changeTemplateBtn.layer.borderColor = UIColor.appPrimary.withAlphaComponent(0.3).cgColor
            changeTemplateBtn.clipsToBounds = true
            changeTemplateBtn.translatesAutoresizingMaskIntoConstraints = false
            changeTemplateBtn.addTarget(self, action: #selector(changeTemplateTapped), for: .touchUpInside)
            bottomBar.contentView.addSubview(changeTemplateBtn)
            leftView = changeTemplateBtn
        } else {
            let shareContainer = makeGradientContainer(alpha: 0.8, grad: &shareBtnGrad)
            shareBtnContainer = shareContainer
            bottomBar.contentView.addSubview(shareContainer)
            shareBtn.setTitle(NSLocalizedString("分享", comment: ""), for: .normal)
            shareBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            shareBtn.setTitleColor(.white, for: .normal)
            shareBtn.translatesAutoresizingMaskIntoConstraints = false
            shareBtn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
            shareContainer.addSubview(shareBtn)
            leftView = shareContainer
        }

        NSLayoutConstraint.activate([
            leftView.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 48),
            leftView.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            leftView.heightAnchor.constraint(equalToConstant: 52),
            leftView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            saveBtn.topAnchor.constraint(equalTo: leftView.topAnchor),
            saveBtn.leadingAnchor.constraint(equalTo: leftView.trailingAnchor, constant: 12),
            saveBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            saveBtn.heightAnchor.constraint(equalTo: leftView.heightAnchor),
            saveBtn.widthAnchor.constraint(equalTo: leftView.widthAnchor),
        ])
        if let sc = shareBtnContainer {
            NSLayoutConstraint.activate([
                shareBtn.topAnchor.constraint(equalTo: sc.topAnchor),
                shareBtn.bottomAnchor.constraint(equalTo: sc.bottomAnchor),
                shareBtn.leadingAnchor.constraint(equalTo: sc.leadingAnchor),
                shareBtn.trailingAnchor.constraint(equalTo: sc.trailingAnchor),
            ])
        }

        // loading 指示器居中在各自容器上
        let indicatorPairs: [(UIActivityIndicatorView, UIView)] = canChangeTemplate
            ? [(saveIndicator, saveBtn)]
            : [(saveIndicator, saveBtn), (shareIndicator, shareBtnContainer!)]
        for (indicator, container) in indicatorPairs {
            indicator.color = .white
            indicator.hidesWhenStopped = true
            indicator.translatesAutoresizingMaskIntoConstraints = false
            bottomBar.contentView.addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
        }
    }

    private func updateBlurFadeMask() {
        guard bottomBar.bounds.height > 0 else { return }
        blurFadeMask.frame = bottomBar.bounds
        // 顶部 48pt 为渐变过渡区，之后完全不透明
        let fadeRatio = 48.0 / bottomBar.bounds.height
        blurFadeMask.locations = [0, NSNumber(value: fadeRatio)]
    }

    /// 创建渐变容器 UIView（与 NewProjectViewController 统一写法）
    private func makeGradientContainer(alpha: CGFloat, grad: inout CAGradientLayer?) -> UIView {
        let container = UIView()
        container.layer.cornerRadius = 26
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let g = CAGradientLayer()
        g.colors     = [UIColor.appGradientStart.withAlphaComponent(alpha).cgColor,
                        UIColor.appGradientMid.withAlphaComponent(alpha).cgColor,
                        UIColor.appGradientEnd.withAlphaComponent(alpha).cgColor]
        g.locations  = [0.0, 0.55, 1.0]
        g.startPoint = CGPoint(x: 0, y: 0.5)
        g.endPoint   = CGPoint(x: 1, y: 0.5)
        container.layer.insertSublayer(g, at: 0)
        grad = g
        return container
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
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
            showCenterMessage(NSLocalizedString("PPT 生成失败，请重试", comment: ""))
            return
        }
        guard let rawUrl = pptInfo.fileUrl, !rawUrl.isEmpty else {
            showCenterMessage(NSLocalizedString("PPT 文件地址为空", comment: ""))
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
            showCenterMessage(NSLocalizedString("无效的 PPT 文件地址", comment: ""))
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
                    let alert = UIAlertController(title: NSLocalizedString("下载失败", comment: ""),
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
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
            saveBtn.setTitle(NSLocalizedString("保存到本地", comment: ""), for: .normal)
            shareBtn.setTitle(NSLocalizedString("分享", comment: ""), for: .normal)
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
        showLoadingOverlay(message: NSLocalizedString("更换模板中…", comment: ""))

        PPTAPIService.shared.updateTemplate(pptId: pptId, templateId: templateId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.hideLoadingOverlay()
                self.setButtonsEnabled(true)
                let alert = UIAlertController(title: NSLocalizedString("换模板失败", comment: ""),
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
                self.present(alert, animated: true)

            case .success:
                // 重新加载 PPT 详情获取新 fileUrl
                PPTAPIService.shared.loadPPT(pptId: pptId) { [weak self] result in
                    guard let self else { return }
                    self.hideLoadingOverlay()
                    self.setButtonsEnabled(true)
                    if case .success(let newInfo) = result {
                        self.pptInfo = newInfo
                        self.title   = newInfo.subject ?? NSLocalizedString("PPT 预览", comment: "")
                        self.loadContent()
                    }
                }
            }
        }
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

    /// 保存到本地：下载后用 UIDocumentPickerViewController 直接打开文件 App
    @objc private func saveTapped() {
        downloadFile(indicator: saveIndicator, activeBtn: saveBtn) { [weak self] destUrl in
            guard let self else { return }
            let picker = UIDocumentPickerViewController(forExporting: [destUrl], asCopy: true)
            picker.delegate = self
            picker.modalPresentationStyle = .formSheet
            self.present(picker, animated: true)
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
        showCenterMessage(NSLocalizedString("加载失败，请检查网络", comment: "") + "\n\(error.localizedDescription)")
    }
}

// MARK: - UIDocumentPickerDelegate

extension PPTPreviewViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // 用户点击"保存"完成后弹出提示
        let alert = UIAlertController(
            title: NSLocalizedString("已保存到文件 App", comment: ""),
            message: NSLocalizedString("你可以在「文件」App 中找到「", comment: "") + "\(pptInfo.subject ?? "PPT")" + NSLocalizedString("」。", comment: ""),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("好的", comment: ""), style: .default))
        present(alert, animated: true)
    }
}
