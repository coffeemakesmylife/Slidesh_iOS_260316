//
//  NewProjectViewController.swift
//  Slidesh
//
//  极简 AI 建单页，视觉重心聚焦于输入卡片
//

import UIKit

class NewProjectViewController: UIViewController {

    // MARK: - 参数状态

    private var selectedPageCount = 10
    private var selectedLanguage  = "中文"
    private var selectedScene     = ""
    private var selectedAudience  = ""

    // MARK: - 子视图

    private let cardView         = UIView()
    private let themeField       = UITextField()
    private let sendButton       = UIButton(type: .system)
    private let paramsScrollView = UIScrollView()
    private let paramsStack      = UIStackView()

    // 参数 Chip 引用（便于更新标题）
    private var pageChip:     ParamChip!
    private var langChip:     ParamChip!
    private var sceneChip:    ParamChip!
    private var audienceChip: ParamChip!

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = ""
        addMeshGradientBackground()
        setupNav()
        setupSlogan()
        setupCard()
        setupKeyboardDismiss()
    }

    // MARK: - 导航栏

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
    }

    // MARK: - Slogan 区域

    private func setupSlogan() {
        // 品牌图标
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 38, weight: .light)
        let iconView   = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: iconConfig))
        iconView.tintColor    = .appPrimaryLight
        iconView.contentMode  = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)

        // 主标语
        let mainLabel = UILabel()
        mainLabel.text          = "让 AI 为你创建精美 PPT"
        mainLabel.font          = .systemFont(ofSize: 22, weight: .bold)
        mainLabel.textColor     = .appTextPrimary
        mainLabel.textAlignment = .center
        mainLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainLabel)

        // 副标语
        let subLabel = UILabel()
        subLabel.text          = "输入主题，几秒内生成专业幻灯片"
        subLabel.font          = .systemFont(ofSize: 14)
        subLabel.textColor     = .appTextSecondary
        subLabel.textAlignment = .center
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subLabel)

        NSLayoutConstraint.activate([
            // 图标在 mainLabel 上方
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.bottomAnchor.constraint(equalTo: mainLabel.topAnchor, constant: -14),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            // mainLabel 距安全区顶部 ~22%
            mainLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,
                                           constant: UIScreen.main.bounds.height * 0.13),

            subLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subLabel.topAnchor.constraint(equalTo: mainLabel.bottomAnchor, constant: 6),
        ])
    }

    // MARK: - 输入卡片

    private func setupCard() {
        cardView.backgroundColor          = .appCardBackground
        cardView.layer.cornerRadius       = 20
        cardView.layer.shadowColor        = UIColor.black.cgColor
        cardView.layer.shadowOpacity      = 0.08
        cardView.layer.shadowRadius       = 24
        cardView.layer.shadowOffset       = CGSize(width: 0, height: 6)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            // 卡片中心略高于屏幕中心
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 30),
        ])

        buildThemeRow()
        buildSeparator()
        buildParamsBar()
    }

    // 主题输入行
    private func buildThemeRow() {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(row)

        // 左侧文字图标
        let leftIcon = UIImageView(image: UIImage(systemName: "text.cursor"))
        leftIcon.tintColor    = .appTextTertiary
        leftIcon.contentMode  = .scaleAspectFit
        leftIcon.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(leftIcon)

        // 输入框
        themeField.placeholder            = "输入您的幻灯片主题..."
        themeField.font                   = .systemFont(ofSize: 15)
        themeField.textColor              = .appTextPrimary
        themeField.borderStyle            = .none
        themeField.returnKeyType          = .send
        themeField.autocorrectionType     = .no
        themeField.enablesReturnKeyAutomatically = true
        themeField.delegate               = self
        themeField.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(themeField)

        // 发送按钮
        let imgCfg  = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let sendImg = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: imgCfg)
        sendButton.setImage(sendImg, for: .normal)
        sendButton.tintColor = .appPrimary
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(sendButton)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            row.heightAnchor.constraint(equalToConstant: 46),

            leftIcon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            leftIcon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            leftIcon.widthAnchor.constraint(equalToConstant: 20),
            leftIcon.heightAnchor.constraint(equalToConstant: 20),

            themeField.leadingAnchor.constraint(equalTo: leftIcon.trailingAnchor, constant: 10),
            themeField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            themeField.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            sendButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 30),
            sendButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    // 分割线
    private func buildSeparator() {
        let sep = UIView()
        sep.backgroundColor = .appSeparator
        sep.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(sep)

        NSLayoutConstraint.activate([
            // 分割线紧贴输入行底部（输入行 top=16, height=46 → y=62）
            sep.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 62),
            sep.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    // 参数横向滚动栏
    private func buildParamsBar() {
        paramsScrollView.showsHorizontalScrollIndicator = false
        paramsScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        paramsScrollView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(paramsScrollView)

        paramsStack.axis      = .horizontal
        paramsStack.spacing   = 8
        paramsStack.alignment = .center
        paramsStack.translatesAutoresizingMaskIntoConstraints = false
        paramsScrollView.addSubview(paramsStack)

        // 创建四个参数 chips
        pageChip     = ParamChip(badge: "P", label: "\(selectedPageCount) 页")
        langChip     = ParamChip(badge: "L", label: selectedLanguage)
        sceneChip    = ParamChip(badge: "S", label: "场景")
        audienceChip = ParamChip(badge: "A", label: "受众")

        [pageChip, langChip, sceneChip, audienceChip].forEach { paramsStack.addArrangedSubview($0) }

        pageChip.onTap     = { [weak self] in self?.showPagePicker() }
        langChip.onTap     = { [weak self] in self?.showLanguagePicker() }
        sceneChip.onTap    = { [weak self] in self?.showScenePicker() }
        audienceChip.onTap = { [weak self] in self?.showAudiencePicker() }

        NSLayoutConstraint.activate([
            // 分割线在 y=62.5，参数栏从 y=63 开始
            paramsScrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 63),
            paramsScrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            paramsScrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            paramsScrollView.heightAnchor.constraint(equalToConstant: 52),
            paramsScrollView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -4),

            paramsStack.topAnchor.constraint(equalTo: paramsScrollView.topAnchor),
            paramsStack.bottomAnchor.constraint(equalTo: paramsScrollView.bottomAnchor),
            paramsStack.leadingAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.leadingAnchor),
            paramsStack.trailingAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.trailingAnchor),
            paramsStack.heightAnchor.constraint(equalTo: paramsScrollView.heightAnchor),
        ])
    }

    // MARK: - 键盘收起

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - Actions

    @objc private func dismissSelf()     { dismiss(animated: true) }
    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func sendTapped() {
        let theme = themeField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !theme.isEmpty else { return }
        // TODO: 调用生成 API
        print("生成 PPT: 主题=\(theme), 页数=\(selectedPageCount), 语言=\(selectedLanguage)")
    }

    // MARK: - 参数选择器

    private func showPagePicker() {
        let counts  = [5, 8, 10, 15, 20, 25, 30]
        let options = counts.map { "\($0) 页" }
        let current = counts.firstIndex(of: selectedPageCount) ?? 2
        let picker  = FilterPickerViewController(title: "页数", options: options, selectedIndex: current)
        picker.onSelect = { [weak self] idx in
            guard let self else { return }
            self.selectedPageCount = counts[idx]
            self.pageChip.updateLabel("\(counts[idx]) 页")
        }
        present(picker, animated: false)
    }

    private func showLanguagePicker() {
        let langs   = ["中文", "English", "日本語", "한국어", "Français", "Español"]
        let current = langs.firstIndex(of: selectedLanguage) ?? 0
        let picker  = FilterPickerViewController(title: "语言", options: langs, selectedIndex: current)
        picker.onSelect = { [weak self] idx in
            guard let self else { return }
            self.selectedLanguage = langs[idx]
            self.langChip.updateLabel(langs[idx])
        }
        present(picker, animated: false)
    }

    private func showScenePicker() {
        let scenes  = ["通用", "商务", "教育", "科技", "医疗", "创意"]
        let current = scenes.firstIndex(of: selectedScene) ?? 0
        let picker  = FilterPickerViewController(title: "场景", options: scenes, selectedIndex: current)
        picker.onSelect = { [weak self] idx in
            guard let self else { return }
            self.selectedScene = scenes[idx]
            self.sceneChip.updateLabel(scenes[idx])
        }
        present(picker, animated: false)
    }

    private func showAudiencePicker() {
        let audiences = ["通用", "学生", "职场人士", "管理层", "投资人", "客户"]
        let current   = audiences.firstIndex(of: selectedAudience) ?? 0
        let picker    = FilterPickerViewController(title: "受众", options: audiences, selectedIndex: current)
        picker.onSelect = { [weak self] idx in
            guard let self else { return }
            self.selectedAudience = audiences[idx]
            self.audienceChip.updateLabel(audiences[idx])
        }
        present(picker, animated: false)
    }
}

