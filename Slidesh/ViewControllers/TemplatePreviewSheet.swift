//
//  TemplatePreviewSheet.swift
//  Slidesh
//
//  模板预览底部弹窗：封面图（16:9）+ 名称 + 标签 + "使用此模板"按钮
//

import UIKit
import Kingfisher

class TemplatePreviewSheet: UIViewController {

    // MARK: - 回调

    /// 用户点击"使用此模板"时触发
    var onUse: (() -> Void)?

    // MARK: - 数据

    private let template: PPTTemplate

    // MARK: - 子视图

    private let coverImageView = UIImageView()
    private weak var useButton: UIButton?
    private var gradientLayer: CAGradientLayer?

    // MARK: - Init

    init(template: PPTTemplate) {
        self.template = template
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 按钮 bounds 确定后更新渐变 frame
        if let btn = useButton {
            gradientLayer?.frame = btn.bounds
        }
    }

    // MARK: - 视图搭建

    private func setupViews() {
        // 封面图（16:9 比例）
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = 12
        coverImageView.backgroundColor = .appChipUnselectedBackground
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coverImageView)

        // 模板标题
        let titleLabel = UILabel()
        titleLabel.text = template.subject
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // 标签行（页数 / 场景 / 风格）
        let tagsStack = UIStackView()
        tagsStack.axis = .horizontal
        tagsStack.spacing = 8
        tagsStack.alignment = .center
        tagsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tagsStack)

        let tagTexts: [String] = [
            template.num > 0 ? "\(template.num)页" : "",
            template.category,
            template.style,
        ].filter { !$0.isEmpty }

        for text in tagTexts {
            tagsStack.addArrangedSubview(makePill(text))
        }
        // 弹簧让标签靠左
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tagsStack.addArrangedSubview(spacer)

        // "使用此模板"渐变按钮
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("使用此模板", comment: ""), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.layer.cornerRadius = 22
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(useTapped), for: .touchUpInside)

        let grad = CAGradientLayer()
        grad.colors = [
            UIColor.appGradientStart.cgColor,
            UIColor.appGradientMid.cgColor,
            UIColor.appGradientEnd.cgColor,
        ]
        grad.locations = [0.0, 0.5, 1.0]
        grad.startPoint = CGPoint(x: 0, y: 0.5)
        grad.endPoint   = CGPoint(x: 1, y: 0.5)
        btn.layer.insertSublayer(grad, at: 0)
        gradientLayer = grad
        useButton = btn
        view.addSubview(btn)

        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            coverImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            coverImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            // 16:9 宽高比
            coverImageView.heightAnchor.constraint(equalTo: coverImageView.widthAnchor, multiplier: 9.0 / 16.0),

            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tagsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tagsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tagsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            btn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            btn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            btn.heightAnchor.constraint(equalToConstant: 54),
        ])

        // 加载封面图
        if let url = template.coverImageURL {
            coverImageView.kf.setImage(with: url, options: [.transition(.fade(0.2)), .cacheOriginalImage])
        }
    }

    // MARK: - 辅助

    private func makePill(_ text: String) -> TagPillView {
        let pill = TagPillView(title: text)
        return pill
    }

    // MARK: - Action

    @objc private func useTapped() {
        onUse?()
    }
}

// MARK: - TagPillView（与 CategoryChipButton 未选中态风格一致）

private class TagPillView: UIView {

    private let label = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        label.text = title
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = 15
        clipsToBounds = false
        backgroundColor = .appCardBackground.withAlphaComponent(0.65)
        layer.borderWidth = 1

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .appTextSecondary
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])

        updateBorderColor()
    }

    private func updateBorderColor() {
        layer.borderColor = UIColor.appCardBorder.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateBorderColor()
    }
}
