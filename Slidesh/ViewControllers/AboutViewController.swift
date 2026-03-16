//
//  AboutViewController.swift
//  Slidesh
//

import UIKit
import SafariServices

class AboutViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "关于"
        addMeshGradientBackground()
        setupUI()
    }

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .always
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        // 应用图标
        let iconView = UIImageView(image: UIImage(named: "AppIcon"))
        iconView.layer.cornerRadius = 22
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        iconView.layer.borderWidth = 0.5
        iconView.layer.borderColor = UIColor.appCardBorder.cgColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // 应用名
        let nameLabel = UILabel()
        nameLabel.text = "Slidesh"
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = .appTextPrimary
        nameLabel.textAlignment = .center

        // 版本号
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = UILabel()
        versionLabel.text = "版本 \(version) (\(build))"
        versionLabel.font = .systemFont(ofSize: 13)
        versionLabel.textColor = .appTextTertiary
        versionLabel.textAlignment = .center

        // 简介
        let descLabel = UILabel()
        descLabel.text = "Slidesh 是一款 AI 驱动的演示文稿工具，帮助你快速生成、编辑和分享精美幻灯片。"
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .appTextSecondary
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0

        // 信息卡片
        let infoCard = makeInfoCard(rows: [
            ("globe", "官方网站", { [weak self] in self?.openURL("https://example.com") }),
            ("envelope", "联系我们", { [weak self] in self?.openURL("mailto:hello@slidesh.app") }),
            ("star.fill", "给我们评分", { self.rateApp() }),
        ])

        // 版权
        let copyrightLabel = UILabel()
        copyrightLabel.text = "© 2026 Slidesh. All rights reserved."
        copyrightLabel.font = .systemFont(ofSize: 12)
        copyrightLabel.textColor = .appTextTertiary
        copyrightLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [
            iconView, nameLabel, versionLabel, descLabel, infoCard, copyrightLabel
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.setCustomSpacing(6, after: nameLabel)
        stack.setCustomSpacing(20, after: versionLabel)
        stack.setCustomSpacing(24, after: descLabel)
        stack.setCustomSpacing(32, after: infoCard)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 88),
            iconView.heightAnchor.constraint(equalToConstant: 88),

            infoCard.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 20),
            infoCard.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -20),

            descLabel.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 32),
            descLabel.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -32),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -40),
        ])
    }

    // MARK: - 信息卡片

    private func makeInfoCard(rows: [(String, String, () -> Void)]) -> UIView {
        let card = UIView()
        card.backgroundColor = .appCardBackground.withAlphaComponent(0.7)
        card.layer.cornerRadius = 22
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6

        var prev: UIView?
        for (i, row) in rows.enumerated() {
            let rowView = makeRow(sfSymbol: row.0, title: row.1, action: row.2)
            rowView.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(rowView)
            NSLayoutConstraint.activate([
                rowView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                rowView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                rowView.heightAnchor.constraint(equalToConstant: 56),
            ])
            if let prev = prev {
                let sep = UIView()
                sep.backgroundColor = .appSeparator
                sep.translatesAutoresizingMaskIntoConstraints = false
                card.addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.topAnchor.constraint(equalTo: prev.bottomAnchor),
                    sep.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 52),
                    sep.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    sep.heightAnchor.constraint(equalToConstant: 0.5),
                    rowView.topAnchor.constraint(equalTo: sep.bottomAnchor),
                ])
            } else {
                rowView.topAnchor.constraint(equalTo: card.topAnchor).isActive = true
            }
            if i == rows.count - 1 {
                rowView.bottomAnchor.constraint(equalTo: card.bottomAnchor).isActive = true
            }
            prev = rowView
        }
        return card
    }

    private func makeRow(sfSymbol: String, title: String, action: @escaping () -> Void) -> UIView {
        let row = AboutActionRow(action: action)

        let icon = UIImageView(image: UIImage(systemName: sfSymbol))
        icon.tintColor = .appTextSecondary
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15)
        label.textColor = .appTextPrimary

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .appTextTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevron.contentMode = .scaleAspectFit

        [icon, label, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
            row.addSubview($0)
        }
        NSLayoutConstraint.activate([
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),

            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
        ])
        return row
    }

    // MARK: - 动作

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        if urlString.hasPrefix("http") {
            present(SFSafariViewController(url: url), animated: true)
        } else {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        // 替换为实际 App Store ID
        if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// 持有 action 闭包的行控件
private class AboutActionRow: UIControl {
    private let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        addTarget(self, action: #selector(fire), for: .touchUpInside)
        addTarget(self, action: #selector(highlight), for: .touchDown)
        addTarget(self, action: #selector(unhighlight), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func fire() { action() }
    @objc private func highlight() {
        UIView.animate(withDuration: 0.1) { self.backgroundColor = UIColor.black.withAlphaComponent(0.04) }
    }
    @objc private func unhighlight() {
        UIView.animate(withDuration: 0.15) { self.backgroundColor = .clear }
    }
}
