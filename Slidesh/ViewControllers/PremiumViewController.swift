//
//  PremiumViewController.swift
//  Slidesh
//
//  订阅与高级版界面，复现参照截图的 UI 设计
//

import UIKit
import SafariServices

// MARK: - PremiumPlan Model

struct PremiumPlan: Equatable {
    let id: String
    let title: String
    let tag: String?
    let priceStr: String
    let priceDouble: Double
    let subtext: String
    
    static let allPlans: [PremiumPlan] = [
        PremiumPlan(id: "week", title: "周卡订阅", tag: nil, priceStr: "¥12.00", priceDouble: 12.00, subtext: "每周仅 ¥12.00"),
        PremiumPlan(id: "month", title: "月卡订阅", tag: "最受欢迎", priceStr: "¥38.00", priceDouble: 38.00, subtext: "每天低至 ¥1.26"),
        PremiumPlan(id: "year", title: "年卡订阅", tag: "限时折扣", priceStr: "¥198.00", priceDouble: 198.00, subtext: "每月低至 ¥16.50")
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
    
    // 底部浮动交互条
    private let bottomBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let subscribeButton = AnimatedGradientButton()
    private let autoRenewTipLabel = UILabel()
    
    // 存储所有卡片及当前选中状态
    private var cardViews: [PremiumPlanCardView] = []
    private var selectedPlan: PremiumPlan = PremiumPlan.allPlans[1] // 默认选中月卡

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupNavigationBar()
        setupScrollView()
        setupBottomBar()
        setupContent()
        
        // 初始更新选中状态
        updateSelection()
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
        subscribeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.layer.cornerRadius = 28
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
        
        NSLayoutConstraint.activate([
            bottomBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            container.topAnchor.constraint(equalTo: bottomBlurView.topAnchor),
            container.leadingAnchor.constraint(equalTo: bottomBlurView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: bottomBlurView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            subscribeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            subscribeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            subscribeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            subscribeButton.heightAnchor.constraint(equalToConstant: 56),
            
            autoRenewTipLabel.topAnchor.constraint(equalTo: subscribeButton.bottomAnchor, constant: 12),
            autoRenewTipLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            autoRenewTipLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            autoRenewTipLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12) // padding bottom
        ])
        
        // 为 scrollView 增加底部内容 inset，避免内容被 fixed 底栏遮挡
        view.layoutIfNeeded()
        let bottomHeight = bottomBlurView.bounds.height
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomHeight + 20, right: 0)
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
        
        // iOS SafeArea 上边距大概是 44 到 59，关闭按钮在NavigationBar，所以只需少量上边距
        let topPadding: CGFloat = 20
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: topPadding),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func createLegalStack() -> UIStackView {
        let disclaimer = UILabel()
        disclaimer.text = "每月包含无限次使用，服务将自动续期，随时可取消"
        disclaimer.font = .systemFont(ofSize: 12)
        disclaimer.textColor = .appTextSecondary
        disclaimer.textAlignment = .center
        disclaimer.numberOfLines = 0
        
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
        
        let container = UIStackView(arrangedSubviews: [disclaimer, linksRow])
        container.axis = .vertical
        container.spacing = 8
        container.alignment = .center
        return container
    }
    
    private func createLinkButton(title: String, action: @escaping () -> Void) -> UIButton {
        let btn = ActionButton(action: action)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.appTextSecondary,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        btn.setAttributedTitle(NSAttributedString(string: title, attributes: attrs), for: .normal)
        return btn
    }
    
    // MARK: - Handlers & State Updates

    @objc private func cardTapped(_ sender: UITapGestureRecognizer) {
        guard let tappedCard = sender.view as? PremiumPlanCardView else { return }
        
        // 触感反馈
        UISelectionFeedbackGenerator().selectionChanged()
        
        selectedPlan = tappedCard.plan
        updateSelection()
    }
    
    private func updateSelection() {
        for card in cardViews {
            let isSelected = (card.plan.id == selectedPlan.id)
            card.setSelected(isSelected, animated: true)
        }
        
        // 更新大按钮字样
        let btnText = "\(selectedPlan.priceStr) 立即体验"
        subscribeButton.setTitle(btnText, for: .normal)
        
        // 给按钮一个轻微跳动强调动画
        UIView.animate(withDuration: 0.1, animations: {
            self.subscribeButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.subscribeButton.transform = .identity
            })
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func subscribeTapped() {
        let alert = UIAlertController(title: "确认订阅", message: "您将订阅【\(selectedPlan.title)】，模拟支付流程...", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true) {
                // Success logic
                let success = UIAlertController(title: "订阅成功", message: "感谢您的支持！", preferredStyle: .alert)
                success.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
                    self.dismiss(animated: true)
                }))
                self.present(success, animated: true)
            }
        }
    }
    
    private func handleRestore() {
        let alert = UIAlertController(title: "恢复购买", message: "正在恢复您的购买记录…", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            alert.dismiss(animated: true) {
                let result = UIAlertController(title: "恢复完成", message: "未找到可恢复的订阅记录。", preferredStyle: .alert)
                result.addAction(UIAlertAction(title: "确定", style: .default))
                self?.present(result, animated: true)
            }
        }
    }
    
    private func openSafari(url: URL) {
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }
}

