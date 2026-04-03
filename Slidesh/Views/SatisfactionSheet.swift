//
//  SatisfactionSheet.swift
//  Slidesh
//
//  满意度调查底部半屏弹窗，iOS 26 风格：系统 sheet 呈现，背景透明展示后方内容
//

import UIKit

final class SatisfactionSheet: UIViewController {

    // MARK: - 回调

    var onPositive: (() -> Void)?
    var onNegative: (() -> Void)?

    // 防止双击重复触发
    private var hasHandledAction = false

    // MARK: - Init / 呈现

    /// 从 topViewController 呈现 SatisfactionSheet
    static func present(onPositive: (() -> Void)?, onNegative: (() -> Void)?) {
        guard let topVC = topViewController() else { return }
        let sheet = SatisfactionSheet()
        sheet.onPositive = onPositive
        sheet.onNegative = onNegative
        sheet.modalPresentationStyle = .pageSheet
        if let ctrl = sheet.sheetPresentationController {
            if #available(iOS 16.0, *) {
                let detent = UISheetPresentationController.Detent.custom { _ in 300 }
                ctrl.detents = [detent]
            } else {
                ctrl.detents = [.medium()]
            }
            ctrl.prefersGrabberVisible  = false
            ctrl.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        topVC.present(sheet, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        guard var top = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        // 透明底，毛玻璃由系统 sheet 背景提供
        view.backgroundColor = .clear
        setupUI()
    }

    // MARK: - 布局

    private func setupUI() {
        // 毛玻璃背景层
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 拖拽指示条
        let pill = UIView()
        pill.backgroundColor = UIColor.label.withAlphaComponent(0.18)
        pill.layer.cornerRadius = 2
        pill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pill)

        // 当前 App 图标（使用 AppIconManager 获取预览图，无图则降级为渐变）
        let iconContainer = makeIconView()

        // 标题
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? AppConfig.appName
        let titleLabel = UILabel()
        titleLabel.text          = "\(appName) 帮到你了吗？"
        titleLabel.font          = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor     = .label
        titleLabel.textAlignment = .center

        // 副标题
        let subtitleLabel = UILabel()
        subtitleLabel.text          = "你的反馈帮助我们持续改进"
        subtitleLabel.font          = .systemFont(ofSize: 15)
        subtitleLabel.textColor     = .secondaryLabel
        subtitleLabel.textAlignment = .center

        // 按钮行
        let thumbDown = makeThumbButton(positive: false)
        let thumbUp   = makeThumbButton(positive: true)
        let buttonRow = UIStackView(arrangedSubviews: [thumbDown, thumbUp])
        buttonRow.axis    = .horizontal
        buttonRow.spacing = 48
        buttonRow.alignment = .center

        // 主 StackView
        let stack = UIStackView(arrangedSubviews: [
            iconContainer, titleLabel, subtitleLabel, buttonRow
        ])
        stack.axis      = .vertical
        stack.alignment = .center
        stack.spacing   = 12
        stack.setCustomSpacing(20, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            // 拖拽条
            pill.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            pill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pill.widthAnchor.constraint(equalToConstant: 36),
            pill.heightAnchor.constraint(equalToConstant: 4),

            // 图标尺寸
            iconContainer.widthAnchor.constraint(equalToConstant: 80),
            iconContainer.heightAnchor.constraint(equalToConstant: 80),

            // 按钮尺寸
            thumbDown.widthAnchor.constraint(equalToConstant: 100),
            thumbDown.heightAnchor.constraint(equalToConstant: 100),
            thumbUp.widthAnchor.constraint(equalToConstant: 100),
            thumbUp.heightAnchor.constraint(equalToConstant: 100),

            // stack 位置
            stack.topAnchor.constraint(equalTo: pill.bottomAnchor, constant: 20),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    // 当前选中 app 图标，无法读取时展示渐变兜底
    private func makeIconView() -> UIView {
        let container = UIView()
        container.layer.cornerRadius = 20
        container.layer.masksToBounds = true

        // 渐变兜底
        let grad = CAGradientLayer()
        grad.colors     = [UIColor.appGradientStart.cgColor, UIColor.appGradientEnd.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint   = CGPoint(x: 1, y: 1)
        grad.frame      = CGRect(x: 0, y: 0, width: 80, height: 80)
        container.layer.insertSublayer(grad, at: 0)

        // 尝试读取当前 app icon
        let currentID = UIApplication.shared.alternateIconName
        let entries   = AppIconManager.shared.icons
        if let entry = entries.first(where: { $0.identifier == currentID })
            ?? entries.first,
           let img = AppIconManager.shared.previewImage(for: entry) {
            let iv = UIImageView(image: img)
            iv.contentMode = .scaleAspectFill
            iv.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: container.topAnchor),
                iv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                iv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            grad.isHidden = true
        }

        return container
    }

    // 大圆形拇指按钮
    private func makeThumbButton(positive: Bool) -> UIButton {
        let btn = ThumbButton(type: .custom)
        btn.isPositive = positive
        let symbolName = positive ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        btn.setImage(UIImage(systemName: symbolName, withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.label          // 自动深浅模式
        btn.layer.cornerRadius = 50
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(thumbTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - 按钮事件

    @objc private func thumbTapped(_ sender: UIButton) {
        guard !hasHandledAction else { return }
        hasHandledAction = true
        let isPositive = (sender as? ThumbButton)?.isPositive ?? false

        // 弹跳动画
        UIView.animate(withDuration: 0.08, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }, completion: { _ in
            UIView.animate(withDuration: 0.35,
                           delay: 0,
                           usingSpringWithDamping: 0.45,
                           initialSpringVelocity: 0) {
                sender.transform = .identity
            }
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.dismiss(animated: true) {
                if isPositive {
                    self?.onPositive?()
                } else {
                    self?.onNegative?()
                }
            }
        }
    }
}

// 携带 isPositive 标记的按钮子类
private final class ThumbButton: UIButton {
    var isPositive = false
}
