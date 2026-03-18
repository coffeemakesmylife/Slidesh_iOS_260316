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
    private let paramsScrollView = UIScrollView()
    private let paramsStack      = UIStackView()
    private let generateButton   = UIButton(type: .system)

    // 参数 Chip 引用（便于更新标题）
    private var inspireChip:  ParamChip!
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
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 38, weight: .light)
        let iconView   = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: iconConfig))
        iconView.tintColor   = .appPrimaryLight
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)

        let mainLabel = UILabel()
        mainLabel.text          = "让 AI 为你创建精美 PPT"
        mainLabel.font          = .systemFont(ofSize: 22, weight: .bold)
        mainLabel.textColor     = .appTextPrimary
        mainLabel.textAlignment = .center
        mainLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainLabel)

        let subLabel = UILabel()
        subLabel.text          = "输入主题，几秒内生成专业幻灯片"
        subLabel.font          = .systemFont(ofSize: 14)
        subLabel.textColor     = .appTextSecondary
        subLabel.textAlignment = .center
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.bottomAnchor.constraint(equalTo: mainLabel.topAnchor, constant: -14),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            mainLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,
                                           constant: UIScreen.main.bounds.height * 0.13),

            subLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subLabel.topAnchor.constraint(equalTo: mainLabel.bottomAnchor, constant: 6),
        ])
    }

    // MARK: - 输入卡片

    private func setupCard() {
        cardView.backgroundColor     = .appCardBackground
        cardView.layer.cornerRadius  = 20
        cardView.layer.shadowColor   = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius  = 24
        cardView.layer.shadowOffset  = CGSize(width: 0, height: 6)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 30),
        ])

        let inputRow = buildThemeRow()
        let sep1     = buildSeparator(below: inputRow)
        let params   = buildParamsBar(below: sep1)
        let sep2     = buildSeparator(below: params)
        buildGenerateButton(below: sep2)
    }

    // 主题输入行（无发送按钮），返回视图用于后续链式约束
    @discardableResult
    private func buildThemeRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(row)

        let leftIcon = UIImageView(image: UIImage(systemName: "text.cursor"))
        leftIcon.tintColor    = .appTextTertiary
        leftIcon.contentMode  = .scaleAspectFit
        leftIcon.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(leftIcon)

        themeField.placeholder        = "输入您的幻灯片主题..."
        themeField.font               = .systemFont(ofSize: 15)
        themeField.textColor          = .appTextPrimary
        themeField.borderStyle        = .none
        themeField.returnKeyType      = .send
        themeField.autocorrectionType = .no
        themeField.enablesReturnKeyAutomatically = true
        themeField.delegate           = self
        themeField.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(themeField)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            row.heightAnchor.constraint(equalToConstant: 44),

            leftIcon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            leftIcon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            leftIcon.widthAnchor.constraint(equalToConstant: 20),
            leftIcon.heightAnchor.constraint(equalToConstant: 20),

            themeField.leadingAnchor.constraint(equalTo: leftIcon.trailingAnchor, constant: 10),
            themeField.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            themeField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    // 0.5pt 分割线，链接到 above 视图底部
    @discardableResult
    private func buildSeparator(below above: UIView) -> UIView {
        let sep = UIView()
        sep.backgroundColor = .appSeparator
        sep.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(sep)

        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: above.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            sep.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
        ])
        return sep
    }

    // 参数横向滚动栏
    @discardableResult
    private func buildParamsBar(below above: UIView) -> UIView {
        paramsScrollView.showsHorizontalScrollIndicator = false
        paramsScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        paramsScrollView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(paramsScrollView)

        paramsStack.axis      = .horizontal
        paramsStack.spacing   = 8
        paramsStack.alignment = .center
        paramsStack.translatesAutoresizingMaskIntoConstraints = false
        paramsScrollView.addSubview(paramsStack)

        // 五个参数 Chip：灵感 / 页数 / 语言 / 场景 / 受众
        inspireChip  = ParamChip(symbol: "lightbulb",   label: "主题灵感")
        pageChip     = ParamChip(symbol: "doc.text",    label: "\(selectedPageCount) 页")
        langChip     = ParamChip(symbol: "globe",       label: selectedLanguage)
        sceneChip    = ParamChip(symbol: "theatermasks", label: "场景")
        audienceChip = ParamChip(symbol: "person.2",    label: "受众")

        [inspireChip, pageChip, langChip, sceneChip, audienceChip]
            .forEach { paramsStack.addArrangedSubview($0) }

        inspireChip.onTap  = { [weak self] in self?.showInspirePicker() }
        pageChip.onTap     = { [weak self] in self?.showPagePicker() }
        langChip.onTap     = { [weak self] in self?.showLanguagePicker() }
        sceneChip.onTap    = { [weak self] in self?.showScenePicker() }
        audienceChip.onTap = { [weak self] in self?.showAudiencePicker() }

        NSLayoutConstraint.activate([
            paramsScrollView.topAnchor.constraint(equalTo: above.bottomAnchor),
            paramsScrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            paramsScrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            paramsScrollView.heightAnchor.constraint(equalToConstant: 52),

            paramsStack.topAnchor.constraint(equalTo: paramsScrollView.topAnchor),
            paramsStack.bottomAnchor.constraint(equalTo: paramsScrollView.bottomAnchor),
            paramsStack.leadingAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.leadingAnchor),
            paramsStack.trailingAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.trailingAnchor),
            paramsStack.heightAnchor.constraint(equalTo: paramsScrollView.heightAnchor),
        ])

        return paramsScrollView
    }

    // 底部"立即生成"渐变按钮
    private func buildGenerateButton(below above: UIView) {
        // 渐变容器（UIButton 不直接支持渐变，用包装 UIView）
        let container = UIView()
        container.layer.cornerRadius = 14
        container.clipsToBounds      = true
        container.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(container)

        // 品牌渐变层
        let gradient        = CAGradientLayer()
        gradient.colors     = [UIColor.appGradientStart.cgColor,
                                UIColor.appGradientMid.cgColor,
                                UIColor.appGradientEnd.cgColor]
        gradient.locations  = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint   = CGPoint(x: 1, y: 0.5)
        container.layer.insertSublayer(gradient, at: 0)

        // 按钮叠加在渐变上
        generateButton.setTitle("立即生成", for: .normal)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        generateButton.setImage(UIImage(systemName: "sparkles", withConfiguration: cfg), for: .normal)
        generateButton.tintColor       = .white
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        generateButton.semanticContentAttribute = .forceLeftToRight
        generateButton.imageEdgeInsets  = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        generateButton.titleEdgeInsets  = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(generateButton)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: above.bottomAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            container.heightAnchor.constraint(equalToConstant: 48),
            container.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            generateButton.topAnchor.constraint(equalTo: container.topAnchor),
            generateButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            generateButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            generateButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        // 渐变 frame 在布局后设定
        container.layoutIfNeeded()
        gradient.frame = container.bounds

        // 用 KVO-less 方式在 layoutSubviews 后更新 frame
        DispatchQueue.main.async { gradient.frame = container.bounds }
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

    @objc private func generateTapped() {
        let theme = themeField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !theme.isEmpty else {
            themeField.becomeFirstResponder()
            return
        }
        // TODO: 调用生成 API
        print("生成 PPT: 主题=\(theme), 页数=\(selectedPageCount), 语言=\(selectedLanguage), 场景=\(selectedScene), 受众=\(selectedAudience)")
    }

    // MARK: - 参数选择器

    private func showInspirePicker() {
        let topics  = ["2025年人工智能发展趋势", "季度销售业绩回顾", "新员工入职培训",
                       "产品发布会方案", "市场竞争分析", "团队建设与文化"]
        let picker  = FilterPickerViewController(title: "主题灵感", options: topics, selectedIndex: -1)
        picker.onSelect = { [weak self] idx in
            self?.themeField.text = topics[idx]
        }
        present(picker, animated: false)
    }

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
        let current = max(scenes.firstIndex(of: selectedScene) ?? 0, 0)
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
        let current   = max(audiences.firstIndex(of: selectedAudience) ?? 0, 0)
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
        generateTapped()
        return false
    }
}

