//
//  SatisfactionSheet.swift
//  Slidesh
//
//  满意度调查底部弹窗，直接挂载到 UIWindow，无需 presenting VC
//

import UIKit

final class SatisfactionSheet: UIView {

    // MARK: - 回调

    var onPositive: (() -> Void)?
    var onNegative: (() -> Void)?

    // MARK: - 子视图

    private let dimView      = UIView()
    private let cardView     = UIView()
    private var starViews:   [UIImageView] = []
    private let positiveBtn  = UIButton(type: .custom)
    private let negativeBtn  = UIButton(type: .system)

    // 防止双击重复触发
    private var hasHandledAction = false

    // 渐变图层（positive 按钮背景 + icon 卡片）
    private var positiveBtnGradient: CAGradientLayer?
    private var iconCardGradient:    CAGradientLayer?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 布局

    private func setupViews() {
        // 遮罩
        dimView.backgroundColor = .appOverlay
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))

        // 卡片（仅上方两角圆角）
        cardView.backgroundColor = .appBackgroundTertiary
        cardView.layer.cornerRadius = 24
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // ---- 卡片内容 ----

        // 拖拽指示条
        let pill = UIView()
        pill.backgroundColor = UIColor.appTextPrimary.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 2
        pill.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(pill)

        // App 图标卡片（圆角矩形 + 紫蓝渐变）
        let iconCard = UIView()
        iconCard.layer.cornerRadius = 20
        iconCard.layer.masksToBounds = true
        iconCard.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconCard)

        let iconGrad = CAGradientLayer()
        iconGrad.colors = [
            UIColor.appGradientStart.cgColor,
            UIColor.appGradientEnd.cgColor
        ]
        iconGrad.startPoint = CGPoint(x: 0, y: 0)
        iconGrad.endPoint   = CGPoint(x: 1, y: 1)
        iconCard.layer.insertSublayer(iconGrad, at: 0)
        iconCardGradient = iconGrad

        let iconImage = UIImageView(image: UIImage(systemName: "wand.and.stars"))
        iconImage.tintColor       = .white
        iconImage.contentMode     = .scaleAspectFit
        iconImage.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .medium)
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconCard.addSubview(iconImage)

        // 星星行（5个，初始灰色小尺寸，动画弹入后变金色大尺寸）
        let starStack = UIStackView()
        starStack.axis    = .horizontal
        starStack.spacing = 10
        starStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(starStack)

        for _ in 0 ..< 5 {
            let sv = UIImageView(image: UIImage(systemName: "star.fill"))
            sv.tintColor  = .appTextTertiary
            sv.transform  = CGAffineTransform(scaleX: 0.7, y: 0.7)
            sv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
            sv.translatesAutoresizingMaskIntoConstraints = false
            starStack.addArrangedSubview(sv)
            starViews.append(sv)
        }

        // 标题（动态读取 App 显示名，避免硬编码）
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Slidesh"
        let titleLabel = UILabel()
        titleLabel.text          = "\(appName) 帮到你了吗？"
        titleLabel.font          = .systemFont(ofSize: 22, weight: .black)
        titleLabel.textColor     = .appTextPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // 正向按钮（渐变背景）
        positiveBtn.setTitle("帮到了，好评", for: .normal)
        positiveBtn.setTitleColor(.appOnPrimary, for: .normal)
        positiveBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        positiveBtn.layer.cornerRadius = 26
        positiveBtn.layer.masksToBounds = true
        positiveBtn.translatesAutoresizingMaskIntoConstraints = false
        positiveBtn.addTarget(self, action: #selector(positiveTapped), for: .touchUpInside)
        cardView.addSubview(positiveBtn)

        let posGrad = CAGradientLayer()
        posGrad.colors     = [UIColor.appGradientStart.cgColor,
                               UIColor.appGradientMid.cgColor,
                               UIColor.appGradientEnd.cgColor]
        posGrad.locations  = [0.0, 0.55, 1.0]
        posGrad.startPoint = CGPoint(x: 0, y: 0)
        posGrad.endPoint   = CGPoint(x: 1, y: 1)
        positiveBtn.layer.insertSublayer(posGrad, at: 0)
        positiveBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        positiveBtn.layer.borderWidth = 1.5
        positiveBtnGradient = posGrad

        // 负向按钮（灰色文字）
        negativeBtn.setTitle("有建议，说一下", for: .normal)
        negativeBtn.setTitleColor(.appTextSecondary, for: .normal)
        negativeBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        negativeBtn.translatesAutoresizingMaskIntoConstraints = false
        negativeBtn.addTarget(self, action: #selector(negativeTapped), for: .touchUpInside)
        cardView.addSubview(negativeBtn)

        // ---- 约束 ----

        NSLayoutConstraint.activate([
            // 遮罩撑满
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // 卡片底部对齐
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 拖拽指示条
            pill.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            pill.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            pill.widthAnchor.constraint(equalToConstant: 36),
            pill.heightAnchor.constraint(equalToConstant: 4),

            // 图标卡片
            iconCard.topAnchor.constraint(equalTo: pill.bottomAnchor, constant: 28),
            iconCard.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconCard.widthAnchor.constraint(equalToConstant: 80),
            iconCard.heightAnchor.constraint(equalToConstant: 80),

            // 图标 image 居中
            iconImage.centerXAnchor.constraint(equalTo: iconCard.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconCard.centerYAnchor),

            // 星星行
            starStack.topAnchor.constraint(equalTo: iconCard.bottomAnchor, constant: 20),
            starStack.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            // 标题
            titleLabel.topAnchor.constraint(equalTo: starStack.bottomAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            // 正向按钮
            positiveBtn.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            positiveBtn.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            positiveBtn.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            positiveBtn.heightAnchor.constraint(equalToConstant: 54),

            // 负向按钮
            negativeBtn.topAnchor.constraint(equalTo: positiveBtn.bottomAnchor, constant: 4),
            negativeBtn.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            negativeBtn.heightAnchor.constraint(equalToConstant: 44),
            negativeBtn.bottomAnchor.constraint(equalTo: cardView.safeAreaLayoutGuide.bottomAnchor, constant: -4),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 渐变图层随 bounds 更新
        positiveBtnGradient?.frame = positiveBtn.bounds
        iconCardGradient?.frame    = CGRect(origin: .zero, size: CGSize(width: 80, height: 80))
    }

    // MARK: - 显示 / 隐藏

    /// 挂载到 window 并执行进场动画
    func show(in window: UIWindow) {
        frame = window.bounds
        window.addSubview(self)

        // 先完成 Auto Layout，确保所有子视图 frame 已确定
        layoutIfNeeded()
        // 渐变图层 frame 需要在 layout 后才能拿到正确尺寸
        positiveBtnGradient?.frame = positiveBtn.bounds
        iconCardGradient?.frame    = CGRect(origin: .zero, size: CGSize(width: 80, height: 80))

        let slideOffset = cardView.bounds.height
        cardView.transform = CGAffineTransform(translationX: 0, y: slideOffset)

        UIView.animate(withDuration: 0.45, delay: 0,
                       usingSpringWithDamping: 0.78, initialSpringVelocity: 0.2,
                       options: [.allowUserInteraction], animations: {
            self.dimView.alpha      = 1
            self.cardView.transform = .identity
        })

        // 星星依次弹入
        for (i, star) in starViews.enumerated() {
            UIView.animate(withDuration: 0.3, delay: 0.2 + Double(i) * 0.07,
                           usingSpringWithDamping: 0.55, initialSpringVelocity: 0,
                           options: [], animations: {
                star.tintColor = UIColor(red: 1, green: 184/255, blue: 0, alpha: 1)
                star.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
            })
        }
    }

    /// 退场动画后移除
    func dismiss() {
        let slideOffset = cardView.bounds.height
        UIView.animate(withDuration: 0.28, delay: 0,
                       usingSpringWithDamping: 1.0, initialSpringVelocity: 0,
                       options: [], animations: {
            self.dimView.alpha      = 0
            self.cardView.transform = CGAffineTransform(translationX: 0, y: slideOffset)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    // MARK: - Actions

    @objc private func dimTapped() {
        guard !hasHandledAction else { return }
        dismiss()
    }

    @objc private func positiveTapped() {
        guard !hasHandledAction else { return }
        hasHandledAction = true

        // 0.4s 高亮 feedback 后回调
        UIView.animate(withDuration: 0.15, animations: {
            self.positiveBtn.alpha = 0.6
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) { self.positiveBtn.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.dismiss()
                self?.onPositive?()
            }
        })
    }

    @objc private func negativeTapped() {
        guard !hasHandledAction else { return }
        hasHandledAction = true

        UIView.animate(withDuration: 0.15, animations: {
            self.negativeBtn.alpha = 0.4
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) { self.negativeBtn.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.dismiss()
                self?.onNegative?()
            }
        })
    }
}
