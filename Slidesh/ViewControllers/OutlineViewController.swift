//
//  OutlineViewController.swift
//  Slidesh
//
//  大纲生成页：流式 markdown 展示 → 可编辑卡片列表
//

import UIKit

// MARK: - 数据模型

struct OutlineSection {
    enum Kind { case theme, toc, chapter }
    var kind: Kind
    var title: String
    var bullets: [OutlineBullet]

    var tagLabel: String {
        switch kind {
        case .theme:   return "主题"
        case .toc:     return "目录"
        case .chapter: return "章节"
        }
    }
}

struct OutlineBullet {
    enum Level { case h3, h4, body }
    var level: Level
    var text: String
}

// MARK: - Markdown 解析器

enum MarkdownParser {
    /// 将 markdown 文本解析为大纲数据模型
    static func parse(_ md: String) -> [OutlineSection] {
        var sections:         [OutlineSection] = []
        var tocTitles:        [String]         = []
        var curChapterTitle   = ""
        var curBullets:       [OutlineBullet]  = []
        var inChapter         = false

        func flushChapter() {
            guard inChapter, !curChapterTitle.isEmpty else { return }
            sections.append(OutlineSection(kind: .chapter, title: curChapterTitle, bullets: curBullets))
            curBullets = []
        }

        for line in md.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("# ") {
                sections.append(OutlineSection(kind: .theme, title: String(t.dropFirst(2)), bullets: []))
            } else if t.hasPrefix("## ") {
                flushChapter()
                curChapterTitle = String(t.dropFirst(3))
                tocTitles.append(curChapterTitle)
                inChapter = true
            } else if t.hasPrefix("### ") {
                curBullets.append(OutlineBullet(level: .h3, text: String(t.dropFirst(4))))
            } else if t.hasPrefix("#### ") {
                curBullets.append(OutlineBullet(level: .h4, text: String(t.dropFirst(5))))
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                curBullets.append(OutlineBullet(level: .h3, text: String(t.dropFirst(2))))
            } else if !t.isEmpty && inChapter && !t.hasPrefix("#") {
                curBullets.append(OutlineBullet(level: .body, text: t))
            }
        }
        flushChapter()

        // 在主题后插入目录 section
        if !tocTitles.isEmpty {
            let tocBullets = tocTitles.enumerated().map { i, title in
                OutlineBullet(level: .body, text: "\(i + 1). \(title)")
            }
            let toc = OutlineSection(kind: .toc, title: "目录", bullets: tocBullets)
            let insertIdx = sections.firstIndex(where: { $0.kind == .theme }).map { $0 + 1 } ?? 0
            sections.insert(toc, at: insertIdx)
        }
        return sections
    }
}

// MARK: - OutlineViewController

class OutlineViewController: UIViewController {

    // 参数
    private let taskId:   String
    private let subject:  String
    private let language: String
    private let length:   String
    private let scene:    String
    private let audience: String

    // 状态
    private var accumulatedMarkdown = ""
    private var sseTask: URLSessionDataTask?
    private var sections: [OutlineSection] = []
    private var activeIndexPath: IndexPath?   // 当前正在编辑的 cell 位置（用于键盘滚动）

    // 流式展示
    private let streamScrollView = UIScrollView()
    private let streamLabel      = UILabel()
    private let spinner          = UIActivityIndicatorView(style: .medium)
    private let spinnerLabel     = UILabel()

    // 卡片编辑
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // 底部工具栏
    private let bottomBar   = UIView()
    private let templateBtn = UIButton(type: .custom)
    private var templateGrad: CAGradientLayer?

