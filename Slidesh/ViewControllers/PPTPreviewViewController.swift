//
//  PPTPreviewViewController.swift
//  Slidesh
//
//  PPT 预览页：WKWebView 加载 fileUrl，支持存到文件 / 分享
//

import UIKit
import WebKit

class PPTPreviewViewController: UIViewController {

    private let pptInfo: PPTInfo

    // MARK: - 子视图

    private var webView: WKWebView!
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?

    private let bottomBar    = UIView()
    private let saveBtn      = UIButton(type: .custom)   // 存到文件
    private let shareBtn     = UIButton(type: .custom)   // 分享
    private var saveBtnGrad:  CAGradientLayer?
    private var shareBtnGrad: CAGradientLayer?

    // 下载任务（存到文件 / 分享共用）
    private var downloadTask: URLSessionDownloadTask?
    private let saveIndicator  = UIActivityIndicatorView(style: .medium)
    private let shareIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Init

    init(pptInfo: PPTInfo) {
        self.pptInfo = pptInfo
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

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .appBackgroundPrimary
        appearance.titleTextAttributes = [.foregroundColor: UIColor.appTextPrimary]
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
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

        // 公共样式
        for btn in [saveBtn, shareBtn] {
            btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 26
            btn.clipsToBounds = true
            btn.translatesAutoresizingMaskIntoConstraints = false
            bottomBar.addSubview(btn)
        }

        saveBtn.setTitle("存到文件", for: .normal)
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        shareBtn.setTitle("分享", for: .normal)
        shareBtn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            saveBtn.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            saveBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            saveBtn.heightAnchor.constraint(equalToConstant: 52),
            saveBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            shareBtn.topAnchor.constraint(equalTo: saveBtn.topAnchor),
            shareBtn.leadingAnchor.constraint(equalTo: saveBtn.trailingAnchor, constant: 12),
            shareBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            shareBtn.heightAnchor.constraint(equalTo: saveBtn.heightAnchor),
            shareBtn.widthAnchor.constraint(equalTo: saveBtn.widthAnchor),
        ])

        saveBtnGrad  = makeGradient(for: saveBtn,  alpha: 1.0)
        shareBtnGrad = makeGradient(for: shareBtn, alpha: 0.8)

        // loading 指示器
        for (indicator, btn) in [(saveIndicator, saveBtn), (shareIndicator, shareBtn)] {
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
        g.colors      = [UIColor.appPrimary.cgColor,
                         UIColor.appPrimary.withAlphaComponent(alpha * 0.75).cgColor]
        g.startPoint  = CGPoint(x: 0, y: 0.5)
        g.endPoint    = CGPoint(x: 1, y: 0.5)
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

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
            let fileName = url.lastPathComponent.isEmpty ? "presentation.pptx" : url.lastPathComponent
            let destUrl  = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: destUrl)
            try? FileManager.default.moveItem(at: tempUrl, to: destUrl)
            DispatchQueue.main.async { completion(destUrl) }
        }
        downloadTask?.resume()
    }

    private func setButtonsEnabled(_ enabled: Bool) {
        saveBtn.isEnabled  = enabled
        shareBtn.isEnabled = enabled
        if enabled {
            saveBtn.setTitle("存到文件", for: .normal)
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

    /// 存到文件：下载后用 UIDocumentPickerViewController 直接打开文件 App
    @objc private func saveTapped() {
        downloadFile(indicator: saveIndicator, activeBtn: saveBtn) { [weak self] destUrl in
            guard let self else { return }
            let picker = UIDocumentPickerViewController(forExporting: [destUrl], asCopy: true)
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
        showCenterMessage("加载失败，请检查网络\n\(error.localizedDescription)")
    }
}
