//
//  PPTPreviewViewController.swift
//  Slidesh
//
//  PPT 预览页：WKWebView 加载 fileUrl，支持下载/分享
//

import UIKit
import WebKit

class PPTPreviewViewController: UIViewController {

    private let pptInfo: PPTInfo

    // MARK: - 子视图

    private var webView: WKWebView!
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?

    private let bottomBar  = UIView()
    private let shareBtn   = UIButton(type: .custom)
    private var shareGrad: CAGradientLayer?
    private var downloadTask: URLSessionDownloadTask?
    private let downloadIndicator = UIActivityIndicatorView(style: .medium)

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
        shareGrad?.frame = shareBtn.bounds
    }

    // MARK: - 导航栏

    private func setupNavBar() {
        title = pptInfo.subject ?? "PPT 预览"

        let closeBtn = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain, target: self, action: #selector(closeTapped))
        closeBtn.tintColor = .appTextPrimary
        navigationItem.leftBarButtonItem = closeBtn

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
        // 顶部细分隔线
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

        // 分享/下载按钮（同 composeBtn 风格）
        shareBtn.setTitle("下载 / 分享", for: .normal)
        shareBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        shareBtn.setTitleColor(.white, for: .normal)
        shareBtn.layer.cornerRadius = 26
        shareBtn.clipsToBounds      = true
        shareBtn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(shareBtn)

        NSLayoutConstraint.activate([
            shareBtn.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            shareBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            shareBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            shareBtn.heightAnchor.constraint(equalToConstant: 56),
            shareBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        let grad = CAGradientLayer()
        grad.colors      = [UIColor.appPrimary.cgColor,
                            UIColor.appPrimary.withAlphaComponent(0.75).cgColor]
        grad.startPoint  = CGPoint(x: 0, y: 0.5)
        grad.endPoint    = CGPoint(x: 1, y: 0.5)
        grad.cornerRadius = 26
        shareBtn.layer.insertSublayer(grad, at: 0)
        shareGrad = grad

        // 下载 loading 指示器，叠加在按钮中央
        downloadIndicator.color = .white
        downloadIndicator.hidesWhenStopped = true
        downloadIndicator.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(downloadIndicator)
        NSLayoutConstraint.activate([
            downloadIndicator.centerXAnchor.constraint(equalTo: shareBtn.centerXAnchor),
            downloadIndicator.centerYAnchor.constraint(equalTo: shareBtn.centerYAnchor),
        ])
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

    // MARK: - 加载内容

    private func loadContent() {
        // 状态检查
        if pptInfo.status == "FAILURE" {
            showCenterMessage("PPT 生成失败，请重试")
            return
        }

        guard let rawUrl = pptInfo.fileUrl, !rawUrl.isEmpty else {
            showCenterMessage("PPT 文件地址为空")
            return
        }

        // .pptx/.ppt 文件使用 Microsoft Office 在线预览
        let viewerUrl: String
        let lower = rawUrl.lowercased()
        if lower.hasSuffix(".pptx") || lower.hasSuffix(".ppt") {
            let encoded = rawUrl.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed) ?? rawUrl
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

    @objc private func closeTapped() {
        // 关闭整个模板选择流程
        dismiss(animated: true)
    }

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
            // 将临时文件移动到 Documents，保留原始文件名
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
}

// MARK: - WKNavigationDelegate

extension PPTPreviewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        print("❌ PPTPreview 加载失败：\(error.localizedDescription)")
        showCenterMessage("加载失败，请检查网络\n\(error.localizedDescription)")
    }
}