    init(taskId:   String, subject:  String,
         language: String, length:   String,
         scene:    String, audience: String) {
        self.taskId   = taskId;   self.subject  = subject
        self.language = language; self.length   = length
        self.scene    = scene;    self.audience = audience
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 导航栏改为透明背景，与 SettingsViewController 一致
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开页面时恢复默认导航栏外观
        let def = UINavigationBarAppearance()
        def.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance   = def
        navigationController?.navigationBar.scrollEdgeAppearance = def
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "大纲生成"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"), style: .plain,
            target: self, action: #selector(backTapped))
        hidesBottomBarWhenPushed = true

        setupBottomBar()  // 先布局底部栏，tableView 绑定其顶部
        setupStreamView()
        setupTableView()
        setupKeyboardDismiss()
        setupKeyboardHandling()
        startSSE()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // adjustedContentInset 在 viewDidAppear 时才确定；设置初始 offset 让内容从导航栏下方开始
        if streamScrollView.contentOffset.y > -streamScrollView.adjustedContentInset.top {
            streamScrollView.setContentOffset(
                CGPoint(x: 0, y: -streamScrollView.adjustedContentInset.top), animated: false)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        templateGrad?.frame = templateBtn.bounds
    }

    // MARK: - 布局

    private func setupStreamView() {
        // 延伸到 view.topAnchor 实现导航栏透明效果，系统自动通过 adjustedContentInset 留出安全区
        streamScrollView.contentInsetAdjustmentBehavior = .always
        streamScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(streamScrollView)

        streamLabel.numberOfLines = 0
        streamLabel.translatesAutoresizingMaskIntoConstraints = false
        streamScrollView.addSubview(streamLabel)

        spinner.color = .secondaryLabel
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        spinnerLabel.text      = "大纲生成中..."
        spinnerLabel.font      = .systemFont(ofSize: 13)
        spinnerLabel.textColor = .secondaryLabel
        spinnerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinnerLabel)

        NSLayoutConstraint.activate([
            streamScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            streamScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            streamScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            streamScrollView.bottomAnchor.constraint(equalTo: spinner.topAnchor, constant: -12),

            // 内容标签撑开 contentSize
            streamLabel.topAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.topAnchor, constant: 16),
            streamLabel.leadingAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            streamLabel.trailingAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            streamLabel.bottomAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            streamLabel.widthAnchor.constraint(equalTo: streamScrollView.frameLayoutGuide.widthAnchor, constant: -32),

            // spinner 固定在 safeArea 底部，不受 bottomBar 影响
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -48),
            spinner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            spinnerLabel.centerYAnchor.constraint(equalTo: spinner.centerYAnchor),
            spinnerLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 8),
        ])
    }

    private func setupBottomBar() {
        bottomBar.backgroundColor = .systemBackground
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        // 顶部分割线
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(sep)

        // 绿色勾 + hint
        let checkImg = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkImg.tintColor = .systemGreen
        checkImg.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(checkImg)

        let hintLbl = UILabel()
        hintLbl.text      = "AI生成内容仅供参考，点击可编辑操作"
        hintLbl.font      = .systemFont(ofSize: 12)
        hintLbl.textColor = .secondaryLabel
        hintLbl.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(hintLbl)

        // 换个大纲 & 下载大纲
        let regenBtn = makeToolbarBtn(symbol: "arrow.clockwise", label: "换个大纲", action: #selector(regenerateTapped))
        let dlBtn    = makeToolbarBtn(symbol: "arrow.down.to.line", label: "下载大纲", action: #selector(downloadTapped))

        // 渐变"挑选PPT模板"按钮
        templateBtn.setTitle("挑选PPT模板  →", for: .normal)
        templateBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        templateBtn.setTitleColor(.white, for: .normal)
        templateBtn.layer.cornerRadius = 22
        templateBtn.clipsToBounds = true
        templateBtn.addTarget(self, action: #selector(templateTapped), for: .touchUpInside)
        templateBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(templateBtn)

        let grad = CAGradientLayer()
        grad.colors     = [UIColor.appGradientStart.cgColor,
                           UIColor.appGradientMid.cgColor,
                           UIColor.appGradientEnd.cgColor]
        grad.locations  = [0, 0.5, 1]
        grad.startPoint = CGPoint(x: 0, y: 0.5)
        grad.endPoint   = CGPoint(x: 1, y: 0.5)
        templateBtn.layer.insertSublayer(grad, at: 0)
        templateGrad = grad

        // 流式阶段不显示工具栏
        bottomBar.isHidden = true

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sep.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            checkImg.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 10),
            checkImg.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            checkImg.widthAnchor.constraint(equalToConstant: 14),
            checkImg.heightAnchor.constraint(equalToConstant: 14),

            hintLbl.centerYAnchor.constraint(equalTo: checkImg.centerYAnchor),
            hintLbl.leadingAnchor.constraint(equalTo: checkImg.trailingAnchor, constant: 6),

            regenBtn.topAnchor.constraint(equalTo: checkImg.bottomAnchor, constant: 8),
            regenBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            regenBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            regenBtn.heightAnchor.constraint(equalToConstant: 44),

            dlBtn.centerYAnchor.constraint(equalTo: regenBtn.centerYAnchor),
            dlBtn.leadingAnchor.constraint(equalTo: regenBtn.trailingAnchor, constant: 8),
            dlBtn.heightAnchor.constraint(equalToConstant: 44),

            templateBtn.centerYAnchor.constraint(equalTo: regenBtn.centerYAnchor),
            templateBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            templateBtn.heightAnchor.constraint(equalToConstant: 44),
            templateBtn.leadingAnchor.constraint(greaterThanOrEqualTo: dlBtn.trailingAnchor, constant: 12),
            templateBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
        ])
    }

    @discardableResult
    private func makeToolbarBtn(symbol: String, label: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        var cfg = UIButton.Configuration.plain()
        cfg.image           = UIImage(systemName: symbol)
        cfg.title           = label
        cfg.imagePadding    = 6
        cfg.baseForegroundColor = .secondaryLabel
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = .systemFont(ofSize: 12); return a
        }
        btn.configuration = cfg
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(btn)
        return btn
    }

    private func setupTableView() {
        tableView.dataSource     = self
        tableView.delegate       = self
        tableView.isHidden       = true
        tableView.alpha          = 0
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle  = .none
        tableView.register(OutlineHeaderCell.self,  forCellReuseIdentifier: OutlineHeaderCell.reuseID)
        tableView.register(OutlineBulletCell.self,  forCellReuseIdentifier: OutlineBulletCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
        ])
    }

    // MARK: - 键盘处理

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info     = notification.userInfo,
              let kbValue  = info[UIResponder.keyboardFrameEndUserInfoKey]         as? NSValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey]    as? UInt
        else { return }

        let kbHeight = kbValue.cgRectValue.height - view.safeAreaInsets.bottom
        let inset    = UIEdgeInsets(top: 0, left: 0, bottom: kbHeight, right: 0)
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.tableView.contentInset                = inset
            self.tableView.verticalScrollIndicatorInsets = inset
        }
        // 把正在编辑的 cell 滚到键盘上方可见区域
        if let ip = activeIndexPath {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.tableView.scrollToRow(at: ip, at: .none, animated: true)
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info     = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey]    as? UInt
        else { return }
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.tableView.contentInset                = .zero
            self.tableView.verticalScrollIndicatorInsets = .zero
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - SSE 流式生成

    private func startSSE() {
        sseTask = PPTAPIService.shared.generateContent(
            taskId:   taskId,
            language: language,
            length:   length,
            scene:    scene,
            audience: audience,
            onChunk: { [weak self] chunk in
                guard let self else { return }
                self.accumulatedMarkdown += chunk
                print("📝 chunk(\(chunk.count)): \(chunk.prefix(60))")
                self.streamLabel.attributedText = self.renderMarkdown(self.accumulatedMarkdown)
                // 滚到底部跟随流式输出；max 下界为 -adjustedContentInset.top 确保第一行始终在导航栏下方
                let sv  = self.streamScrollView
                let top = -sv.adjustedContentInset.top
                let bot = sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom
                sv.setContentOffset(CGPoint(x: 0, y: max(top, bot)), animated: false)
            },
            onComplete: { [weak self] fullMarkdown in
                guard let self else { return }
                print("✅ 大纲生成完成，length=\(fullMarkdown.count)")
                self.accumulatedMarkdown = fullMarkdown
                self.transitionToEditable()
            },
            onError: { [weak self] error in
                guard let self else { return }
                self.spinner.stopAnimating()
                self.spinnerLabel.text = "生成失败"
                let alert = UIAlertController(title: "生成失败",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "返回", style: .default) { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                })
                self.present(alert, animated: true)
            }
        )
    }

    // MARK: - Markdown 渲染（流式阶段）

    /// 将 markdown 文本转换为带样式的 NSAttributedString
    // 间距规范：
    //   主题(#)    spacingBefore=8
    //   章节(##)   spacingBefore=24  —— 每章节前大间距
    //   h3(###)    spacingBefore=16  —— 章节内一级子标题
    //   h4(####)   spacingBefore=10  —— 二级子标题
    //   body       spacingBefore=4, spacingAfter=4  —— 正文前后各留一点
    private func renderMarkdown(_ md: String) -> NSAttributedString {
        let result   = NSMutableAttributedString()
        let purple   = UIColor.appPrimary
        let purpleBg = UIColor.appPrimarySubtle
        var isFirst  = true

        for line in md.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            // 跳过空行，避免产生大段空白
            if t.isEmpty { continue }

            let lineAttr: NSAttributedString
            if t.hasPrefix("# ") {
                lineAttr = taggedLine(tag: "主题", text: String(t.dropFirst(2)),
                                      tagFg: purple, tagBg: purpleBg,
                                      textFont: .boldSystemFont(ofSize: 18), spacingBefore: 8)
            } else if t.hasPrefix("## ") {
                lineAttr = taggedLine(tag: "章节", text: String(t.dropFirst(3)),
                                      tagFg: purple, tagBg: purpleBg,
                                      textFont: .boldSystemFont(ofSize: 16), spacingBefore: 24)
            } else if t.hasPrefix("### ") {
                lineAttr = plainLine("• " + String(t.dropFirst(4)),
                                     font: .boldSystemFont(ofSize: 14), color: .label,
                                     indent: 0, spacingBefore: 16, spacingAfter: 2)
            } else if t.hasPrefix("#### ") {
                // 与卡片视图统一，使用 ○
                lineAttr = plainLine("  ○ " + String(t.dropFirst(5)),
                                     font: .systemFont(ofSize: 13), color: .label,
                                     indent: 16, spacingBefore: 10, spacingAfter: 0)
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                lineAttr = plainLine("• " + String(t.dropFirst(2)),
                                     font: .systemFont(ofSize: 14), color: .label,
                                     indent: 0, spacingBefore: 16, spacingAfter: 2)
            } else {
                // body 文本限制一行：约 30 个汉字 ≈ 一屏行宽（indent=28 占用约 28pt）
                let preview = t.count > 30 ? String(t.prefix(30)) + "..." : t
                lineAttr = plainLine(preview, font: .systemFont(ofSize: 12),
                                     color: .secondaryLabel, indent: 28, spacingBefore: 4, spacingAfter: 4)
            }

            if !isFirst { result.append(NSAttributedString(string: "\n")) }
            result.append(lineAttr)
            isFirst = false
        }
        return result
    }

    /// 生成带圆角的 badge 图片，用于流式阶段的标签（NSTextAttachment 不支持 backgroundColor 圆角）
    private func makeBadgeImage(text: String, fg: UIColor, bg: UIColor) -> UIImage {
        let font     = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let hPad: CGFloat = 6
        let vPad: CGFloat = 3
        let imgSize = CGSize(width: textSize.width + hPad * 2, height: textSize.height + vPad * 2)

        return UIGraphicsImageRenderer(size: imgSize).image { ctx in
            bg.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: imgSize), cornerRadius: 4).fill()
            (text as NSString).draw(at: CGPoint(x: hPad, y: vPad), withAttributes: attrs)
        }
    }

    private func taggedLine(tag: String, text: String,
                            tagFg: UIColor, tagBg: UIColor,
                            textFont: UIFont, spacingBefore: CGFloat = 0) -> NSAttributedString {
        let r  = NSMutableAttributedString()
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = spacingBefore

        // 使用圆角图片作为 badge，避免 .backgroundColor 无圆角问题
        let badgeImg   = makeBadgeImage(text: tag, fg: tagFg, bg: tagBg)
        let attachment = NSTextAttachment()
        attachment.image = badgeImg
        // 以 capHeight 为参考让 badge 垂直居中，确保与文字基线对齐
        let capH = textFont.capHeight
        let imgH = badgeImg.size.height
        attachment.bounds = CGRect(x: 0,
                                   y: (capH - imgH) / 2,
                                   width: badgeImg.size.width,
                                   height: imgH)

        let attachStr = NSMutableAttributedString(attachment: attachment)
        attachStr.addAttribute(.paragraphStyle, value: ps,
                               range: NSRange(location: 0, length: attachStr.length))
        r.append(attachStr)

        r.append(NSAttributedString(string: "  \(text)", attributes: [
            .font:            textFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle:  ps,
        ]))
        return r
    }

    private func plainLine(_ text: String, font: UIFont, color: UIColor,
                           indent: CGFloat, spacingBefore: CGFloat = 0,
                           spacingAfter: CGFloat = 0) -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.firstLineHeadIndent    = indent
        ps.headIndent             = indent
        ps.paragraphSpacingBefore = spacingBefore
        ps.paragraphSpacing       = spacingAfter
        return NSAttributedString(string: text, attributes: [
            .font:            font,
            .foregroundColor: color,
            .paragraphStyle:  ps,
        ])
    }

    // MARK: - 完成后切换到可编辑卡片视图

    private func transitionToEditable() {
        spinner.stopAnimating()
        spinnerLabel.isHidden = true

        sections = MarkdownParser.parse(accumulatedMarkdown)
        tableView.reloadData()
        tableView.isHidden = false
        bottomBar.isHidden = false

        UIView.animate(withDuration: 0.3) {
            self.streamScrollView.alpha = 0
            self.spinner.alpha          = 0
        } completion: { _ in
            self.streamScrollView.isHidden = true
            UIView.animate(withDuration: 0.3) {
                self.tableView.alpha = 1
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        sseTask?.cancel()
        navigationController?.popViewController(animated: true)
    }

    @objc private func regenerateTapped() {
        sseTask?.cancel()
        navigationController?.popViewController(animated: true)
    }

    @objc private func downloadTapped() {
        // TODO: 下载大纲功能
    }

    @objc private func templateTapped() {
        // TODO: 跳转模板选择页
    }
}

// MARK: - UITableViewDataSource / Delegate

extension OutlineViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    /// 每个 section 第 0 行是 header（tag badge + title），其余是 bullet
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1 + sections[section].bullets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sec = sections[indexPath.section]
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: OutlineHeaderCell.reuseID, for: indexPath) as! OutlineHeaderCell
            cell.configure(tag: sec.tagLabel, title: sec.title)
            return cell
        }
        let bullet = sec.bullets[indexPath.row - 1]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: OutlineBulletCell.reuseID, for: indexPath) as! OutlineBulletCell
        cell.configure(with: bullet)
        return cell
    }

    // 不需要默认 section header/footer，卡片已由 insetGrouped 提供
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int)  -> UIView? { nil }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int)  -> UIView? { UIView() }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        activeIndexPath = indexPath
        if indexPath.row == 0 {
            (tableView.cellForRow(at: indexPath) as? OutlineHeaderCell)?.beginEditing()
        } else {
            (tableView.cellForRow(at: indexPath) as? OutlineBulletCell)?.beginEditing()
        }
    }
}

