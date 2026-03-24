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

        let stack = UIStackView(arrangedSubviews: [vipCard, section2, section3, section4])
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

        let titleLabel = UILabel()
        titleLabel.text = "解锁 Pro 会员"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white

        let featuresLabel = UILabel()
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.paragraphSpacing = 8
        featuresLabel.attributedText = NSAttributedString(
            string: "✓ 无限制创建演示文稿\n✓ 无限制高级格式转换\n✓ 解锁全部模板",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .paragraphStyle: paraStyle,
            ])
        featuresLabel.numberOfLines = 0

        let btn = UIButton(type: .system)
        btn.setTitle("立即解锁", for: .normal)
        btn.setTitleColor(.appPrimary, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 18, bottom: 6, right: 18)
        btn.addTarget(self, action: #selector(unlockPro), for: .touchUpInside)

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
        let alert = UIAlertController(title: "切换应用图标", message: "该功能即将推出", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 高亮

    @objc private func unlockPro() {
        let vc = PremiumViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

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
