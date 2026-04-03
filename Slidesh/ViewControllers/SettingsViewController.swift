//
//  SettingsViewController.swift
//  Slidesh
//

import UIKit
import SafariServices

class SettingsViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let cardRadius: CGFloat = 30
    private let rowHeight: CGFloat = 66
    private let sideInset: CGFloat = 20

    // 主题行的引用，用于切换后重建 menu state
    private weak var themeValueLabel: UILabel?
    private weak var themeButton: UIButton?

    // 会员卡片的引用，用于付费后更新文案
    private weak var vipTitleLabel: UILabel?
    private weak var vipFeaturesLabel: UILabel?
    private weak var vipButton: UIButton?
    private weak var vipGradientLayer: CAGradientLayer?

    // 渐变色方案
    private var normalGradientColors: [CGColor] {
        [UIColor.appGradientStart.cgColor, UIColor.appGradientMid.cgColor, UIColor.appGradientEnd.cgColor]
    }
    private var premiumGradientColors: [CGColor] {
        [UIColor(red: 1.00, green: 0.82, blue: 0.28, alpha: 1).cgColor,  // 亮金
         UIColor(red: 0.92, green: 0.60, blue: 0.08, alpha: 1).cgColor,  // 琥珀
         UIColor(red: 0.72, green: 0.42, blue: 0.02, alpha: 1).cgColor]  // 深金
    }
    private var premiumButtonTitleColor: UIColor {
        UIColor(red: 0.60, green: 0.32, blue: 0.00, alpha: 1)            // 深棕金，搭配白色按钮背景
    }

    // 隐私 / 条款链接（替换为正式 URL）
    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let termsURL   = URL(string: "https://example.com/terms")!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "设置"
        addMeshGradientBackground()
        setupScrollView()
        buildSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task {
            await QuotaManager.shared.refreshPremiumStatus()
            updateVIPCard()
        }
    }

    // MARK: - 滚动容器

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .always
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
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - 构建 Section

    private func buildSections() {
        let vipCard = makeVIPCard()
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(unlockPro))
        vipCard.addGestureRecognizer(cardTap)

        // Section 2：主题（上下 chevron 选择）+ 切换应用图标
        let section2 = makeCard(rows: [
            makeThemeRow(),
            makeRow(sfSymbol: "square.grid.2x2", title: "切换应用图标") { [weak self] in
                self?.changeAppIcon()
            },
        ])

        // Section 3：反馈 + 分享 + 恢复购买
        let section3 = makeCard(rows: [
            makeRow(sfSymbol: "envelope", title: "反馈") { [weak self] in
                self?.push(FeedbackViewController())
            },
            makeRow(sfSymbol: "square.and.arrow.up", title: "分享") { [weak self] in
                self?.shareApp()
            },
            makeRow(sfSymbol: "arrow.clockwise.circle", title: "恢复购买") { [weak self] in
                self?.restorePurchase()
            },
        ])

        // Section 4：隐私政策 + 使用条款 + FAQ + 关于
        let section4 = makeCard(rows: [
            makeRow(sfSymbol: "hand.raised.fill", title: "隐私政策") { [weak self] in
                self?.openSafari(url: self!.privacyURL)
            },
            makeRow(sfSymbol: "doc.text", title: "使用条款") { [weak self] in
                self?.openSafari(url: self!.termsURL)
            },
            makeRow(sfSymbol: "questionmark.circle.fill", title: "FAQ") { [weak self] in
                self?.push(FAQViewController())
            },
            makeRow(sfSymbol: "info.circle.fill", title: "关于") { [weak self] in
                self?.push(AboutViewController())
            },
        ])

        var sections: [UIView] = []
        #if DEBUG
        sections.append(makeDebugSection())
        #endif
        sections.append(contentsOf: [vipCard, section2, section3, section4])
        let stack = UIStackView(arrangedSubviews: sections)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sideInset),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sideInset),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - 会员横幅卡片

    private func makeVIPCard() -> UIView {
        let card = UIView()
        card.layer.cornerRadius = cardRadius
        card.clipsToBounds = true
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        card.layer.borderWidth = 2.0

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.appGradientStart.cgColor,
                           UIColor.appGradientMid.cgColor,
                           UIColor.appGradientEnd.cgColor]
        gradient.locations = [0.0, 0.55, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint   = CGPoint(x: 1, y: 1)
        card.layer.insertSublayer(gradient, at: 0)
        vipGradientLayer = gradient

        let titleLabel = UILabel()
        titleLabel.text = "升级 Pro 会员"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        vipTitleLabel = titleLabel

        let featuresLabel = UILabel()
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.paragraphSpacing = 8
        featuresLabel.attributedText = NSAttributedString(
            string: "✓ 无限制生成大纲\n✓ 无限制高级格式转换\n✓ 无限制生成演示文稿",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .paragraphStyle: paraStyle,
            ])
        featuresLabel.numberOfLines = 0
        vipFeaturesLabel = featuresLabel

        let btn = UIButton(type: .system)
        btn.setTitle("立即升级", for: .normal)
        btn.setTitleColor(.appPrimary, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 18, bottom: 6, right: 18)
        btn.addTarget(self, action: #selector(unlockPro), for: .touchUpInside)
        vipButton = btn

        let deco = UIImageView(image: UIImage(named: "speak-ai-line")?.withRenderingMode(.alwaysTemplate))
        deco.tintColor = UIColor.white.withAlphaComponent(0.12)
        deco.contentMode = .scaleAspectFit
        deco.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 7.2)

        [titleLabel, featuresLabel, btn, deco].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: deco.leadingAnchor, constant: -8),

            featuresLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            featuresLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            featuresLabel.trailingAnchor.constraint(lessThanOrEqualTo: deco.leadingAnchor, constant: -8),

            btn.topAnchor.constraint(equalTo: featuresLabel.bottomAnchor, constant: 18),
            btn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            btn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),

            deco.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            deco.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            deco.widthAnchor.constraint(equalToConstant: 100),
            deco.heightAnchor.constraint(equalToConstant: 100),
        ])

        let gradientUpdater = GradientFrameUpdateView(gradientLayer: gradient)
        gradientUpdater.translatesAutoresizingMaskIntoConstraints = false
        card.insertSubview(gradientUpdater, at: 0)
        NSLayoutConstraint.activate([
            gradientUpdater.topAnchor.constraint(equalTo: card.topAnchor),
            gradientUpdater.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            gradientUpdater.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            gradientUpdater.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])

        return card
    }

    // MARK: - 主题行（UIMenu 弹出，上下 chevron 指示）

    private func makeThemeRow() -> UIView {
        // 用 UIButton 挂 UIMenu，showsMenuAsPrimaryAction 让单次点击即触发
        let row = UIButton(type: .system)
        row.showsMenuAsPrimaryAction = true
        row.addTarget(self, action: #selector(rowHighlight(_:)), for: .touchDown)
        row.addTarget(self, action: #selector(rowUnhighlight(_:)), for: [.menuActionTriggered, .touchUpOutside, .touchCancel])

        let icon = UIImageView(image: UIImage(systemName: "moon.circle.fill"))
        icon.tintColor = .appTextSecondary
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        icon.isUserInteractionEnabled = false

        let titleLabel = UILabel()
        titleLabel.text = "主题"
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .appTextPrimary
        titleLabel.isUserInteractionEnabled = false

        let valueLabel = UILabel()
        valueLabel.text = currentThemeName()
        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = .appTextSecondary
        valueLabel.isUserInteractionEnabled = false
        themeValueLabel = valueLabel
        themeButton = row

        let chevron = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
        chevron.tintColor = .appTextTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        chevron.contentMode = .scaleAspectFit
        chevron.isUserInteractionEnabled = false

        [icon, titleLabel, valueLabel, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }

        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),

            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),

            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
        ])

        // 构建 UIMenu
        row.menu = makeThemeMenu()

        return row
    }

    private func makeThemeMenu() -> UIMenu {
        let options: [(String, String, UIUserInterfaceStyle)] = [
            ("跟随系统", "circle.lefthalf.filled", .unspecified),
            ("浅色主题",  "sun.max",                .light),
            ("深色主题",  "moon.fill",               .dark),
        ]
        let current = ThemeManager.shared.currentStyle
        let actions = options.map { title, symbol, style in
            UIAction(
                title: title,
                image: UIImage(systemName: symbol),
                state: current == style ? .on : .off
            ) { [weak self] _ in
                ThemeManager.shared.apply(style)
                self?.themeValueLabel?.text = ThemeManager.shared.currentStyleName
                // 重建 menu，下次弹出时 state 正确
                self?.themeButton?.menu = self?.makeThemeMenu()
            }
        }
        return UIMenu(title: "", children: actions)
    }

    // MARK: - 通用卡片
    // 外层负责 shadow，内层 clipsToBounds 确保点击高亮不溢出圆角

    private func makeCard(rows: [UIView]) -> UIView {
        // 外层：仅承载阴影，不裁切
        let outer = UIView()
        outer.layer.cornerRadius = cardRadius
        outer.layer.shadowColor = UIColor.black.cgColor
        outer.layer.shadowOpacity = 0.06
        outer.layer.shadowOffset = CGSize(width: 0, height: 2)
        outer.layer.shadowRadius = 8

        // 内层：裁切圆角，点击高亮不会超出边界
        let inner = UIView()
        inner.backgroundColor = .appCardBackground.withAlphaComponent(0.65)
        inner.layer.cornerRadius = cardRadius
        inner.clipsToBounds = true
        inner.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: outer.topAnchor),
            inner.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: outer.bottomAnchor),
        ])

        var prev: UIView? = nil
        for (i, row) in rows.enumerated() {
            row.translatesAutoresizingMaskIntoConstraints = false
            inner.addSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: inner.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: inner.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: rowHeight),
            ])
            if let prev = prev {
                let sep = makeSeparator()
                inner.addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.topAnchor.constraint(equalTo: prev.bottomAnchor),
                    sep.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: 52),
                    sep.trailingAnchor.constraint(equalTo: inner.trailingAnchor),
                    sep.heightAnchor.constraint(equalToConstant: 0.5),
                    row.topAnchor.constraint(equalTo: sep.bottomAnchor),
                ])
            } else {
                row.topAnchor.constraint(equalTo: inner.topAnchor).isActive = true
            }
            if i == rows.count - 1 {
                row.bottomAnchor.constraint(equalTo: inner.bottomAnchor).isActive = true
            }
            prev = row
        }
        return outer
    }

    // MARK: - 通用行（带 action 闭包）

    private func makeRow(sfSymbol: String, title: String, action: (() -> Void)? = nil) -> UIView {
        let row = ActionRow(action: action)
        row.addTarget(self, action: #selector(rowHighlight(_:)), for: .touchDown)
        row.addTarget(self, action: #selector(rowUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        let icon = UIImageView(image: UIImage(systemName: sfSymbol))
        icon.tintColor = .appTextSecondary
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16)
        label.textColor = .appTextPrimary

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .appTextTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        chevron.contentMode = .scaleAspectFit

        [icon, label, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
            row.addSubview($0)
        }

        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
        ])

        return row
    }

    // MARK: - 分割线

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = .appSeparator
        line.translatesAutoresizingMaskIntoConstraints = false
        return line
    }

    // MARK: - 主题

    private func currentThemeName() -> String {
        ThemeManager.shared.currentStyleName
    }

    // MARK: - 其他行动作

    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openSafari(url: URL) {
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    private func shareApp() {
        let text = "推荐你使用 Slidesh，一键生成精美演示文稿！"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // iPad 需要指定 sourceView，iPhone 自动从底部弹出
        if let popover = vc.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(vc, animated: true)
    }

    private func restorePurchase() {
        let alert = UIAlertController(title: "恢复购买", message: "正在恢复您的购买记录…", preferredStyle: .alert)
        present(alert, animated: true)
        // 模拟异步恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            alert.dismiss(animated: true) {
                let result = UIAlertController(title: "恢复完成", message: "未找到可恢复的购买记录。", preferredStyle: .alert)
                result.addAction(UIAlertAction(title: "确定", style: .default))
                self?.present(result, animated: true)
            }
        }
    }

    private func changeAppIcon() {
        push(AppIconPickerViewController())
    }

    // MARK: - 高亮

    private func updateVIPCard() {
        let isPremium = QuotaManager.shared.isPremium
        vipTitleLabel?.text = isPremium ? "Pro 会员" : "升级 Pro 会员"

        // 渐变色切换动画
        if let gradient = vipGradientLayer {
            let newColors = isPremium ? premiumGradientColors : normalGradientColors
            let anim = CABasicAnimation(keyPath: "colors")
            anim.fromValue = gradient.colors
            anim.toValue = newColors
            anim.duration = 0.6
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            gradient.colors = newColors   // 先更新 model layer，动画结束后无闪烁
            gradient.add(anim, forKey: "gradientColorChange")
        }

        let paraStyle = NSMutableParagraphStyle()
        paraStyle.paragraphSpacing = 8
        let featuresText = isPremium
            ? "✓ 无限制生成大纲\n✓ 无限制高级格式转换\n✓ 无限制生成演示文稿"
            : "✓ 无限制生成大纲\n✓ 无限制高级格式转换\n✓ 无限制生成演示文稿"
        vipFeaturesLabel?.attributedText = NSAttributedString(
            string: featuresText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .paragraphStyle: paraStyle,
            ])

        vipButton?.setTitle(isPremium ? "管理订阅" : "立即升级", for: .normal)
        vipButton?.setTitleColor(isPremium ? premiumButtonTitleColor : .appPrimary, for: .normal)
        vipButton?.removeTarget(nil, action: nil, for: .allEvents)
        if isPremium {
            vipButton?.addTarget(self, action: #selector(manageSubscription), for: .touchUpInside)
        } else {
            vipButton?.addTarget(self, action: #selector(unlockPro), for: .touchUpInside)
        }
    }

    @objc private func manageSubscription() {
        // 跳转到 App Store 订阅管理页
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    @objc private func unlockPro() {
        let vc = PremiumViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Debug 区域

    #if DEBUG
    private func makeDebugSection() -> UIView {
        let header = UILabel()
        header.text = "DEBUG"
        header.font = .systemFont(ofSize: 11, weight: .semibold)
        header.textColor = .systemOrange

        let card = makeCard(rows: [
            makeDebugPremiumToggleRow(),
            makeRow(sfSymbol: "creditcard", title: "显示付费界面") { [weak self] in
                guard let self else { return }
                let premiumVC = PremiumViewController()
                let nav = UINavigationController(rootViewController: premiumVC)
                nav.modalPresentationStyle = .fullScreen
                present(nav, animated: true)
            },
            makeRow(sfSymbol: "arrow.counterclockwise", title: "重置所有配额") { [weak self] in
                QuotaManager.shared.debugResetAllQuotas()
                let alert = UIAlertController(title: "已重置", message: "所有功能配额已归零", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好", style: .default))
                self?.present(alert, animated: true)
            },
            makeRow(sfSymbol: "star.bubble", title: "测试评分弹窗（可重复）") { [weak self] in
                UserDefaults.standard.removeObject(forKey: "rating_has_prompted")
                RatingManager.shared.presentSatisfactionSheet()
            },
        ])

        let container = UIStackView(arrangedSubviews: [header, card])
        container.axis = .vertical
        container.spacing = 6
        return container
    }

    private func makeDebugPremiumToggleRow() -> UIView {
        let row = UIView()

        let icon = UIImageView(image: UIImage(systemName: "crown.fill"))
        icon.tintColor = .systemOrange
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        icon.isUserInteractionEnabled = false

        let label = UILabel()
        label.text = "Premium 状态"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .appTextPrimary
        label.isUserInteractionEnabled = false

        let toggle = UISwitch()
        toggle.isOn = QuotaManager.shared.isPremium
        toggle.onTintColor = .systemOrange
        toggle.addTarget(self, action: #selector(debugPremiumToggled(_:)), for: .valueChanged)

        [icon, label, toggle].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }

        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),

            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
        ])

        return row
    }

    @objc private func debugPremiumToggled(_ sender: UISwitch) {
        QuotaManager.shared.debugSetPremium(sender.isOn)
        updateVIPCard()
    }
    #endif

    // MARK: - 高亮

    @objc private func rowHighlight(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1) {
            sender.backgroundColor = UIColor.black.withAlphaComponent(0.04)
        }
    }

    @objc private func rowUnhighlight(_ sender: UIControl) {
        UIView.animate(withDuration: 0.15) {
            sender.backgroundColor = .clear
        }
    }
}

// MARK: - ActionRow：持有点击闭包的 UIControl 子类

private class ActionRow: UIControl {
    private let action: (() -> Void)?
    init(action: (() -> Void)?) {
        self.action = action
        super.init(frame: .zero)
        addTarget(self, action: #selector(fired), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func fired() { action?() }
}

// MARK: - 渐变 frame 更新 View

private class GradientFrameUpdateView: UIView {
    private let gradientLayer: CAGradientLayer
    init(gradientLayer: CAGradientLayer) {
        self.gradientLayer = gradientLayer
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
