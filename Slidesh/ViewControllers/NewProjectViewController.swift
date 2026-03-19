//
//  NewProjectViewController.swift
//  Slidesh
//

import UIKit

class NewProjectViewController: UIViewController {

    // MARK: - 参数状态（存 API 值）

    private var selectedLength   = "medium"   // short / medium / long
    private var selectedLanguage = "zh"       // 语言 API 值
    private var selectedScene    = "通用"
    private var selectedAudience = "大众"

    // MARK: - 子视图

    private let cardView         = UIView()
    private let themeTextView    = UITextView()
    private let placeholderLabel = UILabel()
    private let paramsScrollView = UIScrollView()
    private let paramsStack      = UIStackView()
    private let generateButton   = UIButton(type: .system)

    // 生成按钮渐变层（需在 viewDidLayoutSubviews 中更新 frame）
    private var generateGradient: CAGradientLayer?
    private weak var generateContainer: UIView?
    // 生成中 loading 指示器
    private weak var generateSpinner: UIActivityIndicatorView?

    // 卡片垂直位置约束（键盘弹出时动态调整）
    private var cardCenterYConstraint: NSLayoutConstraint!
    // subLabel 底部约束（TopicSuggestionsView 出现时上移）
    private var subLabelBottomConstraint: NSLayoutConstraint!

    // 输入框高度约束（动态更新）
    private var textViewHeightConstraint: NSLayoutConstraint!
    private let minInputHeight: CGFloat = 44
    private let maxInputHeight: CGFloat = 120

    // 参数 Chip 引用
    private var inspireChip: ParamChip!
    private var pageChip:    ParamChip!
    private var langChip:    ParamChip!

    // 当前 SSE 任务（用于取消）
    private var generateTask: URLSessionDataTask?

    // 主题灵感建议浮层（卡片外部，靠右对齐，参考 PromptSuggestionsView 设计）
    private var topicSuggestionsView: TopicSuggestionsView!
    // 当前选中行业的主题列表（文本清空后用于复显）
    private var currentTopics: [String] = []

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = ""
        addMeshGradientBackground()
        setupNav()
        setupCard()      // 先将 cardView 加入视图层级
        setupSlogan()    // 再建立 subLabel → cardView 的底部约束
        setupTopicSuggestions()
        setupKeyboardDismiss()
        setupKeyboardObservers()
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

        // 布局方向从下往上：subLabel 底部紧贴卡片顶，mainLabel/icon 依次叠上
        subLabelBottomConstraint = subLabel.bottomAnchor.constraint(
            equalTo: cardView.topAnchor, constant: -20)

        NSLayoutConstraint.activate([
            subLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subLabelBottomConstraint,

            mainLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainLabel.bottomAnchor.constraint(equalTo: subLabel.topAnchor, constant: -6),

            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.bottomAnchor.constraint(equalTo: mainLabel.topAnchor, constant: -14),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    // MARK: - 输入卡片

    private func setupCard() {
        cardView.backgroundColor     = .appCardBackground.withAlphaComponent(0.7)
        cardView.layer.cornerRadius  = 30
        cardView.layer.shadowColor   = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowRadius  = 24
        cardView.layer.shadowOffset  = CGSize(width: 0, height: 6)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        // 卡片描边（dark mode 自适应）
        updateCardBorder()

        cardCenterYConstraint = cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 10)
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cardCenterYConstraint,
        ])

        let inputContainer = buildThemeRow()
        let sep1           = buildSeparator(below: inputContainer)
        let params         = buildParamsBar(below: sep1)
        // 参数栏底部 = 卡片底部（决定卡片高度）
        params.bottomAnchor.constraint(equalTo: cardView.bottomAnchor).isActive = true

