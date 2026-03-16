//
//  SettingsViewController.swift
//  Slidesh
//

import UIKit

class SettingsViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let cardRadius: CGFloat = 30
    private let rowHeight: CGFloat = 66
    private let sideInset: CGFloat = 20

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
        // 显式设置，确保 iOS 26 也能正确计算导航栏偏移
        scrollView.contentInsetAdjustmentBehavior = .always
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // scrollView 贴满整个 view
        // contentView 必须绑 contentLayoutGuide 才能驱动 contentSize，实现滚动
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // 宽度绑 frameLayoutGuide，确保横向不可滚动
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - 构建4个 Section

    private func buildSections() {
        // Section 1：会员横幅
        let vipCard = makeVIPCard()

        // Section 2：主题 + 切换应用图标
        let section2 = makeCard(rows: [
            makeRow(sfSymbol: "moon.circle.fill",  title: "主题",        accessory: makeThemeSwitch()),
            makeRow(sfSymbol: "square.grid.2x2",   title: "切换应用图标"),
        ])

        // Section 3：反馈 + 分享 + 恢复购买
        let section3 = makeCard(rows: [
            makeRow(sfSymbol: "envelope",                   title: "反馈"),
            makeRow(sfSymbol: "square.and.arrow.up",        title: "分享"),
            makeRow(sfSymbol: "arrow.clockwise.circle",     title: "恢复购买"),
        ])

        // Section 4：隐私政策 + 使用条款 + FAQ + 关于
        let section4 = makeCard(rows: [
            makeRow(sfSymbol: "hand.raised.fill",           title: "隐私政策"),
            makeRow(sfSymbol: "doc.text",                   title: "使用条款"),
            makeRow(sfSymbol: "questionmark.circle.fill",   title: "FAQ"),
            makeRow(sfSymbol: "info.circle.fill",           title: "关于"),
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

        // 深海军蓝渐变（参考截图：左上极深藏青 → 右下中蓝）
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.039, green: 0.094, blue: 0.260, alpha: 1).cgColor, // #0A1842 深藏青
            UIColor(red: 0.180, green: 0.380, blue: 0.720, alpha: 1).cgColor, // #2E61B8 中过渡蓝
            UIColor(red: 0.471, green: 0.710, blue: 0.953, alpha: 1).cgColor, // #78B5F3 亮天蓝
        ]
        gradient.locations = [0.0, 0.55, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint   = CGPoint(x: 1, y: 1)
        card.layer.insertSublayer(gradient, at: 0)

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "解锁 Pro 会员"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white

        // 功能列表
        let featuresLabel = UILabel()
        featuresLabel.text = "✓ 无限制导出演示文稿\n✓ 解锁全部模板\n✓ 高级格式转换"
        featuresLabel.font = .systemFont(ofSize: 14)
        featuresLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        featuresLabel.numberOfLines = 0

        // 解锁按钮
        let btn = UIButton(type: .system)
        btn.setTitle("立即解锁", for: .normal)
        btn.setTitleColor(.appPrimary, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 18, bottom: 6, right: 18)

        // 装饰图标：speak-ai-line，旋转 -25° 增加设计感
        let chevron = UIImageView(image: UIImage(named: "speak-ai-line")?
            .withRenderingMode(.alwaysTemplate))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.12)
        chevron.contentMode = .scaleAspectFit
        chevron.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 7.2) // -25°

        [titleLabel, featuresLabel, btn, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            featuresLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            featuresLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            featuresLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            btn.topAnchor.constraint(equalTo: featuresLabel.bottomAnchor, constant: 18),
            btn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            btn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),

            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            chevron.widthAnchor.constraint(equalToConstant: 100),
            chevron.heightAnchor.constraint(equalToConstant: 100),
        ])

        // 渐变层随卡片尺寸更新
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layoutIfNeeded()

        // 用 layoutSubviews 时机更新 gradient frame
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

    // MARK: - 通用白色卡片

    private func makeCard(rows: [UIView]) -> UIView {
        let card = UIView()
        card.backgroundColor = .appCardBackground.withAlphaComponent(0.7)
        card.layer.cornerRadius = cardRadius

        // 轻微阴影
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8

        var prev: UIView? = nil
        for (i, row) in rows.enumerated() {
            row.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(row)

            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: rowHeight),
            ])

            if let prev = prev {
                // 添加分割线
                let sep = makeSeparator()
                card.addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.topAnchor.constraint(equalTo: prev.bottomAnchor),
                    sep.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 52),
                    sep.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    sep.heightAnchor.constraint(equalToConstant: 0.5),
                    row.topAnchor.constraint(equalTo: sep.bottomAnchor),
                ])
            } else {
                row.topAnchor.constraint(equalTo: card.topAnchor).isActive = true
            }

            if i == rows.count - 1 {
                row.bottomAnchor.constraint(equalTo: card.bottomAnchor).isActive = true
            }

            prev = row
        }

        return card
    }

    // MARK: - 行视图

    private func makeRow(sfSymbol: String, title: String, accessory: UIView? = nil) -> UIView {
        let row = UIControl()
        row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)

        // 高亮效果
        row.addTarget(self, action: #selector(rowHighlight(_:)), for: .touchDown)
        row.addTarget(self, action: #selector(rowUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        // 图标
        let icon = UIImageView(image: UIImage(systemName: sfSymbol))
        icon.tintColor = .appTextSecondary
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        // 标题
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16)
        label.textColor = .appTextPrimary

        // 右侧 accessory（默认为 chevron）
        let rightView: UIView = accessory ?? {
            let img = UIImageView(image: UIImage(systemName: "chevron.right"))
            img.tintColor = .appTextTertiary
            img.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            img.contentMode = .scaleAspectFit
            return img
        }()

        [icon, label, rightView].forEach {
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
            label.trailingAnchor.constraint(lessThanOrEqualTo: rightView.leadingAnchor, constant: -8),

            rightView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rightView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
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

    // MARK: - 主题切换开关

    private func makeThemeSwitch() -> UIView {
        let sw = UISwitch()
        sw.onTintColor = .appPrimary
        // 根据当前 window 样式初始化状态
        sw.isOn = (view.window?.overrideUserInterfaceStyle == .dark)
        sw.addTarget(self, action: #selector(themeSwitchChanged(_:)), for: .valueChanged)
        return sw
    }

    // MARK: - 交互事件

    @objc private func rowTapped(_ sender: UIControl) {
        // 各行点击后续接业务逻辑
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

    @objc private func themeSwitchChanged(_ sender: UISwitch) {
        guard let window = view.window else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.overrideUserInterfaceStyle = sender.isOn ? .dark : .light
        }
    }
}

// MARK: - 辅助：跟随 Auto Layout 更新渐变 frame 的透明 View

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
