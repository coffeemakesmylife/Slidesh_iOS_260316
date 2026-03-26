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

    /// 加载中视图（仅 spinner）
    private let loadingView = UIView()
    private let spinner     = UIActivityIndicatorView(style: .large)

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
            // 首次启动：用 NWPathMonitor 触发网络权限弹窗，联网后拉取配置
            startNetworkMonitoring()
        } else {
            // 非首次启动：直接请求 host 配置，loading 等结果后跳转
            fetchHostConfiguration()
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
                    self.fetchHostConfiguration()
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

    // MARK: - 服务器配置获取

    /// 首次启动阻塞式拉取 host/list（含 code 参数）
    private func fetchHostConfiguration() {
        guard !isConfigured else { return }
        showLoading()

        guard let uuid = AppDelegate.getCurrentUserId() else {
            print("❌ 无法获取用户ID")
            normalHost()
            return
        }

        let parameters: [String: Any] = [
            "code":  "19436650565",
            "appId": AppConfig.appId,
            "uuid":  uuid
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters),
              let jsonStr  = String(data: jsonData, encoding: .utf8),
              let rsaStr   = RSAHelper.encryptString(jsonStr, publicKey: AppConfig.configPublicKey) else {
            print("❌ RSA 加密失败")
            normalHost()
            return
        }

        AF.request(AppConfig.configServerURL,
                   method: .post,
                   parameters: ["plainText": rsaStr],
                   encoding: URLEncoding.default)
            .validate()
            .responseJSON { [weak self] response in
                guard let self else { return }
                switch response.result {
                case .success(let value):
                    guard let dict      = value as? [String: Any],
                          let code      = dict["code"] as? Int, code == 200,
                          let rsaStr    = dict["newslist"] as? String,
                          let decoded   = rsaStr.removingPercentEncoding,
                          let decrypted = RSAHelper.decryptString(decoded, publicKey: AppConfig.configPublicKey),
                          let listData  = decrypted.data(using: .utf8),
                          let hostList  = try? JSONSerialization.jsonObject(with: listData) as? [[String: Any]] else {
                        print("❌ 服务器响应解析失败")
                        self.normalHost()
                        return
                    }
                    print("✅ 成功获取服务器配置列表")
                    self.processHostList(hostList)
                case .failure(let error):
                    print("❌ 网络请求失败: \(error)")
                    self.normalHost()
                }
            }
    }

    /// 解析 host 列表：保存 URL，触发应用配置请求，决定跳转时机
    /// ipOrPort: 1=配置/通知/反馈 2=格式转换 3=PPT生成
    private func processHostList(_ hostList: [[String: Any]]) {
        var configBase:  String?
        var convertBase: String?
        var pptBase:     String?

        for item in hostList {
            guard let ipOrPort = item["ipOrPort"] as? Int,
                  let host     = item["host"]     as? String else { continue }

            let prefix = host.hasPrefix("http") ? host : "http://\(host)"
            let port   = item["port"] as? String ?? ""
            let full   = port.isEmpty ? prefix : "\(prefix):\(port)"

            switch ipOrPort {
            case 1: configBase  = full; print("✅ 获取 configBaseURL: \(full)")
            case 2: convertBase = full; print("✅ 获取 convertBaseURL: \(full)")
            case 3: pptBase     = full; print("✅ 获取 pptBaseURL: \(full)")
            default: break
            }
        }

        AppConfig.save(configBase: configBase, convertBase: convertBase, pptBase: pptBase)

        // fetchAllConfigs 存配置开关，fire-and-forget 不阻塞跳转
        let base = configBase ?? AppConfig.fallbackConfigBaseURL
        fetchAllConfigs(base)

        if isFirstLaunch {
            // 首次启动：等引导开关结果再跳转
            print("📱 首次启动 - 请求引导开关配置")
            fetchSubscriptionGuideConfig(base)
        } else {
            proceed()
        }
    }

    /// 拉取所有应用开关配置（每次启动都调用）
    private func fetchAllConfigs(_ baseUrl: String) {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            .replacingOccurrences(of: ".", with: "")
        let parameters: [String: Any] = ["appId": AppConfig.appId, "version": version]

        print("📤 请求应用配置: \(baseUrl)/v1/api/ai/chat/notice/new")

        AF.request("\(baseUrl)/v1/api/ai/chat/notice/new",
                   method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { [weak self] response in
                guard let self else { return }
                switch response.result {
                case .success(let value):
                    guard let dict     = value as? [String: Any],
                          let code     = dict["code"] as? Int, code == 200,
                          let newslist = dict["newslist"] as? [[String: Any]] else {
                        self.setDefaultConfigs(); return
                    }
                    self.processAllConfigs(newslist)
                case .failure:
                    self.setDefaultConfigs()
                }
            }
    }

    /// 解析并保存各 type 开关值
    private func processAllConfigs(_ newslist: [[String: Any]]) {
        for item in newslist {
            guard let type  = item["type"]  as? Int,
                  let title = item["title"] as? String else { continue }
            switch type {
            case 4: UserDefaults.standard.set(title == "1", forKey: "enable_rating_trial_restore")
            case 5: UserDefaults.standard.set(title == "1", forKey: "enable_rating_reward_prompt")
            case 6: UserDefaults.standard.set(title == "1", forKey: "enable_star_or_comment")
            case 7: UserDefaults.standard.set(Int(title) ?? 0,  forKey: "free_trial_count")
            case 8: UserDefaults.standard.set(Int(title) ?? 10, forKey: "vip_daily_limit")
            case 9: UserDefaults.standard.set(Int(title) ?? 0,  forKey: "guided_subscription_plan")
            default: break
            }
        }
        UserDefaults.standard.synchronize()
        print("✅ 应用配置已保存")
    }

    /// 应用配置请求失败时设置保守默认值
    private func setDefaultConfigs() {
        let defaults: [String: Any] = [
            "enable_rating_trial_restore": false,
            "enable_rating_reward_prompt": false,
            "enable_star_or_comment":      false,
            "free_trial_count":            0,
            "vip_daily_limit":             10,
            "guided_subscription_plan":    0,
        ]
        defaults.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
        UserDefaults.standard.synchronize()
        print("⚠️ 已设置默认配置值")
    }

    /// 首次启动：请求引导开关（type=3），决定后续路由
    private func fetchSubscriptionGuideConfig(_ baseUrl: String) {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            .replacingOccurrences(of: ".", with: "")
        let parameters: [String: Any] = ["appId": AppConfig.appId, "type": 3, "version": version]

        print("📤 请求引导开关配置")

        AF.request("\(baseUrl)/v1/api/ai/chat/notice",
                   method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate()
            .responseJSON { [weak self] response in
                guard let self else { return }
                switch response.result {
                case .success(let value):
                    guard let dict     = value as? [String: Any],
                          let code     = dict["code"] as? Int, code == 200,
                          let newslist = dict["newslist"] as? [String: Any],
                          let title    = newslist["title"] as? String else {
                        print("❌ 引导开关解析失败，默认继续")
                        self.proceed()
                        return
                    }
                    print("✅ 引导开关: \(title)")
                    // title == "1" 表示展示引导页
                    if title == "1" {
                        self.navigateToOnboarding()
                    } else {
                        self.proceed()
                    }
                case .failure(let error):
                    print("❌ 引导开关请求失败: \(error)，默认继续")
                    self.proceed()
                }
            }
    }

    /// 配置拉取失败兜底：使用已缓存或默认地址，继续启动
    private func normalHost() {
        print("⚠️ 使用兜底服务器配置")
        setDefaultConfigs()
        proceed()
    }

    private func proceed() {
        isConfigured = true
        stopNetworkMonitoring()

        // 首次使用前展示数据处理同意弹窗
        if DataConsentManager.shared.hasConsented {
            navigateToMain()
        } else {
            showConsentView()
        }
    }

    private func showConsentView() {
        let consent = DataConsentView(parentVC: self)
        consent.onConsent  = { [weak self] in self?.navigateToMain() }
        consent.onDecline  = { /* 用户拒绝：留在启动页，功能不可用 */ }
        consent.showInView(view)
    }

    // MARK: - 导航

    private func navigateToMain() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.view.window else { return }
            let main = CustomTabBarController()
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
                window.rootViewController = main
            })
        }
    }

    private func navigateToOnboarding() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.view.window else { return }
            let onboarding = OnboardingViewController()
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
                window.rootViewController = onboarding
            })
        }
    }

    // MARK: - 按钮事件

    @objc private func retryTapped() {
        showLoading()
        fetchHostConfiguration()
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

        // 仅显示加载指示器
        spinner.color = .appTextSecondary
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(spinner)

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            spinner.topAnchor.constraint(equalTo: loadingView.topAnchor),
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
