//
//  PremiumViewController.swift
//  Slidesh
//
//  订阅与高级版界面，复现参照截图的 UI 设计
//

import UIKit
import SafariServices
import StoreKit

// MARK: - PremiumPlan Model

struct PremiumPlan: Equatable {
    let id: String
    let title: String
    let tag: String?
    let priceStr: String       // 默认兜底价格（产品加载前显示）
    let priceDouble: Double
    let subtext: String
    let disclaimer: String

    // App Store Connect 中配置的产品 ID，需与后台一致
    var productID: String {
        switch id {
        case "week":  return "com.slidesh.subscription.weekly"
        case "month": return "com.slidesh.subscription.monthly"
        case "year":  return "com.slidesh.subscription.yearly"
        default:      return ""
        }
    }

    static let allPlans: [PremiumPlan] = [
        PremiumPlan(id: "week",  title: "周订阅", tag: nil,       priceStr: "¥12.00",  priceDouble: 12.00,  subtext: "每天低至 ¥1.71", disclaimer: "每天仅¥1.7无限次使用，到期自动续期，随时可取消"),
        PremiumPlan(id: "month", title: "月订阅", tag: "限时折扣", priceStr: "¥18.00",  priceDouble: 18.00,  subtext: "每天低至 ¥0.60", disclaimer: "首月¥18，之后¥38每月包含无限次使用，随时可取消"),
        PremiumPlan(id: "year",  title: "年订阅", tag: "最受欢迎", priceStr: "¥198.00", priceDouble: 198.00, subtext: "每月低至 ¥16.50", disclaimer: "每年包含无限次使用，到期自动续期，随时可取消")
    ]
}

// MARK: - PremiumViewController

class PremiumViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 内容组件
    private let headerLabel = UILabel()
    private let subHeaderLabel = UILabel()
    private let cardsStackView = UIStackView()
    private let disclaimerLabel = UILabel()

    // 底部浮动交互条
    private let bottomBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let blurFadeMask   = CAGradientLayer()  // 顶部渐入遮罩
    private let subscribeButton = AnimatedGradientButton()
    private let autoRenewTipLabel = UILabel()

    // 存储所有卡片及当前选中状态
    private var cardViews: [PremiumPlanCardView] = []
    private var selectedPlan: PremiumPlan = PremiumPlan.allPlans[1] // 默认选中月卡

    // 购买成功回调（由 PaywallSheet 设置，购买完成后调用）
    var onPurchased: (() -> Void)?

    // StoreKit 2：已加载的产品（productID → Product）
    private var storeProducts: [String: Product] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupNavigationBar()
        setupScrollView()
        setupBottomBar()
        setupContent()

        // 初始更新选中状态
        updateSelection()

        // 异步加载 App Store 产品信息
        Task { await loadProducts() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBlurFadeMask()
    }

    private func setupBackground() {
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()
    }

    private func setupNavigationBar() {
        let config = UIImage.SymbolConfiguration(weight: .bold)
        let image = UIImage(systemName: "xmark", withConfiguration: config)
        let closeItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(closeTapped))
        closeItem.tintColor = .appTextPrimary
        navigationItem.leftBarButtonItem = closeItem

        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
    }

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func setupBottomBar() {
        bottomBlurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBlurView)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        bottomBlurView.contentView.addSubview(container)

        // 订阅大按钮
        subscribeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        subscribeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        subscribeButton.layer.borderWidth = 2.0
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.layer.cornerRadius = 30
        subscribeButton.clipsToBounds = true
        subscribeButton.addTarget(self, action: #selector(subscribeTapped), for: .touchUpInside)
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subscribeButton)

        // 自动续费附加提示
        autoRenewTipLabel.text = "确认即同意自动续费条款，随用随停"
        autoRenewTipLabel.font = .systemFont(ofSize: 12)
        autoRenewTipLabel.textColor = .appTextSecondary
        autoRenewTipLabel.textAlignment = .center
        autoRenewTipLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(autoRenewTipLabel)

        // blur view 从按钮容器顶部上方 60pt 开始，给渐入过渡留空间
        let fadeHeight: CGFloat = 60

        NSLayoutConstraint.activate([
            bottomBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBlurView.topAnchor.constraint(equalTo: container.topAnchor, constant: -fadeHeight),

            container.topAnchor.constraint(equalTo: bottomBlurView.topAnchor, constant: fadeHeight),
            container.leadingAnchor.constraint(equalTo: bottomBlurView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: bottomBlurView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            subscribeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            subscribeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            subscribeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            subscribeButton.heightAnchor.constraint(equalToConstant: 60),

            autoRenewTipLabel.topAnchor.constraint(equalTo: subscribeButton.bottomAnchor, constant: 12),
            autoRenewTipLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            autoRenewTipLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            autoRenewTipLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        // 顶部渐入遮罩：从透明到不透明，让内容滑入时有模糊渐变过渡
        blurFadeMask.colors    = [UIColor.clear.cgColor, UIColor.black.cgColor]
        blurFadeMask.startPoint = CGPoint(x: 0.5, y: 0)
        blurFadeMask.endPoint   = CGPoint(x: 0.5, y: 1)
        bottomBlurView.layer.mask = blurFadeMask

        // 为 scrollView 增加底部内容 inset，避免内容被 fixed 底栏遮挡
        view.layoutIfNeeded()
        let bottomHeight = bottomBlurView.bounds.height
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomHeight + 20, right: 0)
        updateBlurFadeMask()
    }

    private func updateBlurFadeMask() {
        guard bottomBlurView.bounds.height > 0 else { return }
        blurFadeMask.frame = bottomBlurView.bounds
        // 渐变区只占顶部 fadeHeight（60pt），之后完全不透明
        let fadeRatio = 60.0 / bottomBlurView.bounds.height
        blurFadeMask.locations = [0, NSNumber(value: fadeRatio)]
    }

    private func setupContent() {
        // 标题信息
        headerLabel.text = "解锁高级版"
        headerLabel.font = .systemFont(ofSize: 32, weight: .heavy)
        headerLabel.textColor = .appTextPrimary
        headerLabel.textAlignment = .center

        subHeaderLabel.text = "解除一切格式限制，体验极速转换与提取"
        subHeaderLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subHeaderLabel.textColor = .appTextSecondary
        subHeaderLabel.textAlignment = .center

        let titleStack = UIStackView(arrangedSubviews: [headerLabel, subHeaderLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 12
        titleStack.alignment = .center

        // 渲染选项卡
        cardsStackView.axis = .vertical
        cardsStackView.spacing = 16

        for plan in PremiumPlan.allPlans {
            let card = PremiumPlanCardView(plan: plan)
            let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
            card.addGestureRecognizer(tap)
            cardViews.append(card)
            cardsStackView.addArrangedSubview(card)
        }

        // 政策协议声明
        let legalStack = createLegalStack()

        // 主干 Stack
        let mainStack = UIStackView(arrangedSubviews: [titleStack, cardsStackView, legalStack])
        mainStack.axis = .vertical
        mainStack.spacing = 40
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UIScreen.main.bounds.height / 6),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func createLegalStack() -> UIStackView {
        disclaimerLabel.font = .systemFont(ofSize: 12)
        disclaimerLabel.textColor = .appTextSecondary
        disclaimerLabel.textAlignment = .center
        disclaimerLabel.numberOfLines = 0

        // TODO: 替换为实际的用户协议和隐私政策 URL
        let termsBtn = createLinkButton(title: "用户协议") { [weak self] in
            self?.openSafari(url: URL(string: "https://example.com/terms")!)
        }

        let privacyBtn = createLinkButton(title: "隐私政策") { [weak self] in
            self?.openSafari(url: URL(string: "https://example.com/privacy")!)
        }

        let restoreBtn = createLinkButton(title: "恢复购买") { [weak self] in
            self?.handleRestore()
        }

        let linksRow = UIStackView(arrangedSubviews: [termsBtn, privacyBtn, restoreBtn])
        linksRow.axis = .horizontal
        linksRow.spacing = 16
        linksRow.alignment = .center
        linksRow.distribution = .equalCentering

        let container = UIStackView(arrangedSubviews: [disclaimerLabel, linksRow])
        container.axis = .vertical
        container.spacing = 8
        container.alignment = .center
        return container
    }

    private func createLinkButton(title: String, action: @escaping () -> Void) -> UIButton {
        let btn = ActionButton(action: action)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13.5),
            .foregroundColor: UIColor.appTextSecondary,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        btn.setAttributedTitle(NSAttributedString(string: title, attributes: attrs), for: .normal)
        return btn
    }

    // MARK: - StoreKit 2

    /// 从 App Store 加载产品信息，并用真实价格更新 UI
    private func loadProducts() async {
        let productIDs = PremiumPlan.allPlans.map(\.productID)
        do {
            let products = try await Product.products(for: productIDs)
            await MainActor.run {
                for product in products {
                    self.storeProducts[product.id] = product
                }
                self.refreshPriceDisplays()
            }
        } catch {
            // 加载失败时保留 allPlans 中的默认兜底价格，不影响 UI 正常使用
        }
    }

    /// 用 App Store 真实价格刷新所有卡片和订阅按钮
    private func refreshPriceDisplays() {
        for (index, plan) in PremiumPlan.allPlans.enumerated() {
            guard let product = storeProducts[plan.productID] else { continue }
            cardViews[index].updatePriceDisplay(product.displayPrice)
        }
        // 刷新订阅按钮上的价格文字
        updateSelection()
    }

    /// 返回当前已加载的 App Store 价格；未加载时回退到兜底字符串
    private func displayPrice(for plan: PremiumPlan) -> String {
        storeProducts[plan.productID]?.displayPrice ?? plan.priceStr
    }

    // MARK: - Handlers & State Updates

    @objc private func cardTapped(_ sender: UITapGestureRecognizer) {
        guard let tappedCard = sender.view as? PremiumPlanCardView else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        selectedPlan = tappedCard.plan
        updateSelection()
    }

    private func updateSelection() {
        for card in cardViews {
            card.setSelected(card.plan.id == selectedPlan.id, animated: true)
        }

        disclaimerLabel.text = selectedPlan.disclaimer

        // 使用真实价格（如已加载）或兜底价格
        let btnText = "\(displayPrice(for: selectedPlan)) 立即体验"
        subscribeButton.setTitle(btnText, for: .normal)

        // 按钮轻微跳动强调
        UIView.animate(withDuration: 0.1, animations: {
            self.subscribeButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                self.subscribeButton.transform = .identity
            }
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func subscribeTapped() {
        guard let product = storeProducts[selectedPlan.productID] else {
            // 产品尚未加载完成，给出提示
            showAlert(title: "提示", message: "产品信息加载中，请稍候重试")
            return
        }

        subscribeButton.isEnabled = false

        Task {
            defer {
                Task { @MainActor in self.subscribeButton.isEnabled = true }
            }
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    // 验证收据
                    guard case .verified(let transaction) = verification else {
                        await MainActor.run { self.showAlert(title: "验证失败", message: "收据验证未通过，请联系客服。") }
                        return
                    }
                    await transaction.finish()
                    // 先刷新 Premium 缓存，确保回调触发时 consumeIfAvailable 直接返回 true
                    await QuotaManager.shared.refreshPremiumStatus()
                    let callback = self.onPurchased
                    await MainActor.run {
                        // self.dismiss 会关闭包含 PremiumVC 的 NavigationController
                        // 动画完成后调用 callback，此时 PaywallSheet 再 dismiss 自身
                        self.dismiss(animated: true) {
                            callback?()
                        }
                    }

                case .userCancelled:
                    break // 用户主动取消，无需提示

                case .pending:
                    // 交易待处理：可能是 Ask to Buy 等待家长审批，或支付尚未完成
                    await MainActor.run {
                        self.showAlert(title: "订阅待处理", message: "您的订阅正在等待审批，批准后即可使用。")
                    }

                @unknown default:
                    break
                }
            } catch {
                await MainActor.run { self.showAlert(title: "订阅失败", message: error.localizedDescription) }
            }
        }
    }

    private func handleRestore() {
        Task {
            do {
                // 同步 App Store 购买记录
                try await AppStore.sync()
                showAlert(title: "恢复完成", message: "购买记录已同步，如有有效订阅将自动激活。")
            } catch {
                showAlert(title: "恢复失败", message: error.localizedDescription)
            }
        }
    }

    private func openSafari(url: URL) {
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PremiumPlanCardView

private class PremiumPlanCardView: UIView {

    let plan: PremiumPlan

    private var isCurrentlySelected = false

    private let radioIcon = UIImageView()
    private let titleLabel = UILabel()
    private let tagLabel = UILabel()
    private let tagContainer = UIView()
    private let priceLabel = UILabel()
    private let subtextLabel = UILabel()

    private let priceStackView = UIStackView()

    // 渐变边框（选中态）
    private let gradientBorderLayer = CAGradientLayer()
    private let gradientBorderMask  = CAShapeLayer()

    init(plan: PremiumPlan) {
        self.plan = plan
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 加载完产品后更新价格文字（保持选中色不变）
    func updatePriceDisplay(_ priceStr: String) {
        priceLabel.text = priceStr
    }

    private func setupUI() {
        backgroundColor = .appCardBackground
        layer.cornerRadius = 32
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.appCardBorder.withAlphaComponent(0.8).cgColor

        // 阴影效果
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8

        // 渐变边框层（默认隐藏，选中时显示）
        gradientBorderLayer.colors    = [UIColor.appGradientStart.cgColor,
                                         UIColor.appGradientMid.cgColor,
                                         UIColor.appGradientEnd.cgColor]
        gradientBorderLayer.locations = [0.0, 0.25, 1.0]
        gradientBorderLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientBorderLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientBorderLayer.isHidden   = true
        // mask 用镂空环形路径，只露出边框宽度区域
        gradientBorderLayer.mask = gradientBorderMask
        layer.addSublayer(gradientBorderLayer)

        radioIcon.contentMode = .scaleAspectFit
        radioIcon.tintColor = .appPrimary
        radioIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(radioIcon)

        titleLabel.text = plan.title
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        if let tagStr = plan.tag {
            tagLabel.text = tagStr
            tagLabel.font = .systemFont(ofSize: 9, weight: .medium)
            tagLabel.translatesAutoresizingMaskIntoConstraints = false

            tagContainer.layer.cornerRadius = 6
            tagContainer.clipsToBounds = true
            tagContainer.translatesAutoresizingMaskIntoConstraints = false

            tagContainer.addSubview(tagLabel)
            addSubview(tagContainer)

            NSLayoutConstraint.activate([
                tagLabel.topAnchor.constraint(equalTo: tagContainer.topAnchor, constant: 4),
                tagLabel.bottomAnchor.constraint(equalTo: tagContainer.bottomAnchor, constant: -4),
                tagLabel.leadingAnchor.constraint(equalTo: tagContainer.leadingAnchor, constant: 6),
                tagLabel.trailingAnchor.constraint(equalTo: tagContainer.trailingAnchor, constant: -6),

                tagContainer.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -2),
                tagContainer.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor)
            ])

            if tagStr == "限时折扣" {
                tagContainer.backgroundColor = UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 0.2)
                tagLabel.textColor = UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0)
            } else {
                tagContainer.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.2)
                tagLabel.textColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
            }
        }

        priceLabel.text = plan.priceStr
        if let desc = UIFont.systemFont(ofSize: 21, weight: .semibold).fontDescriptor.withDesign(.rounded) {
            priceLabel.font = UIFont(descriptor: desc, size: 21)
        } else {
            priceLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        }
        priceLabel.textColor = .appTextPrimary
        priceLabel.textAlignment = .right

        subtextLabel.text = plan.subtext
        subtextLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtextLabel.textColor = .appTextSecondary
        subtextLabel.textAlignment = .right

        priceStackView.axis = .vertical
        priceStackView.spacing = 8
        priceStackView.alignment = .trailing
        priceStackView.addArrangedSubview(priceLabel)
        priceStackView.addArrangedSubview(subtextLabel)
        priceStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(priceStackView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 104),

            radioIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            radioIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioIcon.widthAnchor.constraint(equalToConstant: 24),
            radioIcon.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: radioIcon.trailingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: plan.tag != nil ? 6 : 0),

            priceStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            priceStackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setSelected(false, animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientBorderLayer.frame = bounds
        // 镂空环形 mask：外圈 - 内圈（inset = 边框宽度）
        let borderWidth: CGFloat = 2.0
        let r = layer.cornerRadius
        let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: r)
        let innerRect  = bounds.insetBy(dx: borderWidth, dy: borderWidth)
        let innerPath  = UIBezierPath(roundedRect: innerRect, cornerRadius: max(r - borderWidth, 0))
        outerPath.append(innerPath.reversing())
        gradientBorderMask.path     = outerPath.cgPath
        gradientBorderMask.fillRule = .evenOdd
    }

    func setSelected(_ isSelected: Bool, animated: Bool) {
        self.isCurrentlySelected = isSelected
        let duration = animated ? 0.25 : 0.0

        // CALayer 属性无法通过 UIView.animate 驱动，用 CATransaction 控制
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        gradientBorderLayer.isHidden = !isSelected
        CATransaction.commit()

        UIView.animate(withDuration: duration) {
            if isSelected {
                // 选中：渐变层接管边框，背景改为品牌蓝极浅色调
                self.layer.borderWidth = 0
                self.backgroundColor = .appCardBackground.withAlphaComponent(0.65)
                let config = UIImage.SymbolConfiguration(weight: .bold)
                self.radioIcon.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
                self.radioIcon.tintColor = .appPrimary
                self.priceLabel.textColor = .appGradientMid
            } else {
                // 未选中：普通单色细边框
                self.layer.borderWidth = 1.0
                self.layer.borderColor = UIColor.appCardBorder.withAlphaComponent(0.8).cgColor
                self.backgroundColor = .appCardBackground.withAlphaComponent(0.65)
                let config = UIImage.SymbolConfiguration(weight: .light)
                self.radioIcon.image = UIImage(systemName: "circle", withConfiguration: config)
                self.radioIcon.tintColor = .appTextTertiary
                self.priceLabel.textColor = .appTextPrimary
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if !isCurrentlySelected {
            layer.borderColor = UIColor.appCardBorder.withAlphaComponent(0.8).cgColor
        }
    }
}

// MARK: - Animated Gradient Button
// 自带星光元素的渐变按钮

class AnimatedGradientButton: UIButton {

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        gradientLayer.colors = [UIColor.appGradientStart.cgColor,
                                UIColor.appGradientMid.cgColor,
                                UIColor.appGradientEnd.cgColor]
        gradientLayer.locations = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)

        addSparkles()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func addSparkles() {
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let image = UIImage(systemName: "sparkle", withConfiguration: config)

        let leftSparkle = UIImageView(image: image)
        leftSparkle.tintColor = UIColor.white.withAlphaComponent(0.6)
        leftSparkle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftSparkle)

        let rightSparkle = UIImageView(image: image)
        rightSparkle.tintColor = UIColor.white.withAlphaComponent(0.6)
        rightSparkle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightSparkle)

        NSLayoutConstraint.activate([
            leftSparkle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
            leftSparkle.centerYAnchor.constraint(equalTo: centerYAnchor),

            rightSparkle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            rightSparkle.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // 缓慢旋转闪烁动画
        UIView.animate(withDuration: 1.5, delay: 0, options: [.curveEaseInOut, .autoreverse, .repeat]) {
            leftSparkle.alpha = 0.2
            rightSparkle.alpha = 0.2
            leftSparkle.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            rightSparkle.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }
    }
}

// MARK: - ActionButton Utility

private class ActionButton: UIButton {
    private let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        addTarget(self, action: #selector(fired), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func fired() { action() }
}
