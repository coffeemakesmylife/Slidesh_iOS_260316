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
        // 去除服务端可能附在内容末尾的 [DONE]
        let md = md.replacingOccurrences(of: "[DONE]", with: "")
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
    private var sseTask:    URLSessionDataTask?
    private var updateTask: URLSessionDataTask?  // updateContent SSE 任务句柄
    private var sections: [OutlineSection] = []
    private var activeIndexPath: IndexPath?   // 当前正在编辑的 cell 位置（用于键盘滚动）

    // 渲染节流：每 80ms 最多重渲一次，避免频繁 renderMarkdown 卡主线程
    private var renderPending = false
    // badge 图片缓存：主题/章节/目录固定样式，NSCache 线程安全
    private let badgeImageCache = NSCache<NSString, UIImage>()

    // 流式展示
    private let streamScrollView = UIScrollView()
    private let streamLabel      = UILabel()
    private let spinner          = UIActivityIndicatorView(style: .medium)
    private let spinnerLabel     = UILabel()
    private let spinnerStack     = UIStackView()  // spinner + label 的容器，整体居中

    // 卡片编辑
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // 底部工具栏
    private let bottomBar    = UIView()
    private let templateBtn  = UIButton(type: .custom)
    private var templateGrad: CAGradientLayer?
    private var bottomGradLayer: CAGradientLayer?  // 渐变淡入遮罩

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
        addMeshGradientBackground()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"), style: .plain,
            target: self, action: #selector(backTapped))
        hidesBottomBarWhenPushed = true

        setupBottomBar()
        setupStreamView()
        setupTableView()
        // bottomBar 渐变叠加在 tableView/streamScrollView 上方，需要最后提升 z-order
        view.bringSubviewToFront(bottomBar)
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
        templateGrad?.frame   = templateBtn.bounds
        bottomGradLayer?.frame = bottomBar.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        // 深浅色切换时清除 badge 图片缓存，确保重新渲染时使用正确颜色
        badgeImageCache.removeAllObjects()
        if !streamScrollView.isHidden {
            streamLabel.attributedText = renderMarkdown(accumulatedMarkdown)
        }
        // CAGradientLayer 的 cgColor 不自动跟随 trait，需手动刷新
        updateBottomGradColors()
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

        spinnerLabel.text      = "大纲生成中，请不要退出..."
        spinnerLabel.font      = .systemFont(ofSize: 13)
        spinnerLabel.textColor = .secondaryLabel

        // 用 spinnerStack 让 spinner + label 作为整体居中，文案变化也不会偏移
        spinnerStack.axis      = .horizontal
        spinnerStack.spacing   = 8
        spinnerStack.alignment = .center
        spinnerStack.addArrangedSubview(spinner)
        spinnerStack.addArrangedSubview(spinnerLabel)
        spinnerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinnerStack)

        NSLayoutConstraint.activate([
            streamScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            streamScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            streamScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            streamScrollView.bottomAnchor.constraint(equalTo: spinnerStack.topAnchor, constant: -12),

            // 内容标签撑开 contentSize
            streamLabel.topAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.topAnchor, constant: 16),
            streamLabel.leadingAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            streamLabel.trailingAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            streamLabel.bottomAnchor.constraint(equalTo: streamScrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            streamLabel.widthAnchor.constraint(equalTo: streamScrollView.frameLayoutGuide.widthAnchor, constant: -32),

            // spinnerStack 整体居中，固定在 safeArea 底部
            spinnerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinnerStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func setupBottomBar() {
        // 透明容器，通过渐变层实现自然淡入效果，无实体背景和分割线
        bottomBar.backgroundColor = .clear
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        let gradBg = CAGradientLayer()
        gradBg.startPoint = CGPoint(x: 0.5, y: 0)
        gradBg.endPoint   = CGPoint(x: 0.5, y: 1)
        bottomBar.layer.insertSublayer(gradBg, at: 0)
        bottomGradLayer = gradBg
        updateBottomGradColors()

        // edit-fill 图标 + hint
        let checkImg = UIImageView(image: UIImage(named: "edit-fill")?.withRenderingMode(.alwaysTemplate))
        checkImg.tintColor = .systemGreen
        checkImg.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(checkImg)

        let hintLbl = UILabel()
        hintLbl.text      = "AI生成内容仅供参考，点击可编辑操作"
        hintLbl.font      = .systemFont(ofSize: 12)
        hintLbl.textColor = .secondaryLabel
        hintLbl.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(hintLbl)

        // 换个大纲 & 下载大纲（使用自定义图片，alwaysTemplate 保留当前颜色）
        let regenBtn = makeToolbarBtn(image: UIImage(named: "refresh-line"),      label: "换个大纲", action: #selector(regenerateTapped))
        let dlBtn    = makeToolbarBtn(image: UIImage(named: "file-download-line"), label: "下载大纲", action: #selector(downloadTapped))

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

            checkImg.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 48),
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

    /// 根据当前 trait 更新渐变遮罩颜色（深浅色模式切换时调用）
    private func updateBottomGradColors() {
        let bg = UIColor.systemGroupedBackground
        bottomGradLayer?.colors   = [bg.withAlphaComponent(0).cgColor,
                                     bg.withAlphaComponent(0.92).cgColor,
                                     bg.cgColor]
        bottomGradLayer?.locations = [0, 0.30, 1]
    }

    @discardableResult
    private func makeToolbarBtn(image: UIImage?, label: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        var cfg = UIButton.Configuration.plain()
        cfg.image           = image?.withRenderingMode(.alwaysTemplate)
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
        tableView.backgroundColor = .clear
        tableView.separatorStyle  = .none
        tableView.register(OutlineHeaderCell.self,  forCellReuseIdentifier: OutlineHeaderCell.reuseID)
        tableView.register(OutlineBulletCell.self,  forCellReuseIdentifier: OutlineBulletCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // 延伸到屏幕底部，bottomBar 以透明渐变叠加其上
        tableView.contentInset.bottom = 120
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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

    // MARK: - 流式渲染（节流）

    /// 节流渲染（主线程）：80ms 内最多渲染一次
    /// UIColor.label 等自适应色需要主线程 TraitCollection，不能移到后台线程
    private func scheduleStreamRender() {
        guard !renderPending else { return }
        renderPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            self.renderPending = false
            let md = self.accumulatedMarkdown
            self.streamLabel.attributedText = self.renderMarkdown(md)
            self.scrollStreamToBottom()
            // 节流窗口内积累了新内容，立即再调度一次
            if self.accumulatedMarkdown != md { self.scheduleStreamRender() }
        }
    }

    private func scrollStreamToBottom() {
        let sv  = streamScrollView
        let top = -sv.adjustedContentInset.top
        let bot = sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom
        sv.setContentOffset(CGPoint(x: 0, y: max(top, bot)), animated: false)
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
                self.scheduleStreamRender()
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
        // 去除服务端可能附在内容末尾的 [DONE]，不在数据积累层处理，避免副作用
        let source   = md.replacingOccurrences(of: "[DONE]", with: "")
        let result   = NSMutableAttributedString()
        // 流式视图背景较深，使用 chip 专用色保证深色模式下 badge 可读
        let purple   = UIColor.appChipUnselectedText
        let purpleBg = UIColor.appChipUnselectedBackground
        var isFirst  = true

        for line in source.components(separatedBy: "\n") {
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
                                     font: .boldSystemFont(ofSize: 14), color: .appTextPrimary,
                                     indent: 0, spacingBefore: 16, spacingAfter: 2)
            } else if t.hasPrefix("#### ") {
                // 与卡片视图统一，使用 ○
                lineAttr = plainLine("  ○ " + String(t.dropFirst(5)),
                                     font: .systemFont(ofSize: 13), color: .appTextPrimary,
                                     indent: 16, spacingBefore: 10, spacingAfter: 0)
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                lineAttr = plainLine("• " + String(t.dropFirst(2)),
                                     font: .systemFont(ofSize: 14), color: .appTextPrimary,
                                     indent: 0, spacingBefore: 16, spacingAfter: 2)
            } else {
                // body 文本限制一行：约 30 个汉字 ≈ 一屏行宽（indent=28 占用约 28pt）
                let preview = t.count > 30 ? String(t.prefix(30)) + "..." : t
                lineAttr = plainLine(preview, font: .systemFont(ofSize: 12),
                                     color: .appTextSecondary, indent: 28, spacingBefore: 4, spacingAfter: 4)
            }

            if !isFirst { result.append(NSAttributedString(string: "\n")) }
            result.append(lineAttr)
            isFirst = false
        }
        return result
    }

    /// 生成带圆角的 badge 图片，结果按文字缓存避免重复渲染
    private func makeBadgeImage(text: String, fg: UIColor, bg: UIColor) -> UIImage {
        if let cached = badgeImageCache.object(forKey: text as NSString) { return cached }
        let font     = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let hPad: CGFloat = 6
        let vPad: CGFloat = 3
        let imgSize = CGSize(width: textSize.width + hPad * 2, height: textSize.height + vPad * 2)
        let image = UIGraphicsImageRenderer(size: imgSize).image { _ in
            bg.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: imgSize), cornerRadius: 4).fill()
            (text as NSString).draw(at: CGPoint(x: hPad, y: vPad), withAttributes: attrs)
        }
        badgeImageCache.setObject(image, forKey: text as NSString)
        return image
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
            .foregroundColor: UIColor.appTextPrimary,
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

        // 打印前300字符用于调试格式识别问题
        print("📄 markdown前300字符:\n\(accumulatedMarkdown.prefix(300))")
        // 打印所有含 # 的行
        for line in accumulatedMarkdown.components(separatedBy: "\n") {
            if line.hasPrefix("#") { print("  ›› [\(line.prefix(80))]") }
        }

        sections = MarkdownParser.parse(accumulatedMarkdown)
        tableView.reloadData()
        tableView.isHidden = false
        bottomBar.isHidden = false

        UIView.animate(withDuration: 0.3) {
            self.streamScrollView.alpha = 0
            self.spinnerStack.alpha     = 0
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
        // 取消当前请求，重置状态，重新启动流式生成
        sseTask?.cancel()
        accumulatedMarkdown = ""
        sections = []

        // 恢复流式阶段 UI
        streamLabel.text          = nil
        streamScrollView.isHidden = false
        streamScrollView.alpha    = 1
        spinnerStack.alpha        = 1
        spinner.startAnimating()
        spinnerLabel.isHidden     = false
        tableView.isHidden        = true
        tableView.alpha           = 0
        bottomBar.isHidden        = true

        startSSE()
    }

    // MARK: - 从 sections 重建 markdown

    /// 提交当前编辑，并从 sections 重建 markdown（跳过 .toc，由 AI 自动生成）
    func reconstructMarkdown() -> String {
        view.endEditing(true)
        var md = ""
        for section in sections {
            switch section.kind {
            case .toc: continue
            case .theme:
                md += "# \(section.title)\n\n"
            case .chapter:
                md += "## \(section.title)\n"
                for bullet in section.bullets {
                    switch bullet.level {
                    case .h3:   md += "### \(bullet.text)\n"
                    case .h4:   md += "#### \(bullet.text)\n"
                    case .body: md += "\(bullet.text)\n"
                    }
                }
                md += "\n"
            }
        }
        return md
    }

    // MARK: - 下载大纲

    @objc private func downloadTapped() {
        let sheet = DownloadFormatSheet()
        sheet.onMarkdown  = { [weak self] in self?.exportMarkdown() }
        sheet.onPlainText = { [weak self] in self?.exportPlainText() }
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle   = .crossDissolve
        present(sheet, animated: true)
    }

    private func exportMarkdown() {
        let md       = reconstructMarkdown()
        let fileName = "outline_\(taskId).md"
        let tmpURL   = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try md.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            showExportError(error); return
        }
        let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = bottomBar
        present(vc, animated: true)
    }

    private func exportPlainText() {
        var lines: [String] = []
        for section in sections {
            switch section.kind {
            case .theme:
                lines.append("【\(section.title)】\n")
            case .toc:
                lines.append("目录：")
                section.bullets.forEach { lines.append("  \($0.text)") }
                lines.append("")
            case .chapter:
                lines.append("\n▌ \(section.title)")
                for bullet in section.bullets {
                    switch bullet.level {
                    case .h3:   lines.append("  • \(bullet.text)")
                    case .h4:   lines.append("    ○ \(bullet.text)")
                    case .body: lines.append("      \(bullet.text)")
                    }
                }
            }
        }
        let text     = lines.joined(separator: "\n")
        let fileName = "outline_\(taskId).txt"
        let tmpURL   = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try text.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            showExportError(error); return
        }
        let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = bottomBar
        present(vc, animated: true)
    }

    private func showExportError(_ error: Error) {
        let alert = UIAlertController(title: "导出失败", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 挑选 PPT 模板

    @objc private func templateTapped() {
        guard !sections.isEmpty else { return }

        let currentMarkdown = reconstructMarkdown()
        let hasEdits        = currentMarkdown != accumulatedMarkdown
        print("📋 templateTapped: hasEdits=\(hasEdits), markdownLen=\(currentMarkdown.count)")

        setTemplateBtnLoading(true)

        if hasEdits {
            print("🔄 调用 updateContent 同步大纲编辑，taskId=\(taskId)")
            // 有编辑：先同步到服务端，再弹出选择器
            updateTask = PPTAPIService.shared.updateContent(
                taskId:   taskId,
                markdown: currentMarkdown
            ) { [weak self] updatedMarkdown in
                guard let self else { return }
                print("✅ updateContent 成功，返回 markdownLen=\(updatedMarkdown.count)")
                // 服务端返回有效内容才覆盖，避免空结果导致 generatePptx 失败
                if !updatedMarkdown.isEmpty {
                    self.accumulatedMarkdown = updatedMarkdown
                } else {
                    self.accumulatedMarkdown = currentMarkdown
                }
                self.setTemplateBtnLoading(false)
                self.presentTemplateSelector()
            } onError: { [weak self] error in
                // 同步失败不阻断流程，使用本地编辑版本
                guard let self else { return }
                print("❌ updateContent 失败：\(error.localizedDescription)，使用本地 markdown 继续")
                self.accumulatedMarkdown = currentMarkdown
                self.setTemplateBtnLoading(false)
                self.presentTemplateSelector()
            }
        } else {
            print("⏭️ 跳过 updateContent（大纲未修改），直接弹出模板选择器")
            setTemplateBtnLoading(false)
            presentTemplateSelector()
        }
    }

    private func setTemplateBtnLoading(_ loading: Bool) {
        templateBtn.isEnabled = !loading
        if loading {
            templateBtn.setTitle("", for: .normal)
            let s = UIActivityIndicatorView(style: .medium)
            s.color = .white
            s.tag   = 999
            s.startAnimating()
            s.translatesAutoresizingMaskIntoConstraints = false
            templateBtn.addSubview(s)
            NSLayoutConstraint.activate([
                s.centerXAnchor.constraint(equalTo: templateBtn.centerXAnchor),
                s.centerYAnchor.constraint(equalTo: templateBtn.centerYAnchor),
            ])
        } else {
            templateBtn.subviews.first(where: { $0.tag == 999 })?.removeFromSuperview()
            templateBtn.setTitle("挑选PPT模板  →", for: .normal)
        }
    }

    private func presentTemplateSelector() {
        let selector = TemplateSelectorViewController(
            taskId:   taskId,
            markdown: accumulatedMarkdown
        )
        let nav = UINavigationController(rootViewController: selector)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
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
            // 将标题编辑写回 sections
            cell.onTitleChanged = { [weak self] text in
                guard let self, indexPath.section < self.sections.count else { return }
                self.sections[indexPath.section].title = text
            }
            return cell
        }
        let bullet = sec.bullets[indexPath.row - 1]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: OutlineBulletCell.reuseID, for: indexPath) as! OutlineBulletCell
        cell.configure(with: bullet)
        // 将条目编辑写回 sections（回调已去除前缀）
        cell.onTextChanged = { [weak self] text in
            guard let self,
                  indexPath.section < self.sections.count,
                  indexPath.row - 1 < self.sections[indexPath.section].bullets.count
            else { return }
            self.sections[indexPath.section].bullets[indexPath.row - 1].text = text
        }
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

    var onTitleChanged: ((String) -> Void)?  // 标题编辑回调

    private let badgeLabel = UILabel()
    private let badgeBg    = UIView()
    private let titleView  = UITextView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        // backgroundConfiguration 正确集成 insetGrouped 系统圆角机制，避免直接赋值 backgroundColor 导致圆角不一致
        var bgConfig = UIBackgroundConfiguration.listGroupedCell()
        bgConfig.backgroundColor = .appCardBackground.withAlphaComponent(0.7)
        backgroundConfiguration = bgConfig
        titleView.delegate = self

        // Badge 背景（chip 专用色，深浅色模式下均可读）
        badgeBg.backgroundColor    = .appChipUnselectedBackground
        badgeBg.layer.cornerRadius = 4
        badgeBg.translatesAutoresizingMaskIntoConstraints = false

        // badge 文字永不被压缩，保证完整显示
        badgeLabel.font      = .systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = .appChipUnselectedText
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
        onTitleChanged = nil
        badgeLabel.text = tag
        titleView.text  = title
    }

    func beginEditing() { titleView.becomeFirstResponder() }
}