// MARK: - OutlineHeaderCell（卡片标题行：tag badge + 可编辑标题）

private class OutlineHeaderCell: UITableViewCell {
    static let reuseID = "OutlineHeaderCell"

    private let badgeLabel = UILabel()
    private let badgeBg    = UIView()
    private let titleView  = UITextView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        // Badge 背景
        badgeBg.backgroundColor    = .appPrimarySubtle
        badgeBg.layer.cornerRadius = 4
        badgeBg.translatesAutoresizingMaskIntoConstraints = false

        // badge 文字永不被压缩，保证完整显示
        badgeLabel.font      = .systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = .appPrimary
        badgeLabel.numberOfLines = 1
        badgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeBg.addSubview(badgeLabel)

        // 可编辑标题
        titleView.font                              = .systemFont(ofSize: 16, weight: .semibold)
        titleView.isScrollEnabled                   = false
        titleView.textContainerInset                = UIEdgeInsets(top: 1, left: 0, bottom: 1, right: 0)
        titleView.textContainer.lineFragmentPadding = 0
        titleView.backgroundColor                   = .clear
        titleView.translatesAutoresizingMaskIntoConstraints = false

        // UIStackView 自动处理 badge 与 titleView 的垂直居中
        let stack = UIStackView(arrangedSubviews: [badgeBg, titleView])
        stack.axis      = .horizontal
        stack.spacing   = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: badgeBg.topAnchor, constant: 3),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeBg.bottomAnchor, constant: -3),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeBg.leadingAnchor, constant: 6),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeBg.trailingAnchor, constant: -6),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(tag: String, title: String) {
        badgeLabel.text = tag
        titleView.text  = title
    }

    func beginEditing() { titleView.becomeFirstResponder() }
}

// MARK: - OutlineBulletCell（可编辑子条目）

private class OutlineBulletCell: UITableViewCell {
    static let reuseID = "OutlineBulletCell"

    private let textView = UITextView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        textView.isScrollEnabled              = false
        textView.textContainerInset           = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor              = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with bullet: OutlineBullet) {
        let (prefix, font, color, indent) = style(for: bullet.level)
        let ps = NSMutableParagraphStyle()
        ps.firstLineHeadIndent = indent
        ps.headIndent          = indent + (prefix.isEmpty ? 0 : 12)
        textView.attributedText = NSAttributedString(string: prefix + bullet.text, attributes: [
            .font:           font,
            .foregroundColor: color,
            .paragraphStyle: ps,
        ])
    }

    func beginEditing() { textView.becomeFirstResponder() }

    private func style(for level: OutlineBullet.Level) -> (String, UIFont, UIColor, CGFloat) {
        switch level {
        case .h3:   return ("• ",  .boldSystemFont(ofSize: 14),  .label,           0)
        case .h4:   return ("○ ",  .systemFont(ofSize: 13),      .label,           16)
        case .body: return ("",    .systemFont(ofSize: 12),      .secondaryLabel,  32)
        }
    }
}