// MARK: - ParamChip（参数横向滑动栏中的单个参数按钮）

private class ParamChip: UIView {

    var onTap: (() -> Void)?

    private let iconView  = UIImageView()
    private let textLabel = UILabel()
    private let chevron   = UIImageView()

    /// symbol: SF Symbol 名称；label: 当前显示值
    init(symbol: String, label: String) {
        super.init(frame: .zero)
        setup(symbol: symbol, label: label)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(symbol: String, label: String) {
        // 二级背景 + 三级背景层次：chip 用二级，卡片已是三级（白色/深蓝灰）
        backgroundColor    = .appBackgroundSecondary
        layer.cornerRadius = 14

        // SF Symbol 图标（替代字母徽章）
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        iconView.image       = UIImage(systemName: symbol, withConfiguration: iconCfg)
        iconView.tintColor   = .appTextSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // 参数值标签
        textLabel.text      = label
        textLabel.font      = .systemFont(ofSize: 13, weight: .medium)
        textLabel.textColor = .appTextPrimary
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        // 展开箭头
        let chevronCfg = UIImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        chevron.image       = UIImage(systemName: "chevron.down", withConfiguration: chevronCfg)
        chevron.tintColor   = .appTextTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textLabel)
        addSubview(chevron)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),

            textLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 5),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 4),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
    }

    func updateLabel(_ text: String) {
        textLabel.text = text
    }

    @objc private func didTap() {
        UIView.animate(withDuration: 0.1,
                       animations: { self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) }) { _ in
            UIView.animate(withDuration: 0.1) { self.transform = .identity }
        }
        onTap?()
    }
}