extension OutlineHeaderCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        onTitleChanged?(textView.text ?? "")
    }
}

// MARK: - OutlineBulletCell（可编辑子条目）

private class OutlineBulletCell: UITableViewCell {
    static let reuseID = "OutlineBulletCell"

    var onTextChanged: ((String) -> Void)?  // 条目编辑回调（已去除前缀）
    private var currentLevel: OutlineBullet.Level = .h3

    private let textView = UITextView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        // 使用 backgroundConfiguration 避免干扰 insetGrouped 圆角机制
        var bgConfig = UIBackgroundConfiguration.listGroupedCell()
        bgConfig.backgroundColor = .appCardBackground.withAlphaComponent(0.7)
        backgroundConfiguration = bgConfig
        textView.delegate = self

        textView.isScrollEnabled              = false
        // top=8 上边距；bottom=4 配合 bottomAnchor -4 实现上下对称 8pt 间距
        textView.textContainerInset           = UIEdgeInsets(top: 8, left: 0, bottom: 4, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor              = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with bullet: OutlineBullet) {
        onTextChanged  = nil
        currentLevel   = bullet.level
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
        // 注意：此处同时是前缀去除的依据，修改前缀需同步更新 textViewDidChange
        switch level {
        case .h3:   return ("• ",  .boldSystemFont(ofSize: 14),  .appTextPrimary,   0)
        case .h4:   return ("○ ",  .systemFont(ofSize: 13),      .appTextPrimary,   16)
        case .body: return ("",    .systemFont(ofSize: 12),      .appTextSecondary, 32)
        }
    }
}