// MARK: - PremiumPlanCardView

private class PremiumPlanCardView: UIView {
    
    let plan: PremiumPlan
    
    private let radioIcon = UIImageView()
    private let titleLabel = UILabel()
    private let tagLabel = UILabel()
    private let tagContainer = UIView()
    private let priceLabel = UILabel()
    private let subtextLabel = UILabel()
    
    init(plan: PremiumPlan) {
        self.plan = plan
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        backgroundColor = .appCardBackground
        layer.cornerRadius = 28
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.appCardBorder.withAlphaComponent(0.4).cgColor
        
        // 分别增加阴影效果
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        
        radioIcon.contentMode = .scaleAspectFit
        radioIcon.tintColor = .appPrimary
        radioIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(radioIcon)
        
        titleLabel.text = plan.title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        if let tagStr = plan.tag {
            tagLabel.text = tagStr
            tagLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            tagLabel.textColor = .white
            tagLabel.translatesAutoresizingMaskIntoConstraints = false
            
            tagContainer.backgroundColor = .appPrimary.withAlphaComponent(0.6)
            tagContainer.layer.cornerRadius = 6
            tagContainer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMinYCorner] // 默认全圆角
            tagContainer.clipsToBounds = true
            tagContainer.translatesAutoresizingMaskIntoConstraints = false
            
            tagContainer.addSubview(tagLabel)
            addSubview(tagContainer)
            
            NSLayoutConstraint.activate([
                tagLabel.topAnchor.constraint(equalTo: tagContainer.topAnchor, constant: 2),
                tagLabel.bottomAnchor.constraint(equalTo: tagContainer.bottomAnchor, constant: -2),
                tagLabel.leadingAnchor.constraint(equalTo: tagContainer.leadingAnchor, constant: 6),
                tagLabel.trailingAnchor.constraint(equalTo: tagContainer.trailingAnchor, constant: -6),
                
                tagContainer.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -2),
                tagContainer.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor)
            ])
            
            // 为了让 tag 贴靠更紧凑，如果是最受欢迎类型可以染特殊的颜色
            if tagStr == "限时折扣" {
                tagContainer.backgroundColor = .systemPurple.withAlphaComponent(0.6)
            } else {
                tagContainer.backgroundColor = .appPrimary.withAlphaComponent(0.6)
            }
        }
        
        priceLabel.text = plan.priceStr
        if let desc = UIFont.systemFont(ofSize: 26, weight: .bold).fontDescriptor.withDesign(.rounded) {
            priceLabel.font = UIFont(descriptor: desc, size: 26)
        } else {
            priceLabel.font = .systemFont(ofSize: 26, weight: .bold)
        }
        priceLabel.textColor = .appTextPrimary
        priceLabel.textAlignment = .right
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(priceLabel)
        
        subtextLabel.text = plan.subtext
        subtextLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtextLabel.textColor = .appTextSecondary
        subtextLabel.textAlignment = .right
        subtextLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtextLabel)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 104),
            
            radioIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            radioIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioIcon.widthAnchor.constraint(equalToConstant: 24),
            radioIcon.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: radioIcon.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: plan.tag != nil ? 6 : 0),
            
            priceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            priceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            
            subtextLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            subtextLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
        
        setSelected(false, animated: false)
    }
    
    func setSelected(_ isSelected: Bool, animated: Bool) {
        let duration = animated ? 0.25 : 0.0
        UIView.animate(withDuration: duration) {
            if isSelected {
                self.layer.borderWidth = 2.5
                self.layer.borderColor = UIColor.appPrimary.cgColor
                self.backgroundColor = UIColor.appPrimary.withAlphaComponent(0.06)
                // SF Symbol checkmark 选中
                let config = UIImage.SymbolConfiguration(weight: .bold)
                self.radioIcon.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
                self.radioIcon.tintColor = .appPrimary
            } else {
                self.layer.borderWidth = 1.0
                self.layer.borderColor = UIColor.appCardBorder.withAlphaComponent(0.4).cgColor
                self.backgroundColor = .appCardBackground
                // SF Symbol 空心圆
                let config = UIImage.SymbolConfiguration(weight: .light)
                self.radioIcon.image = UIImage(systemName: "circle", withConfiguration: config)
                self.radioIcon.tintColor = .appTextTertiary
            }
        }
    }
    
    // 覆盖系统特质变化以更新边框颜色
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Check if currently selected, if not, update border to standard theme color
        if self.backgroundColor == .appCardBackground {
            self.layer.borderColor = UIColor.appCardBorder.withAlphaComponent(0.4).cgColor
        } else {
            self.layer.borderColor = UIColor.appPrimary.cgColor
        }
    }
}

// MARK: - Animated Gradient Button
// 自带星光元素的渐变按钮

private class AnimatedGradientButton: UIButton {
    
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
        // 在按钮左右两边添加一些星星
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
