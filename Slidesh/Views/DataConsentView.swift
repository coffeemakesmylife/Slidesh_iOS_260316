//
//  DataConsentView.swift
//  Slidesh
//
//  数据处理同意弹窗：文件转换上传前 + AI 生成前展示，App Store 审核合规
//

import UIKit
import SafariServices

// MARK: - DataConsentManager

/// 用户数据处理同意状态管理
class DataConsentManager {
    static let shared = DataConsentManager()
    private let consentKey = "slidesh.dataConsentAccepted"
    private init() {}

    /// 用户是否已同意数据处理条款
    var hasConsented: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    /// 记录用户同意
    func recordConsent() {
        UserDefaults.standard.set(true, forKey: consentKey)
        UserDefaults.standard.synchronize()
    }
}

// MARK: - DataConsentView

/// 数据处理同意弹窗，覆盖于父视图之上
class DataConsentView: UIView {

    // MARK: - 回调

    /// 用户点击「同意并继续」
    var onConsent: (() -> Void)?
    /// 用户最终确认不同意
    var onDecline: (() -> Void)?

    // MARK: - UI

    private let overlayView    = UIView()
    private let cardView       = UIView()
    private let scrollView     = UIScrollView()
    private let contentStack   = UIStackView()
    private let iconView       = UIImageView()
    private let titleLabel     = UILabel()
    private let subtitleLabel  = UILabel()
    private let agreeButton   = UIButton(type: .system)
    private let declineButton = UIButton(type: .system)
    private lazy var linkTextView = buildLinkTextView()

    private weak var parentVC: UIViewController?

    // MARK: - 初始化

    init(parentVC: UIViewController) {
        self.parentVC = parentVC
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 展示 / 隐藏

    func showInView(_ superview: UIView) {
        frame = superview.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        superview.addSubview(self)

        overlayView.alpha = 0
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.overlayView.alpha = 1
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    private func dismissWithAnimation(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.22, animations: {
            self.overlayView.alpha = 0
            self.cardView.alpha = 0
            self.cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    // MARK: - 按钮事件

    @objc private func agreeTapped() {
        DataConsentManager.shared.recordConsent()
        dismissWithAnimation { self.onConsent?() }
    }

    @objc private func declineTapped() {
        guard let vc = parentVC else { return }
        let alert = UIAlertController(
            title: "无法继续",
            message: "不同意数据处理条款将无法使用文件转换和 AI 生成功能。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确认不使用", style: .destructive) { [weak self] _ in
            self?.dismissWithAnimation { self?.onDecline?() }
        })
        alert.addAction(UIAlertAction(title: "重新查看", style: .cancel))
        vc.present(alert, animated: true)
    }

    // MARK: - UI 搭建

    private func setupUI() {
        // 半透明遮罩
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlayView)

        // 卡片
        cardView.backgroundColor = .appCardBackground
        cardView.layer.cornerRadius = 24
        cardView.layer.shadowColor   = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.2
        cardView.layer.shadowOffset  = CGSize(width: 0, height: 6)
        cardView.layer.shadowRadius  = 20
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // 滚动区域
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(scrollView)

        // 内容栈
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // 图标
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        iconView.image = UIImage(systemName: "lock.shield.fill", withConfiguration: iconConfig)
        iconView.tintColor = .appGradientMid
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // 标题
        titleLabel.text = "数据处理说明"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // 副标题
        subtitleLabel.text = "在使用文件转换和 AI 生成功能前，请了解我们如何处理您的文件和数据"
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .appTextSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(makeSeparator())

        // 各说明区块
        contentStack.addArrangedSubview(makeSection(
            sfSymbol: "arrow.up.doc",
            title: "我们会处理哪些内容",
            items: [
                "您选择上传的文档文件（PDF、Word、Excel、PPT 等），仅用于本次格式转换",
                "用于 AI 生成 PPT 的主题文字及相关描述信息",
                "文件处理完成后即从服务器删除，不做任何形式的留存"
            ]
        ))

        contentStack.addArrangedSubview(makeSection(
            sfSymbol: "lock.shield",
            title: "数据安全保障",
            items: [
                "所有文件上传与下载均通过 HTTPS 加密传输，防止中间人截取",
                "您的文件不会被用于训练 AI 模型，也不会与任何第三方共享",
                "我们不收集文件内容用于广告或分析，文件数据与账号信息严格隔离"
            ]
        ))

        contentStack.addArrangedSubview(makeSection(
            sfSymbol: "sparkles",
            title: "AI 功能使用须知",
            items: [
                "AI 根据您输入的主题自动生成 PPT 内容，生成结果因主题而异",
                "AI 生成内容可能存在不准确之处，请在正式使用前自行核对审阅",
                "AI 生成的内容版权归您所有，本应用不对生成结果的具体用途负责"
            ]
        ))

        contentStack.addArrangedSubview(makeSection(
            sfSymbol: "exclamationmark.triangle",
            title: "免责声明",
            items: [
                "文件格式转换由服务器处理，转换效果可能因文件复杂度、排版等因素有所差异",
                "请确保您对所上传的文件拥有合法使用权，不得上传涉及版权争议的内容",
                "本应用转换及生成结果仅供参考，用户应自行承担使用风险"
            ]
        ))

        contentStack.addArrangedSubview(makeSeparator())
        contentStack.addArrangedSubview(linkTextView)

        // 同意按钮：主题色背景
        agreeButton.setTitle("同意并继续", for: .normal)
        agreeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        agreeButton.setTitleColor(.white, for: .normal)
        agreeButton.backgroundColor = .appGradientMid
        agreeButton.layer.cornerRadius = 22
        agreeButton.clipsToBounds = true
        agreeButton.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        agreeButton.translatesAutoresizingMaskIntoConstraints = false

        declineButton.setTitle("不同意", for: .normal)
        declineButton.titleLabel?.font = .systemFont(ofSize: 14)
        declineButton.setTitleColor(.appTextSecondary, for: .normal)
        declineButton.addTarget(self, action: #selector(declineTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [agreeButton, declineButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            // 遮罩全屏
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 卡片居中，最高 72% 屏高
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            cardView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.72),

            // 滚动区
            scrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -12),

            // 内容栈撑开 scrollView contentSize
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            iconView.heightAnchor.constraint(equalToConstant: 38),

            // 按钮区
            buttonStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),

            agreeButton.heightAnchor.constraint(equalToConstant: 44),

            declineButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        // 低优先级：内容不超出时 scrollView 高度等于内容高度（无需滚动）
        let noScrollConstraint = scrollView.heightAnchor.constraint(
            equalTo: scrollView.contentLayoutGuide.heightAnchor
        )
        noScrollConstraint.priority = .defaultLow
        noScrollConstraint.isActive = true
    }

