//
//  StartupViewController.swift
//  Slidesh
//
//  启动配置控制器：等待网络权限 + 从服务器拉取 baseURL 配置，完成后跳转主界面
//

import UIKit
import Network
import Alamofire

class StartupViewController: UIViewController {

    // MARK: - 常量

    private let hasLaunchedKey = "slidesh.hasLaunchedBefore"

    // MARK: - UI

    /// 加载中视图（logo + spinner）
    private let loadingView = UIView()
    private let logoImageView = UIImageView()
    private let appNameLabel  = UILabel()
    private let spinner       = UIActivityIndicatorView(style: .large)

    /// 无网络错误卡片
    private let errorCard         = UIView()
    private let errorIconView     = UIView()
    private let errorTitleLabel   = UILabel()
    private let errorDescLabel    = UILabel()
    private let retryButton       = UIButton(type: .system)
    private let settingsButton    = UIButton(type: .system)

    // MARK: - 状态

    private var networkMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.slidesh.startup.monitor", qos: .utility)
    private var isFirstLaunch = false
    private var isConfigured  = false

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupLoadingView()
        setupErrorCard()
        showLoading()

        checkFirstLaunch()

        if isFirstLaunch {
            // 首次启动：用 NWPathMonitor 触发网络权限弹窗，并等待连接
            startNetworkMonitoring()
        } else {
            // 非首次启动：直接拉取配置，失败则使用兜底继续
            fetchConfig()
        }
    }

    deinit {
        networkMonitor?.cancel()
    }

    // MARK: - 首次启动检测

    private func checkFirstLaunch() {
        let launched = UserDefaults.standard.bool(forKey: hasLaunchedKey)
        isFirstLaunch = !launched
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: - 网络监听（首次启动）

    private func startNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self, !self.isConfigured else { return }
                if path.status == .satisfied {
                    self.hideError()
                    self.fetchConfig()
                } else {
                    self.showError()
                }
            }
        }
        networkMonitor?.start(queue: monitorQueue)
    }

    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    // MARK: - 配置拉取

    private func fetchConfig() {
        guard !isConfigured else { return }
        showLoading()

        let uuid = AppDelegate.getCurrentUserId() ?? "temp"
        let params: [String: Any] = [
            "appId": AppConfig.appId,
            "uuid":  uuid
        ]

        // RSA 加密请求参数
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params),
              let jsonStr  = String(data: jsonData, encoding: .utf8),
              let rsaStr   = RSAHelper.encryptString(jsonStr, publicKey: AppConfig.configPublicKey) else {
            useFallbackAndProceed()
            return
        }

        // Alamofire 自动处理百分比编码
        AF.request(AppConfig.configServerURL,
                   method: .post,
                   parameters: ["plainText": rsaStr],
                   encoding: URLEncoding.default)
            .validate()
            .responseData { [weak self] response in
                guard let self else { return }
                switch response.result {
                case .success(let data):
                    let value = try? JSONSerialization.jsonObject(with: data)
                    self.handleResponse(value)
                case .failure:
                    self.useFallbackAndProceed()
                }
            }
    }

    private func handleResponse(_ value: Any?) {
        guard let json      = value as? [String: Any],
              let code      = json["code"] as? Int, code == 200,
              let encrypted = json["newslist"] as? String else {
            useFallbackAndProceed()
            return
        }

        let decoded = encrypted.removingPercentEncoding ?? encrypted
        guard let decrypted = RSAHelper.decryptString(decoded, publicKey: AppConfig.configPublicKey),
              let listData  = decrypted.data(using: .utf8),
              let hostList  = try? JSONSerialization.jsonObject(with: listData) as? [[String: Any]] else {
            useFallbackAndProceed()
            return
        }

        saveURLs(from: hostList)
        proceed()
    }

    /// 解析 host 列表并保存到 AppConfig（ipOrPort 1=ppt服务, 2=convert服务）
    private func saveURLs(from hostList: [[String: Any]]) {
        var pptBase:     String?
        var convertBase: String?

        for item in hostList {
            guard let type = item["ipOrPort"] as? Int,
                  let host = item["host"]    as? String else { continue }
            let prefix  = host.hasPrefix("http") ? host : "http://\(host)"
            let portStr = item["port"] as? String ?? ""
            let full    = portStr.isEmpty ? prefix : "\(prefix):\(portStr)"

            switch type {
            case 1: pptBase     = full
            case 2: convertBase = full
            default: break
            }
        }

        AppConfig.save(pptBase: pptBase, convertBase: convertBase)
    }

    private func useFallbackAndProceed() {
        // 拉取失败：保留上次已保存的地址（或兜底值），直接继续
        proceed()
    }

    private func proceed() {
        isConfigured = true
        stopNetworkMonitoring()
        navigateToMain()
    }

    // MARK: - 导航

    private func navigateToMain() {
        guard let window = view.window else { return }
        let main = CustomTabBarController()
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
            window.rootViewController = main
        })
    }

    // MARK: - 按钮事件

    @objc private func retryTapped() {
        showLoading()
        fetchConfig()
    }

    @objc private func settingsTapped() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - UI 状态切换

    private func showLoading() {
        spinner.startAnimating()
        UIView.animate(withDuration: 0.25) {
            self.loadingView.alpha = 1
            self.errorCard.alpha   = 0
        }
    }

    private func showError() {
        spinner.stopAnimating()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.loadingView.alpha = 0
            self.errorCard.alpha   = 1
            self.errorCard.transform = .identity
        }
    }

    private func hideError() {
        UIView.animate(withDuration: 0.2) {
            self.errorCard.alpha = 0
        }
    }

    // MARK: - UI 搭建

    private func setupBackground() {
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()
    }

    private func setupLoadingView() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.alpha = 0
        view.addSubview(loadingView)

        // App 图标（SF Symbol）
        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .regular)
        logoImageView.image = UIImage(systemName: "sparkles.rectangle.stack", withConfiguration: config)
        logoImageView.tintColor = .appGradientMid
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(logoImageView)

        // App 名称
        appNameLabel.text = "Slidesh"
        appNameLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        appNameLabel.textColor = .appTextPrimary
        appNameLabel.textAlignment = .center
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(appNameLabel)

        // 加载指示器
        spinner.color = .appTextSecondary
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(spinner)

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            logoImageView.topAnchor.constraint(equalTo: loadingView.topAnchor),
            logoImageView.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 72),
            logoImageView.heightAnchor.constraint(equalToConstant: 72),

            appNameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),
            appNameLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),

            spinner.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 24),
            spinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: loadingView.bottomAnchor),
        ])
    }

    private func setupErrorCard() {
        errorCard.backgroundColor = .appCardBackground
        errorCard.layer.cornerRadius = 24
        errorCard.layer.shadowColor   = UIColor.black.cgColor
        errorCard.layer.shadowOpacity = 0.15
        errorCard.layer.shadowOffset  = CGSize(width: 0, height: 4)
        errorCard.layer.shadowRadius  = 12
        errorCard.alpha = 0
        errorCard.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        errorCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorCard)

        // 图标容器
        errorIconView.backgroundColor = UIColor.appGradientMid.withAlphaComponent(0.12)
        errorIconView.layer.cornerRadius = 30
        errorIconView.translatesAutoresizingMaskIntoConstraints = false
        errorCard.addSubview(errorIconView)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let iconImageView = UIImageView(image: UIImage(systemName: "wifi.slash", withConfiguration: iconConfig))
        iconImageView.tintColor = .appGradientMid
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        errorIconView.addSubview(iconImageView)

        // 标题
        errorTitleLabel.text = "无法连接网络"
        errorTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        errorTitleLabel.textColor = .appTextPrimary
        errorTitleLabel.textAlignment = .center
        errorTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        errorCard.addSubview(errorTitleLabel)

        // 描述
        errorDescLabel.text = "请检查网络连接后重试"
        errorDescLabel.font = .systemFont(ofSize: 14)
        errorDescLabel.textColor = .appTextSecondary
        errorDescLabel.textAlignment = .center
        errorDescLabel.numberOfLines = 0
        errorDescLabel.translatesAutoresizingMaskIntoConstraints = false
        errorCard.addSubview(errorDescLabel)

        // 重试按钮（渐变背景）
        retryButton.setTitle("重试", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.layer.cornerRadius = 22
        retryButton.clipsToBounds = true
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        errorCard.addSubview(retryButton)
        addGradientToRetryButton()

        // 网络设置按钮
        settingsButton.setTitle("前往网络设置", for: .normal)
        settingsButton.titleLabel?.font = .systemFont(ofSize: 13)
        settingsButton.setTitleColor(.appTextSecondary, for: .normal)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        errorCard.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            errorCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorCard.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            errorIconView.topAnchor.constraint(equalTo: errorCard.topAnchor, constant: 36),
            errorIconView.centerXAnchor.constraint(equalTo: errorCard.centerXAnchor),
            errorIconView.widthAnchor.constraint(equalToConstant: 60),
            errorIconView.heightAnchor.constraint(equalToConstant: 60),

            iconImageView.centerXAnchor.constraint(equalTo: errorIconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: errorIconView.centerYAnchor),

            errorTitleLabel.topAnchor.constraint(equalTo: errorIconView.bottomAnchor, constant: 20),
            errorTitleLabel.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 20),
            errorTitleLabel.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -20),

            errorDescLabel.topAnchor.constraint(equalTo: errorTitleLabel.bottomAnchor, constant: 8),
            errorDescLabel.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 20),
            errorDescLabel.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -20),

            retryButton.topAnchor.constraint(equalTo: errorDescLabel.bottomAnchor, constant: 28),
            retryButton.centerXAnchor.constraint(equalTo: errorCard.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 180),
            retryButton.heightAnchor.constraint(equalToConstant: 44),

            settingsButton.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 12),
            settingsButton.centerXAnchor.constraint(equalTo: errorCard.centerXAnchor),
            settingsButton.bottomAnchor.constraint(equalTo: errorCard.bottomAnchor, constant: -28),
        ])
    }

    private func addGradientToRetryButton() {
        let gradient = CAGradientLayer()
        gradient.colors    = [UIColor.appGradientStart.cgColor,
                              UIColor.appGradientMid.cgColor,
                              UIColor.appGradientEnd.cgColor]
        gradient.locations = [0.0, 0.55, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint   = CGPoint(x: 1, y: 1)
        retryButton.layer.insertSublayer(gradient, at: 0)
        // frame 在 layoutSubviews 时更新
        retryButton.layoutIfNeeded()
        gradient.frame = retryButton.bounds
    }
}