// MARK: - UITextFieldDelegate

extension NewProjectViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return false
    }
}

// MARK: - ParamChip（参数横向滑动栏中的单个参数按钮）

private class ParamChip: UIView {

    var onTap: (() -> Void)?

    private let badgeLabel = UILabel()
    private let textLabel  = UILabel()
    private let chevron    = UIImageView()

    init(badge: String, label: String) {
        super.init(frame: .zero)
        setup(badge: badge, label: label)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(badge: String, label: String) {
        backgroundColor    = .appChipUnselectedBackground
        layer.cornerRadius = 14

        // 徽章字母
        badgeLabel.text          = badge
        badgeLabel.font          = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor     = .appChipUnselectedText
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        // 参数值标签
        textLabel.text      = label
        textLabel.font      = .systemFont(ofSize: 13, weight: .medium)
        textLabel.textColor = .appTextPrimary
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        // 展开箭头
        let cfg = UIImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        chevron.image     = UIImage(systemName: "chevron.down", withConfiguration: cfg)
        chevron.tintColor = .appTextTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        addSubview(badgeLabel)
        addSubview(textLabel)
        addSubview(chevron)

        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.widthAnchor.constraint(equalToConstant: 14),

            textLabel.leadingAnchor.constraint(equalTo: badgeLabel.trailingAnchor, constant: 5),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 4),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),

            heightAnchor.constraint(equalToConstant: 30),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
    }

    func updateLabel(_ text: String) {
        textLabel.text = text
    }

    @objc private func didTap() {
        // 轻微缩放反馈
        UIView.animate(withDuration: 0.1, animations: { self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) }) { _ in
            UIView.animate(withDuration: 0.1) { self.transform = .identity }
        }
        onTap?()
    }
}