        // 生成按钮独立在卡片外部
        buildGenerateButton()
    }

    // 主题建议浮层：定位在 cardView 上方，靠右对齐
    private func setupTopicSuggestions() {
        topicSuggestionsView = TopicSuggestionsView()
        topicSuggestionsView.isHidden = true
        topicSuggestionsView.translatesAutoresizingMaskIntoConstraints = false
        topicSuggestionsView.onSelect = { [weak self] topic in
            self?.applyTopic(topic)
        }
        view.addSubview(topicSuggestionsView)

        NSLayoutConstraint.activate([
            topicSuggestionsView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            topicSuggestionsView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            topicSuggestionsView.bottomAnchor.constraint(equalTo: cardView.topAnchor, constant: -12),
        ])
    }

    private func updateCardBorder() {
        let color = UIColor.appCardBorder.resolvedColor(with: traitCollection)
        cardView.layer.borderColor = color.cgColor
        cardView.layer.borderWidth = 1.5
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateCardBorder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gc = generateContainer {
            generateGradient?.frame = gc.bounds
        }
    }

    // MARK: - 主题输入区（UITextView + 动态高度）

    @discardableResult
    private func buildThemeRow() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(container)

        // UITextView
        themeTextView.backgroundColor       = .clear
        themeTextView.font                  = .systemFont(ofSize: 15)
        themeTextView.textColor             = .appTextPrimary
        themeTextView.isScrollEnabled       = false
        themeTextView.textContainerInset    = .zero
        themeTextView.textContainer.lineFragmentPadding = 0
        themeTextView.autocorrectionType    = .no
        themeTextView.delegate              = self
        themeTextView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(themeTextView)

        // 占位符（UITextView 不内置 placeholder）
        placeholderLabel.text                     = "输入您的幻灯片主题..."
        placeholderLabel.font                     = .systemFont(ofSize: 15)
        placeholderLabel.textColor                = .appTextTertiary
        placeholderLabel.isUserInteractionEnabled = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(placeholderLabel)

        // 动态高度约束
        textViewHeightConstraint = themeTextView.heightAnchor.constraint(equalToConstant: minInputHeight)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            themeTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            themeTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            themeTextView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            textViewHeightConstraint,
            themeTextView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            placeholderLabel.leadingAnchor.constraint(equalTo: themeTextView.leadingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: themeTextView.topAnchor),
        ])

        return container
    }

    // MARK: - 主题建议浮层

    func showTopicSuggestions(topics: [String]) {
        currentTopics = topics
        topicSuggestionsView.update(topics: topics)
        // update() 同步填充 chip 后，立即读取内容高度并上移 subLabel
        let h = topicSuggestionsView.fittingHeight
        shiftSubLabel(by: h)
    }

    /// 根据 TopicSuggestionsView 高度调整 subLabel 底部间距（0 = 复位）
    private func shiftSubLabel(by suggestionsHeight: CGFloat) {
        // base -20：subLabel 与卡片顶的基础间距；有建议时再追加高度 + 20 上间距
        let extra = suggestionsHeight > 0 ? suggestionsHeight + 20 : 0
        subLabelBottomConstraint.constant = -(20 + extra)
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    private func applyTopic(_ topic: String) {
        view.endEditing(true)   // 同时收起键盘
        themeTextView.text = topic
        placeholderLabel.isHidden = true
        // textViewDidChange 会根据文本非空调用 hide()，无需重复
        textViewDidChange(themeTextView)
    }

    // MARK: - 分割线

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

    // MARK: - 参数横向滚动栏

    @discardableResult
    private func buildParamsBar(below above: UIView) -> UIView {
        let container = UIView()
        // 底部两角裁剪，与 cardView 圆角（30）对齐，防止 chip 滑出圆角边界
        container.layer.cornerRadius  = 30
        container.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        container.clipsToBounds       = true
        container.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(container)

        // 更多按钮：固定在右侧，不参与滚动
        let moreBtn = buildMoreButton()
        container.addSubview(moreBtn)

        // 竖向分割线，隔开滚动区域和更多按钮
        let divider = UIView()
        divider.backgroundColor = .appSeparator
        divider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(divider)

        // ScrollView：从 leading 到 divider.leading，chip 不会遮挡 moreBtn
        paramsScrollView.showsHorizontalScrollIndicator = false
        paramsScrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
        paramsScrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(paramsScrollView)

        paramsStack.axis      = .horizontal
        paramsStack.spacing   = 8
        paramsStack.alignment = .center
        paramsStack.translatesAutoresizingMaskIntoConstraints = false
        paramsScrollView.addSubview(paramsStack)

        // 三个 Chip：灵感 / 页数 / 语言
        inspireChip = ParamChip(symbol: "lightbulb", label: "主题灵感")
        // 用默认值对应的显示文本初始化 chip
        let defaultLength = ParamsPickerViewController.lengths.first { $0.value == selectedLength }
        let defaultLang   = ParamsPickerViewController.languages.first { $0.value == selectedLanguage }
        let lengthLabel = defaultLength.map { "\($0.display) \($0.detail)" } ?? "中篇 20-30页"
        pageChip = ParamChip(symbol: "doc.text", label: lengthLabel)
        langChip = ParamChip(symbol: "globe",    label: defaultLang?.display   ?? "中文（简体）")

        [inspireChip, pageChip, langChip].forEach { paramsStack.addArrangedSubview($0) }

        inspireChip.onTap = { [weak self] in self?.showInspirePicker() }
        pageChip.onTap    = { [weak self] in self?.showParamsPicker() }
        langChip.onTap    = { [weak self] in self?.showParamsPicker() }

        let moreBtnW: CGFloat = 44

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: above.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: 52),

            // 更多按钮：紧贴右侧，撑满容器高度
            moreBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            moreBtn.topAnchor.constraint(equalTo: container.topAnchor),
            moreBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            moreBtn.widthAnchor.constraint(equalToConstant: moreBtnW),

            // 分割线：紧靠 moreBtn 左侧，垂直居中
            divider.trailingAnchor.constraint(equalTo: moreBtn.leadingAnchor),
            divider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 0.5),
            divider.heightAnchor.constraint(equalToConstant: 20),

            // ScrollView：从 leading 到 divider.leading（不与 moreBtn 重叠）
            paramsScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            paramsScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            paramsScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            paramsScrollView.trailingAnchor.constraint(equalTo: divider.leadingAnchor),

            // Stack 使用 contentLayoutGuide（正确的横向滚动布局方式）
            paramsStack.topAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.topAnchor),
            paramsStack.bottomAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.bottomAnchor),
            paramsStack.leadingAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            paramsStack.trailingAnchor.constraint(equalTo: paramsScrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            // 高度锁定为 frameLayoutGuide 高度，防止垂直滚动
            paramsStack.heightAnchor.constraint(equalTo: paramsScrollView.frameLayoutGuide.heightAnchor),
        ])

        return container
    }

    private func buildMoreButton() -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        btn.setImage(UIImage(systemName: "line.3.horizontal.decrease", withConfiguration: cfg), for: .normal)
        btn.tintColor = .appTextSecondary
        btn.addTarget(self, action: #selector(moreParamsTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    // MARK: - 生成按钮（独立在卡片外部）

    private func buildGenerateButton() {
        let container = UIView()
        container.layer.cornerRadius = 22
        container.clipsToBounds      = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        generateContainer = container

        let gradient        = CAGradientLayer()
        gradient.colors     = [UIColor.appGradientStart.cgColor,
                                UIColor.appGradientMid.cgColor,
                                UIColor.appGradientEnd.cgColor]
        gradient.locations  = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint   = CGPoint(x: 1, y: 0.5)
        container.layer.insertSublayer(gradient, at: 0)
        generateGradient = gradient

        generateButton.setTitle("立即生成", for: .normal)
        let imgCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        generateButton.setImage(UIImage(systemName: "sparkles", withConfiguration: imgCfg), for: .normal)
        generateButton.tintColor        = .white
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        generateButton.semanticContentAttribute = .forceLeftToRight
        generateButton.imageEdgeInsets  = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        generateButton.titleEdgeInsets  = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(generateButton)

        // loading 转圈，生成时覆盖按钮文字
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        generateSpinner = spinner

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        NSLayoutConstraint.activate([
            // 紧贴卡片底部，与卡片左右对齐
            container.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: 60),

            generateButton.topAnchor.constraint(equalTo: container.topAnchor),
            generateButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            generateButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            generateButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }

    // MARK: - 键盘

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self   // 过滤 topicSuggestionsView 内的点击
        view.addGestureRecognizer(tap)
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info     = notification.userInfo,
              let kbValue  = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        // 键盘顶部（在当前 view 坐标系中）
        let kbTop = view.convert(kbValue.cgRectValue, from: nil).minY
        // 生成按钮底部（cardView 底 + 12 间距 + 60 按钮高）
        let buttonBottom = cardView.frame.maxY + 72
        // 超出部分就是需要上移的距离，额外留 16pt 间距
        let overlap = buttonBottom - (kbTop - 16)
        guard overlap > 0 else { return }

        cardCenterYConstraint.constant = 10 - overlap
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info     = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        cardCenterYConstraint.constant = 10
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

    @objc private func dismissSelf()     { dismiss(animated: true) }
    @objc private func dismissKeyboard() { view.endEditing(true) }
    @objc private func moreParamsTapped() { showParamsPicker() }

    @objc private func generateTapped() {
        let theme = themeTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !theme.isEmpty else { themeTextView.becomeFirstResponder(); return }

        view.endEditing(true)
        setGenerating(true)

        // Step 1：创建任务，获取 taskId
        PPTAPIService.shared.createTask(subject: theme) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.setGenerating(false)
                self.showGenerateError(error.localizedDescription)
            case .success(let taskId):
                self.startGenerateContent(taskId: taskId)
            }
        }
    }

    /// Step 2：createTask 成功后直接推送大纲页，由 OutlineViewController 自行发起 SSE
    private func startGenerateContent(taskId: String) {
        let theme = themeTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let vc = OutlineViewController(
            taskId:   taskId,
            subject:  theme,
            language: selectedLanguage,
            length:   selectedLength,
            scene:    selectedScene,
            audience: selectedAudience
        )
        setGenerating(false)
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 切换生成中/完成状态：按钮禁用 + spinner 动画
    private func setGenerating(_ generating: Bool) {
        generateButton.isEnabled = !generating
        generateContainer?.alpha = generating ? 0.85 : 1.0
        if generating {
            generateButton.setTitle("", for: .normal)
            generateButton.setImage(nil, for: .normal)
            generateSpinner?.startAnimating()
        } else {
            generateSpinner?.stopAnimating()
            generateButton.setTitle("立即生成", for: .normal)
            let imgCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            generateButton.setImage(UIImage(systemName: "sparkles", withConfiguration: imgCfg), for: .normal)
            generateTask = nil
        }
    }

    private func showGenerateError(_ message: String) {
        let alert = UIAlertController(title: "生成失败", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 选择器

    private func showInspirePicker() {
        view.endEditing(true)
        let picker = InspirationPickerViewController()
        picker.onSelect = { [weak self] category in
            guard let self else { return }
            // 参数栏 chip 显示选中的行业名
            self.inspireChip.updateLabel(category.name)
            self.showTopicSuggestions(topics: category.topics)
        }
        picker.modalPresentationStyle = .pageSheet
        if let sheet = picker.sheetPresentationController {
            sheet.detents               = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(picker, animated: true)
    }

    private func showParamsPicker() {
        view.endEditing(true)  // 弹出前收起键盘

        // 若当前值不在数组中，则说明之前选了自定义（index 指向数组末尾之后）
        let scenes    = ParamsPickerViewController.scenes
        let audiences = ParamsPickerViewController.audiences
        let sceneIdx  = scenes.firstIndex(of: selectedScene) ?? scenes.count      // 不在数组则指向"自定义"位置
        let audIdx    = audiences.firstIndex(of: selectedAudience) ?? audiences.count

        var current = ParamsPickerViewController.Selection(
            lengthIndex:   ParamsPickerViewController.lengths.firstIndex(where: { $0.value == selectedLength }) ?? 1,
            languageIndex: ParamsPickerViewController.languages.firstIndex(where: { $0.value == selectedLanguage }) ?? 0,
            sceneIndex:    sceneIdx,
            audienceIndex: audIdx
        )
        // 恢复自定义文本
        if sceneIdx >= scenes.count    { current.customScene    = selectedScene }
        if audIdx   >= audiences.count { current.customAudience = selectedAudience }

        let picker = ParamsPickerViewController(selection: current)
        picker.onConfirm = { [weak self] sel in
            guard let self else { return }
            self.selectedLength   = sel.length.value
            self.selectedLanguage = sel.language.value
            self.selectedScene    = sel.scene     // 自定义时返回 customScene
            self.selectedAudience = sel.audience  // 自定义时返回 customAudience
            self.pageChip.updateLabel("\(sel.length.display) \(sel.length.detail)")
            self.langChip.updateLabel(sel.language.display)
        }

        // 使用 native sheet medium detent
        picker.modalPresentationStyle = .pageSheet
        if let sheet = picker.sheetPresentationController {
            sheet.detents                = [.medium(), .large()]
            sheet.prefersGrabberVisible  = true
        }
        present(picker, animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension NewProjectViewController: UIGestureRecognizerDelegate {
    /// 只有 touch 精确命中 topicSuggestionsView 内的 chip 按钮时才不拦截
    /// 其余所有区域（空白、titleLabel、subLabel 等）均允许手势触发收键盘
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        let point   = touch.location(in: view)
        let hitView = view.hitTest(point, with: nil)
        // 命中的是 topicSuggestionsView 内的 chip 按钮 → 不拦截，让按钮自己处理
        return !(hitView is UIButton && hitView?.isDescendant(of: topicSuggestionsView) == true)
    }
}

// MARK: - UITextViewDelegate

extension NewProjectViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        // 占位符显隐
        placeholderLabel.isHidden = !textView.text.isEmpty

        // 建议浮层：有文字→收起，清空→若有已选行业则重新展示
        if textView.text.isEmpty {
            if !currentTopics.isEmpty {
                topicSuggestionsView.show()
                shiftSubLabel(by: topicSuggestionsView.fittingHeight)
            }
        } else {
            topicSuggestionsView.hide()
            shiftSubLabel(by: 0)
        }

        // 动态计算高度
        let size   = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
        let newH   = min(max(size.height, minInputHeight), maxInputHeight)
        let scroll = size.height > maxInputHeight

        guard newH != textViewHeightConstraint.constant || textView.isScrollEnabled != scroll else { return }

        textViewHeightConstraint.constant = newH
        textView.isScrollEnabled = scroll
        UIView.animate(withDuration: 0.15) { self.view.layoutIfNeeded() }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        // 单独一个换行 = 触发生成（不插入换行符）
        if text == "\n" { generateTapped(); return false }
        return true
    }
}

// MARK: - ParamChip

private class ParamChip: UIView {

    var onTap: (() -> Void)?

    private let iconView  = UIImageView()
    private let textLabel = UILabel()
    private let chevron   = UIImageView()

    init(symbol: String, label: String) {
        super.init(frame: .zero)
        setup(symbol: symbol, label: label)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(symbol: String, label: String) {
        backgroundColor    = .appBackgroundSecondary
        layer.cornerRadius = 14

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        iconView.image       = UIImage(systemName: symbol, withConfiguration: iconCfg)
        iconView.tintColor   = .appTextSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        textLabel.text      = label
        textLabel.font      = .systemFont(ofSize: 13, weight: .medium)
        textLabel.textColor = .appTextPrimary
        textLabel.translatesAutoresizingMaskIntoConstraints = false

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

    func updateLabel(_ text: String) { textLabel.text = text }

    @objc private func didTap() {
        UIView.animate(withDuration: 0.1,
                       animations: { self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) }) { _ in
            UIView.animate(withDuration: 0.1) { self.transform = .identity }
        }
        onTap?()
    }
}

// MARK: - TopicSuggestionsView（主题建议浮层，卡片外部靠右对齐，参考 PromptSuggestionsView）

private class TopicSuggestionsView: UIView {

    private let stackView = UIStackView()
    var onSelect: ((String) -> Void)?

    /// 当前内容的自适应高度（stackView 实际高度，用于外部调整布局）
    var fittingHeight: CGFloat {
        stackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // alignment = .trailing 使每个按钮按内容宽度自适应，整体靠右
        stackView.axis      = .vertical
        stackView.spacing   = 8
        stackView.alignment = .trailing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // 刷新主题建议（换新行业时调用），带淡入动画
    func update(topics: [String]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for topic in topics {
            stackView.addArrangedSubview(makeChip(topic: topic))
        }
        alpha = 0
        isHidden = false
        UIView.animate(withDuration: 0.25) { self.alpha = 1 }
    }

    // 仅淡入展示（chips 不变，文本清空后复用）
    func show() {
        guard isHidden, !stackView.arrangedSubviews.isEmpty else { return }
        alpha = 0
        isHidden = false
        UIView.animate(withDuration: 0.25) { self.alpha = 1 }
    }

    // 淡出并隐藏（保留 chips，供 show() 复用）
    func hide() {
        guard !isHidden else { return }
        UIView.animate(withDuration: 0.2) { self.alpha = 0 } completion: { _ in
            self.isHidden = true
        }
    }

    private func makeChip(topic: String) -> UIButton {
        // 用 .custom 避免 system button 从父视图继承蓝色 tintColor
        let btn = UIButton(type: .custom)
        btn.setTitle(topic, for: .normal)
        btn.titleLabel?.font          = .systemFont(ofSize: 14)
        btn.titleLabel?.lineBreakMode = .byTruncatingTail
        btn.setTitleColor(.appTextPrimary, for: .normal)
        btn.backgroundColor           = .appCardBackground.withAlphaComponent(0.92)
        btn.layer.cornerRadius        = 16
        btn.layer.borderColor         = UIColor.appSeparator.cgColor
        btn.layer.borderWidth         = 1
        btn.contentEdgeInsets         = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 20)

        // alwaysOriginal 固定颜色，不受 tint 继承影响
        let cfg   = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        let arrow = UIImage(systemName: "arrow.down.left", withConfiguration: cfg)?
                        .withTintColor(.appTextSecondary, renderingMode: .alwaysOriginal)
        btn.setImage(arrow, for: .normal)
        btn.semanticContentAttribute  = .forceRightToLeft
        btn.imageEdgeInsets           = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)

        btn.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func chipTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        onSelect?(title)
    }
}

