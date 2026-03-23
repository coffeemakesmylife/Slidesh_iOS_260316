//
//  FormatPickerSheet.swift
//  Slidesh
//
//  自定义底部弹窗：选择输出格式
//  - overFullScreen + crossDissolve 呈现，面板从底部滑入
//

import UIKit

// MARK: - FormatPickerSheet

final class FormatPickerSheet: UIViewController {

    // 选择回调，传入格式字符串（如 "PDF"）
    var onSelect: ((String) -> Void)?

    // 格式列表
    private let formats: [String]

    // 半透明遮罩背景
    private let overlayView = UIView()

    // 底部面板
    private let panelView = UIView()

    // 拖拽把手
    private let handleView = UIView()

    // 标题
    private let titleLabel = UILabel()

    // 格式行垂直栈
    private let stackView = UIStackView()

    // 取消按钮卡片
    private let cancelBtn = UIView()

    // 记录每行的 layer，用于主题切换时更新边框色
    private var rowLayers: [CALayer] = []

    // MARK: - 初始化

    init(formats: [String]) {
        self.formats = formats
        super.init(nibName: nil, bundle: nil)
        // 覆盖全屏 + 交叉淡入，面板自行做滑入动画
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOverlay()
        setupPanel()
        setupHandle()
        setupTitle()
        setupFormatRows()
        setupCancelButton()
        layoutPanel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 面板初始位置：移到屏幕下方（用 view.layoutIfNeeded 保证面板已完成布局）
        view.layoutIfNeeded()
        let offset = panelView.bounds.height + 200
        panelView.transform = CGAffineTransform(translationX: 0, y: offset)
        overlayView.alpha   = 0

        // 弹性滑入动画
        let animator = UIViewPropertyAnimator(duration: 0.35, dampingRatio: 0.85) {
            self.panelView.transform = .identity
            self.overlayView.alpha   = 1
        }
        animator.startAnimation()
    }