extension OutlineBulletCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        // 去除 configure 时附加的前缀，只回传纯内容
        let prefix: String
        switch currentLevel {
        case .h3:   prefix = "• "
        case .h4:   prefix = "○ "
        case .body: prefix = ""
        }
        let text     = textView.text ?? ""
        let stripped = text.hasPrefix(prefix) ? String(text.dropFirst(prefix.count)) : text
        onTextChanged?(stripped)
    }
}

// MARK: - 下载格式选择 Bottom Sheet

/// 自定义底部弹出视图，符合 App 设计语言（圆角卡片 + 渐变背景 + 语义色）
private class DownloadFormatSheet: UIViewController {

    var onMarkdown:  (() -> Void)?
    var onPlainText: (() -> Void)?

    private let card       = UIView()
    private let dimView    = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupDim()
        setupCard()
    }

    private func setupDim() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        // 点击空白区域关闭
        let tap = UITapGestureRecognizer(target: self, action: #selector(dimTapped))
        dimView.addGestureRecognizer(tap)
    }

    private func setupCard() {
        card.backgroundColor    = .appCardBackground
        card.layer.cornerRadius = 20
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        // 标题
        let titleLabel = UILabel()
        titleLabel.text      = "下载大纲"
        titleLabel.font      = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // 副标题
        let subtitleLabel = UILabel()
        subtitleLabel.text      = "选择导出格式"
        subtitleLabel.font      = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .appTextSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subtitleLabel)

        // 两个选项按钮
        let mdBtn  = makeOptionBtn(title: "Markdown 格式 (.md)",  action: #selector(mdTapped))
        let txtBtn = makeOptionBtn(title: "纯文本格式 (.txt)",     action: #selector(txtTapped))

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            mdBtn.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            mdBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mdBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            mdBtn.heightAnchor.constraint(equalToConstant: 52),

            txtBtn.topAnchor.constraint(equalTo: mdBtn.bottomAnchor, constant: 12),
            txtBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            txtBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            txtBtn.heightAnchor.constraint(equalToConstant: 52),
            txtBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    private func makeOptionBtn(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.setTitleColor(.appTextPrimary, for: .normal)
        btn.backgroundColor    = .appChipUnselectedBackground
        btn.layer.cornerRadius = 14
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(btn)
        return btn
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.2) { self.dimView.alpha = 1 }
    }

    @objc private func dimTapped() { dismissSheet() }

    @objc private func mdTapped() {
        dismissSheet { self.onMarkdown?() }
    }

    @objc private func txtTapped() {
        dismissSheet { self.onPlainText?() }
    }

    private func dismissSheet(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: {
            self.dimView.alpha = 0
        }) { _ in
            self.dismiss(animated: true, completion: completion)
        }
    }
}
