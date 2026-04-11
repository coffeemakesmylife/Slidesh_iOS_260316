//
//  PaywallSheet.swift
//  Slidesh
//
//  极简半屏付费墙：权益轮播 + 跳转订阅页
//

import UIKit

class PaywallSheet: UIViewController {

    // 购买成功后由外部调用方提供，PaywallSheet 在 PremiumVC 回调后触发
    var onPurchased: (() -> Void)?

    // MARK: - UI

    private let titleLabel    = UILabel()
    private let benefitLabel  = UILabel()
    private let upgradeButton = UIButton(type: .system)

    // 权益文案轮播
    private let benefits = [
        NSLocalizedString("✓  AI 大纲无限次生成", comment: ""),
        NSLocalizedString("✓  格式转换无限次使用", comment: ""),
        NSLocalizedString("✓  一键生成完整 PPT", comment: ""),
    ]
    private var benefitIndex = 0
    private var rotationTimer: Timer?

    // MARK: - 静态展示入口

    /// 从指定 VC 弹出 PaywallSheet；购买成功后调用 onPurchased
    static func show(from presentingVC: UIViewController, onPurchased: @escaping () -> Void) {
        let sheet = PaywallSheet()
        sheet.onPurchased = onPurchased
        sheet.modalPresentationStyle = .pageSheet
        if let sheetController = sheet.sheetPresentationController {
            // 固定高度约 220pt
            if #available(iOS 16.0, *) {
                let detent = UISheetPresentationController.Detent.custom { _ in 220 }
                sheetController.detents = [detent]
            } else {
                sheetController.detents = [.medium()]
            }
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        presentingVC.present(sheet, animated: true)
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appCardBackground
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startBenefitRotation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    // MARK: - UI 搭建

    private func setupUI() {
        // 标题
        titleLabel.text = NSLocalizedString("解锁 ", comment: "") + "\(AppConfig.appName) Pro"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // 权益轮播文字
        benefitLabel.text = benefits[0]
        benefitLabel.font = .systemFont(ofSize: 15, weight: .medium)
        benefitLabel.textColor = .appGradientMid
        benefitLabel.textAlignment = .center
        benefitLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(benefitLabel)

        // 升级按钮
        upgradeButton.setTitle(NSLocalizedString("查看升级计划  →", comment: ""), for: .normal)
        upgradeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        upgradeButton.setTitleColor(.white, for: .normal)
        upgradeButton.backgroundColor = .appGradientMid
        upgradeButton.layer.cornerRadius = 28
        upgradeButton.clipsToBounds = true
        upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
        upgradeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(upgradeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            benefitLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            benefitLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            benefitLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            upgradeButton.topAnchor.constraint(equalTo: benefitLabel.bottomAnchor, constant: 24),
            upgradeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            upgradeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            upgradeButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    // MARK: - 权益轮播

    private func startBenefitRotation() {
        // 防止 viewWillAppear 多次触发时重复注册 Timer
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.rotateBenefit()
        }
    }

    private func rotateBenefit() {
        benefitIndex = (benefitIndex + 1) % benefits.count
        UIView.transition(with: benefitLabel, duration: 0.4,
                          options: .transitionCrossDissolve) { [weak self] in
            guard let self else { return }
            self.benefitLabel.text = self.benefits[self.benefitIndex]
        }
    }

    // MARK: - 按钮事件

    @objc private func upgradeTapped() {
        let premiumVC = PremiumViewController()
        // 链路：PremiumVC.dismiss（关闭 nav）→ callback 触发 →
        //        PaywallSheet.dismiss（关闭 self）→ onPurchased（继续原操作）
        // 此处 [weak self] 捕获 PaywallSheet；callback 触发时 nav 已关闭，
        // self（PaywallSheet）仍在屏幕上，dismiss 正确关闭 PaywallSheet 自身
        premiumVC.onPurchased = { [weak self] in
            self?.dismiss(animated: true) {
                self?.onPurchased?()
            }
        }
        let nav = UINavigationController(rootViewController: premiumVC)
        present(nav, animated: true)
    }
}