    // 主题切换时更新 CALayer 边框色（动态 UIColor 不能直接赋给 cgColor）
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        let borderCG = UIColor.appCardBorder.cgColor
        rowLayers.forEach { $0.borderColor = borderCG }
        cancelBtn.layer.borderColor = borderCG
    }

    // MARK: - UI 构建

    // 遮罩背景，点击空白区域关闭
    private func setupOverlay() {
        overlayView.backgroundColor = .appOverlay
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap(_:)))
        overlayView.addGestureRecognizer(tap)
    }

    // 面板：圆角仅顶部两角
    private func setupPanel() {
        // 用二级背景色（浅色 #EDF0F3，深色 #0D1628），与白色行卡片形成层次
        panelView.backgroundColor = .appBackgroundSecondary
        panelView.layer.cornerRadius = 24
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.layer.masksToBounds = true
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)
    }

    // 拖拽把手：4×36pt，居中
    private func setupHandle() {
        handleView.backgroundColor    = UIColor.appTextSecondary.withAlphaComponent(0.4)
        handleView.layer.cornerRadius = 2
        handleView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(handleView)
        NSLayoutConstraint.activate([
            handleView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 12),
            handleView.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 36),
            handleView.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    // 标题："选择输出格式"
    private func setupTitle() {
        titleLabel.text      = "选择输出格式"
        titleLabel.font      = .systemFont(ofSize: 18, weight: .heavy)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: handleView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -20),
        ])
    }

    // 格式行列表
    private func setupFormatRows() {
        stackView.axis      = .vertical
        stackView.spacing   = 10
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
        ])

        for (index, format) in formats.enumerated() {
            let row = makeFormatRow(format: format, index: index)
            stackView.addArrangedSubview(row)
        }
    }

    // 取消按钮
    private func setupCancelButton() {
        cancelBtn.backgroundColor       = .appCardBackground  // 与行卡片同色，均在灰色面板上突出
        cancelBtn.layer.cornerRadius    = 16
        cancelBtn.layer.borderWidth     = 1
        cancelBtn.layer.borderColor     = UIColor.appCardBorder.cgColor
        cancelBtn.layer.masksToBounds   = true
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(cancelBtn)

        let label      = UILabel()
        label.text      = "取消"
        label.font      = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .appTextSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: cancelBtn.topAnchor),
            label.leadingAnchor.constraint(equalTo: cancelBtn.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: cancelBtn.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: cancelBtn.bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        cancelBtn.addGestureRecognizer(tap)

        // 使用 safeAreaLayoutGuide 避免 viewDidLoad 时 safeAreaInsets 为零的问题
        NSLayoutConstraint.activate([
            cancelBtn.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 12),
            cancelBtn.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            cancelBtn.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
            cancelBtn.heightAnchor.constraint(equalToConstant: 52),
            cancelBtn.bottomAnchor.constraint(equalTo: panelView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    // 面板固定到底部
    private func layoutPanel() {
        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - 工厂方法：单行格式卡片

    private func makeFormatRow(format: String, index: Int) -> UIView {
        let (symbolName, color) = iconInfo(for: format)
        let hintText = extensionHint(for: format)

        // 行容器
        let row = UIView()
        row.backgroundColor     = .appCardBackground
        row.layer.cornerRadius  = 20
        row.layer.borderWidth   = 1
        row.layer.borderColor   = UIColor.appCardBorder.cgColor
        row.layer.masksToBounds = true
        row.tag = index
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 64).isActive = true

        // 记录该 layer 用于主题更新
        rowLayers.append(row.layer)

        // 左侧图标背景
        let iconBg = UIView()
        iconBg.backgroundColor   = color.withAlphaComponent(0.15)
        iconBg.layer.cornerRadius = 15
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconBg)

        // SF Symbol 图标
        let iconView = UIImageView()
        let config   = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image       = UIImage(systemName: symbolName, withConfiguration: config)
        iconView.tintColor   = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // 格式名称
        let nameLabel      = UILabel()
        nameLabel.text      = format
        nameLabel.font      = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = .appTextPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(nameLabel)

        // 扩展名提示
        let hintLabel      = UILabel()
        hintLabel.text      = hintText
        hintLabel.font      = .systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = .appTextSecondary
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(hintLabel)

        // 右侧箭头
        let chevron = UIImageView()
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        chevron.image       = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevron.tintColor   = .appTextSecondary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(chevron)

        NSLayoutConstraint.activate([
            // 图标背景
            iconBg.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconBg.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),

            // 图标居中于背景
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            // 右侧箭头
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.widthAnchor.constraint(equalToConstant: 14),

            // 格式名
            nameLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            // 提示文字
            hintLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            hintLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
        ])

        // 点击手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
        row.addGestureRecognizer(tap)

        return row
    }

    // MARK: - 图标 & 颜色映射

    private func iconInfo(for format: String) -> (String, UIColor) {
        switch format.uppercased() {
        case "WORD":  return ("doc.richtext.fill",                         .systemIndigo)
        case "PDF":   return ("book.pages.fill",                           .systemRed)
        case "EXCEL": return ("tablecells.fill",                           .systemGreen)
        case "PPT":   return ("tv.fill",                                   .systemOrange)
        case "PNG":   return ("photo.fill",                                .systemTeal)
        case "HTML":  return ("globe",                                     .systemPurple)
        case "XML":   return ("chevron.left.forwardslash.chevron.right",   .systemBrown)
        default:      return ("doc.fill",                                  .appPrimary)
        }
    }

    // MARK: - 扩展名提示映射

    private func extensionHint(for format: String) -> String {
        switch format.uppercased() {
        case "WORD":  return ".docx 文档格式"
        case "PDF":   return ".pdf 便携文档"
        case "EXCEL": return ".xlsx 表格格式"
        case "PPT":   return ".pptx 演示文稿"
        case "PNG":   return ".png 图片格式"
        case "HTML":  return ".html 网页格式"
        case "XML":   return ".xml 标记语言"
        default:      return ""
        }
    }

    // MARK: - 动作

    // 点击遮罩：仅当触点在 panelView 外侧时关闭
    @objc private func handleOverlayTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        guard !panelView.frame.contains(location) else { return }
        animateDismiss()
    }

    // 点击取消按钮
    @objc private func cancelTapped() {
        animateDismiss()
    }

    // 点击格式行
    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let row = gesture.view else { return }
        let index = row.tag
        guard index < formats.count else { return }
        let format = formats[index]
        animateDismiss {
            self.onSelect?(format)
        }
    }

    // MARK: - 关闭动画

    private func animateDismiss(completion: (() -> Void)? = nil) {
        // [weak self] 避免循环引用
        let animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeIn) { [weak self] in
            guard let self else { return }
            let offset = self.panelView.bounds.height + 200
            self.panelView.transform = CGAffineTransform(translationX: 0, y: offset)
            self.overlayView.alpha = 0   // 与淡入时对称，使用 alpha 而非 backgroundColor
        }
        animator.addCompletion { [weak self] _ in
            self?.dismiss(animated: false) {
                completion?()
            }
        }
        animator.startAnimation()
    }
}
