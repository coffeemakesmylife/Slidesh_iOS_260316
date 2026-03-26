//
//  OnboardingViewController.swift
//  Slidesh
//
//  Created for cultivating user habits and subscription guide
//

import UIKit
import StoreKit

class OnboardingViewController: UIViewController {
    
    // MARK: - Properties
    private var currentStep: Int = 0 {
        didSet { refreshContent() }
    }
    private let totalSteps = 4
    
    // 从服务端配置读取引导套餐：0=周 1=月 2=年
    private var guidedPlan: PremiumPlan {
        let index = UserDefaults.standard.integer(forKey: "guided_subscription_plan")
        let ids = ["week", "month", "year"]
        let id = (0..<ids.count).contains(index) ? ids[index] : "week"
        return PremiumPlan.allPlans.first(where: { $0.id == id }) ?? PremiumPlan.allPlans.last!
    }
    private var guidedProduct: Product?
    private var titleTopConstraint: NSLayoutConstraint?

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let heroImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .clear
        return iv
    }()
    
    private let heroGradientView: UIView = {
        let view = UIView()
        let gradient = CAGradientLayer()
        gradient.locations = [0.0, 0.5, 0.85, 1.0]
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.appBackgroundPrimary.withAlphaComponent(0.2).cgColor,
            UIColor.appBackgroundPrimary.withAlphaComponent(0.7).cgColor,
            UIColor.appBackgroundPrimary.cgColor
        ]
        view.layer.addSublayer(gradient)
        view.tag = 999
        return view
    }()
    
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 32, weight: .bold)
        lbl.textColor = .appTextPrimary
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        return lbl
    }()
    
    // 仅在第4页（step 3）显示的权益列表
    private let featuresContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.distribution = .fill
        stack.isHidden = true
        return stack
    }()
    
    // 底部浮动区：与 PremiumViewController 风格一致
    private let bottomBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let blurFadeMask = CAGradientLayer()
    private let bottomContainer = UIView()
    private let actionButton = AnimatedGradientButton()

    // 订阅价格说明（第4页权益列表下方）
    private let priceLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .appTextSecondary
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        lbl.isHidden = true
        return lbl
    }()

    // 关闭按钮（左上角，仅第4页显示）
    private let skipButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 19, weight: .bold)
        let img = UIImage(systemName: "xmark", withConfiguration: config)
        btn.setImage(img, for: .normal)
        btn.tintColor = .appTextPrimary
        btn.backgroundColor = UIColor.appBackgroundPrimary.withAlphaComponent(0.7)
        btn.layer.cornerRadius = 22
        btn.layer.borderWidth = 1.5
        btn.layer.borderColor = UIColor.appBackgroundPrimary.cgColor
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.15
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 4
        return btn
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadProducts()
        refreshContent(animated: false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradientView = view.viewWithTag(999),
           let gradient = gradientView.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = gradientView.bounds
        }
        updateBlurFadeMask()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .appBackgroundPrimary
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(heroImageView)
        contentView.addSubview(heroGradientView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(featuresContainer)
        contentView.addSubview(priceLabel)
        
        view.addSubview(bottomBlurView)
        bottomBlurView.contentView.addSubview(bottomContainer)
        bottomContainer.addSubview(actionButton)
        
        view.addSubview(skipButton)
        
        skipButton.isHidden = true  // 初始隐藏，第4页才显示
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        
        buildFeaturesList()
        applyConstraints()
        setupBottomBarAppearance()
    }
    
    private func buildFeaturesList() {
        let benefits = [
            "无限次生成PPT大纲",
            "无限制大纲+模板合成PPT",
            "解除所有文件的格式转换限制",
            "极速服务器响应时间"
        ]
        for text in benefits {
            let row = makeFeatureRow(text: text)
            featuresContainer.addArrangedSubview(row)
        }
    }
    
    private func makeFeatureRow(text: String) -> UIView {
        let container = UIView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: config))
        iconView.tintColor = .appPrimary
        iconView.contentMode = .scaleAspectFit
        
        let textLabel = UILabel()
        textLabel.text = text
        textLabel.font = .systemFont(ofSize: 16, weight: .medium)
        textLabel.textColor = .appTextPrimary
        textLabel.numberOfLines = 0
        
        container.addSubview(iconView)
        container.addSubview(textLabel)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            textLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            textLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }
    
    private func applyConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroGradientView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        featuresContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomBlurView.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        
        let screenHeight = UIScreen.main.bounds.height
        let fadeHeight: CGFloat = 60

        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // 关闭按钮 -> 左上角，仅第4页可见
            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            skipButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            skipButton.widthAnchor.constraint(equalToConstant: 44),
            skipButton.heightAnchor.constraint(equalToConstant: 44),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            // 顶部图片（占用总屏幕高度的 45%）
            heroImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            heroImageView.heightAnchor.constraint(equalToConstant: screenHeight * 0.45),
            
            heroGradientView.topAnchor.constraint(equalTo: heroImageView.topAnchor),
            heroGradientView.leadingAnchor.constraint(equalTo: heroImageView.leadingAnchor),
            heroGradientView.trailingAnchor.constraint(equalTo: heroImageView.trailingAnchor),
            heroGradientView.bottomAnchor.constraint(equalTo: heroImageView.bottomAnchor),
            
            // 标题文本（constraint 引用留给 refreshContent 动态调整）
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            // 最后一页的权益列表
            featuresContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 36),
            featuresContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            featuresContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),

            // 价格说明在权益列表下方
            priceLabel.topAnchor.constraint(equalTo: featuresContainer.bottomAnchor, constant: 30),
            priceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            priceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            
            // 底部悬浮区
            bottomBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBlurView.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: -fadeHeight),
            
            bottomContainer.topAnchor.constraint(equalTo: bottomBlurView.topAnchor, constant: fadeHeight),
            bottomContainer.leadingAnchor.constraint(equalTo: bottomBlurView.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: bottomBlurView.trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // 操作按钮
            actionButton.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 16),
            actionButton.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor, constant: 24),
            actionButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor, constant: -24),
            actionButton.heightAnchor.constraint(equalToConstant: 60),
            actionButton.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor, constant: -16)
        ])

        // 单独保存 title top 约束，供动态调整位置
        let titleTop = titleLabel.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: 24)
        titleTop.isActive = true
        titleTopConstraint = titleTop
    }
    
    private func setupBottomBarAppearance() {
        actionButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        actionButton.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        actionButton.layer.borderWidth = 2.0
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 30
        actionButton.clipsToBounds = true
        
        blurFadeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        blurFadeMask.startPoint = CGPoint(x: 0.5, y: 0)
        blurFadeMask.endPoint = CGPoint(x: 0.5, y: 1)
        bottomBlurView.layer.mask = blurFadeMask
        
        view.layoutIfNeeded()
        let bottomHeight = bottomBlurView.bounds.height
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomHeight + 20, right: 0)
    }
    
    private func updateBlurFadeMask() {
        guard bottomBlurView.bounds.height > 0 else { return }
        blurFadeMask.frame = bottomBlurView.bounds
        let fadeRatio = 60.0 / bottomBlurView.bounds.height
        blurFadeMask.locations = [0, NSNumber(value: fadeRatio)]
    }
    
    // MARK: - StoreKit 2
    private func loadProducts() {
        let plan = guidedPlan
        Task {
            do {
                let products = try await Product.products(for: [plan.productID])
                if let pd = products.first {
                    await MainActor.run {
                        self.guidedProduct = pd
                        self.refreshContent(animated: false)
                    }
                }
            } catch {
                print("Failed to load products: \(error)")
            }
        }
    }
    
    // MARK: - Content

    private func refreshContent(animated: Bool = true) {
        let data = getStepData()
        let isLastStep = currentStep == totalSteps - 1

        // 前三页：title 垂直居中于图片下方与按钮区域之间
        // 最后一页：保持紧贴图片下方（24pt）
        let newTopConstant: CGFloat
        if isLastStep {
            newTopConstant = 24
        } else {
            let screenH = UIScreen.main.bounds.height
            let imageH  = screenH * 0.45
            let barH    = bottomBlurView.bounds.height > 0 ? bottomBlurView.bounds.height : 120
            let available = screenH - imageH - barH
            newTopConstant = max(24, available / 2 - 20)
        }

        // 立即切换显隐（切页时这些元素不在视口中）
        featuresContainer.isHidden = !isLastStep
        priceLabel.isHidden        = !isLastStep
        skipButton.isHidden        = !isLastStep
        if isLastStep {
            let plan = guidedPlan
            let priceText = guidedProduct?.displayPrice ?? plan.priceStr
            priceLabel.text = priceLabelText(plan: plan, price: priceText)
        }

        // 图片：cross-dissolve
        UIView.transition(with: heroImageView, duration: 0.45, options: .transitionCrossDissolve) {
            if let image = data.image {
                self.heroImageView.image = image
                self.heroImageView.tintColor = .clear
            } else {
                let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
                self.heroImageView.image = UIImage(systemName: "wand.and.stars", withConfiguration: config)
                self.heroImageView.tintColor = .appPrimary
            }
        }

        guard animated else {
            // 初次加载：直接设置，不执行动画
            titleLabel.text = data.title
            titleTopConstraint?.constant = newTopConstant
            actionButton.setTitle(data.buttonTitle, for: .normal)
            return
        }

        // 标题动画：先淡出上移，再从下方弹入新内容
        UIView.animate(withDuration: 0.18, options: .curveEaseIn) {
            self.titleLabel.alpha = 0
            self.titleLabel.transform = CGAffineTransform(translationX: 0, y: -8)
        } completion: { _ in
            self.titleLabel.text = data.title
            self.titleTopConstraint?.constant = newTopConstant
            self.titleLabel.transform = CGAffineTransform(translationX: 0, y: 30)
            UIView.animate(
                withDuration: 0.55, delay: 0,
                usingSpringWithDamping: 0.72, initialSpringVelocity: 0.3
            ) {
                self.titleLabel.alpha = 1
                self.titleLabel.transform = .identity
                self.view.layoutIfNeeded()   // 同步驱动约束位移动画
            }
        }

        // 按钮文字淡换
        UIView.transition(with: actionButton, duration: 0.25, options: .transitionCrossDissolve) {
            self.actionButton.setTitle(data.buttonTitle, for: .normal)
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func getStepData() -> (title: String, image: UIImage?, buttonTitle: String) {
        switch currentStep {
        case 0: return ("一键生成专业幻灯片",    UIImage(named: "guide_bg_1"), "继续")
        case 1: return ("解除一切格式转换限制",   UIImage(named: "guide_bg_2"), "继续")
        case 2: return ("随时随地的高效创作",     UIImage(named: "guide_bg_3"), "继续")
        case 3: return ("解锁全部高级特权",       UIImage(named: "guide_bg_4"), "继续")
        default: return ("", nil, "继续")
        }
    }

    /// 按套餐类型定制价格说明文案
    private func priceLabelText(plan: PremiumPlan, price: String) -> String {
        switch plan.id {
        case "week":  return "每周 \(price)自动续费，随时可取消"
        case "month": return "首月¥18 ，之后\(price)/月自动续费，随时可取消"
        case "year":  return "每年 \(price)自动续费，随时可取消"
        default:      return "自动续费 \(price)，随时可取消"
        }
    }
    
    // MARK: - Actions
    @objc private func actionTapped() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            if QuotaManager.shared.isPremium {
                navigateToMain()
            } else {
                startSubscription()
            }
        }
    }
    
    @objc private func skipTapped() {
        navigateToMain()
    }
    
    private func startSubscription() {
        guard let product = guidedProduct else {
            showAlert(title: "提示", message: "产品信息加载中，请稍候重试")
            return
        }
        
        actionButton.isEnabled = false
        Task {
            defer { Task { @MainActor in self.actionButton.isEnabled = true } }
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    guard case .verified(let transaction) = verification else {
                        await MainActor.run { self.showAlert(title: "验证失败", message: "收据验证未通过，请联系客服。") }
                        return
                    }
                    await transaction.finish()
                    await QuotaManager.shared.refreshPremiumStatus()
                    await MainActor.run { self.navigateToMain() }
                case .userCancelled:
                    break
                case .pending:
                    await MainActor.run { self.showAlert(title: "订阅待处理", message: "您的订阅正在等待审批，批准后即可使用。") }
                @unknown default:
                    break
                }
            } catch {
                await MainActor.run { self.showAlert(title: "订阅失败", message: error.localizedDescription) }
            }
        }
    }
    
    private func navigateToMain() {
        guard let window = view.window else { return }
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = CustomTabBarController()
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