    // MARK: - 辅助构建

    private func makeSection(sfSymbol: String, title: String, items: [String]) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 6
        titleRow.alignment = .center

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: sfSymbol, withConfiguration: iconConfig))
        iconView.tintColor = .appGradientMid
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLbl.textColor = .appTextPrimary

        titleRow.addArrangedSubview(iconView)
        titleRow.addArrangedSubview(titleLbl)
        container.addArrangedSubview(titleRow)

        for item in items {
            let lbl = UILabel()
            lbl.text = "  •  \(item)"
            lbl.font = .systemFont(ofSize: 11.5)
            lbl.textColor = .appTextSecondary
            lbl.numberOfLines = 0
            container.addArrangedSubview(lbl)
        }
        return container
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = UIColor.appCardBorder.withAlphaComponent(0.5)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return sep
    }

    private func buildLinkTextView() -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = self

        let full     = "继续使用即表示您同意我们的用户协议和隐私政策"
        let terms    = "用户协议"
        let privacy  = "隐私政策"

        let attr = NSMutableAttributedString(string: full, attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.appTextSecondary
        ])
        if let r = full.range(of: terms) {
            attr.addAttributes([.link: "https://docs.google.com/document/d/1KxSeuHffh0ko6f22XIyO_DLYrajOdtfpi0mWzRY4GYw/edit?usp=sharing",
                                 .foregroundColor: UIColor.appGradientMid], range: NSRange(r, in: full))
        }
        if let r = full.range(of: privacy) {
            attr.addAttributes([.link: "https://docs.google.com/document/d/10jQz1h_h5Sj5OSdnDRME86BdRCKg-1o9y03ndZIXAdg/edit?usp=sharing",
                                 .foregroundColor: UIColor.appGradientMid], range: NSRange(r, in: full))
        }
        tv.attributedText = attr
        tv.textAlignment = .center
        tv.linkTextAttributes = [
            .foregroundColor: UIColor.appGradientMid,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return tv
    }
}

// MARK: - UITextViewDelegate（链接在应用内打开）

extension DataConsentView: UITextViewDelegate {
    func textView(_ textView: UITextView,
                  shouldInteractWith URL: URL,
                  in characterRange: NSRange,
                  interaction: UITextItemInteraction) -> Bool {
        guard let vc = parentVC else { return true }
        vc.present(SFSafariViewController(url: URL), animated: true)
        return false
    }
}
