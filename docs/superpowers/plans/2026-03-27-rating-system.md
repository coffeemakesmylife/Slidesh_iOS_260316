# 评分引导系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在关键用户行为节点触发自定义满意度弹窗（SatisfactionSheet），满意则引导系统评分/App Store，不满意则进入反馈页。

**Architecture:** 以 `RatingManager` 单例统一管理触发逻辑（全局只弹一次），`SatisfactionSheet` 为纯 UIView 直接挂载到 UIWindow，无需依赖 presenting VC。触发点散落在 6 个 VC，通过 `RatingManager.shared.trigger(from:)` 统一调用。

**Tech Stack:** UIKit, StoreKit（SKStoreReviewController），UserDefaults，CAGradientLayer，UIView.animate spring

---

## 文件清单

| 操作 | 路径 | 说明 |
|------|------|------|
| 修改 | `Slidesh/AppConfig.swift` | 添加 `appStoreReviewURL` 常量 |
| 新建 | `Slidesh/Views/SatisfactionSheet.swift` | 满意度底部弹窗 UIView |
| 新建 | `Slidesh/Managers/RatingManager.swift` | 触发逻辑 + 回调处理单例 |
| 修改 | `Slidesh/ViewControllers/PPTPreviewViewController.swift` | 新增 `source` 参数 + T2/T7 |
| 修改 | `Slidesh/ViewControllers/TemplateSelectorViewController.swift` | 传入 `.templateFlow` |
| 修改 | `Slidesh/ViewControllers/MyWorksViewController.swift` | 传入 `.myWorks` + T6 |
| 修改 | `Slidesh/ViewControllers/OutlineViewController.swift` | T1/T8 |
| 修改 | `Slidesh/ViewControllers/ConvertJobViewController.swift` | T4 |
| 修改 | `Slidesh/ViewControllers/SettingsViewController.swift` | Debug 测试按钮 |

---

## Task 1：AppConfig 添加 App Store 评分 URL

**Files:**
- Modify: `Slidesh/AppConfig.swift`

- [ ] **Step 1：在 `AppConfig` 末尾（`save` 方法之后）添加 `appStoreReviewURL`**

在 `AppConfig.swift` 的 `}` 之前插入：

```swift
    // MARK: - App Store

    /// App Store 评分页直链（enable_star_or_comment == false 时使用）
    /// TODO: 上线前替换为正式 Apple ID（数字）
    static let appStoreReviewURL = "https://apps.apple.com/app/id6900000000?action=write-review"
```

- [ ] **Step 2：Commit**

```bash
git add Slidesh/AppConfig.swift
git commit -m "feat: 添加 App Store 评分 URL 常量"
```

---

## Task 2：创建 SatisfactionSheet UIView

**Files:**
- Create: `Slidesh/Views/SatisfactionSheet.swift`

- [ ] **Step 1：新建文件并写入完整实现**

```swift
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
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))

        // 卡片（仅上方两角圆角）
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 24
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // ---- 卡片内容 ----

        // 拖拽指示条
        let pill = UIView()
        pill.backgroundColor = UIColor.black.withAlphaComponent(0.1)
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
            UIColor(red: 122/255, green: 89/255,  blue: 255/255, alpha: 1).cgColor,
            UIColor(red:  66/255, green: 135/255, blue: 245/255, alpha: 1).cgColor
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
            sv.tintColor  = UIColor.systemGray4
            sv.transform  = CGAffineTransform(scaleX: 0.7, y: 0.7)
            sv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
            sv.translatesAutoresizingMaskIntoConstraints = false
            starStack.addArrangedSubview(sv)
            starViews.append(sv)
        }

        // 标题
        let titleLabel = UILabel()
        titleLabel.text          = "Slidesh 帮到你了吗？"
        titleLabel.font          = .systemFont(ofSize: 22, weight: .black)
        titleLabel.textColor     = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // 正向按钮（渐变背景）
        positiveBtn.setTitle("帮到了，好评 ⭐️", for: .normal)
        positiveBtn.setTitleColor(UIColor(red: 20/255, green: 30/255, blue: 60/255, alpha: 1), for: .normal)
        positiveBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        positiveBtn.layer.cornerRadius = 17
        positiveBtn.layer.masksToBounds = true
        positiveBtn.translatesAutoresizingMaskIntoConstraints = false
        positiveBtn.addTarget(self, action: #selector(positiveTapped), for: .touchUpInside)
        cardView.addSubview(positiveBtn)

        let posGrad = CAGradientLayer()
        posGrad.colors = [
            UIColor(red: 130/255, green: 100/255, blue: 255/255, alpha: 1).cgColor,
            UIColor(red:  80/255, green: 160/255, blue: 255/255, alpha: 1).cgColor
        ]
        posGrad.startPoint = CGPoint(x: 0, y: 0.5)
        posGrad.endPoint   = CGPoint(x: 1, y: 0.5)
        positiveBtn.layer.insertSublayer(posGrad, at: 0)
        positiveBtnGradient = posGrad

        // 负向按钮（灰色文字）
        negativeBtn.setTitle("有建议，说一下", for: .normal)
        negativeBtn.setTitleColor(.secondaryLabel, for: .normal)
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
        iconCardGradient?.frame    = iconCardGradient.map { _ in
            CGRect(origin: .zero, size: CGSize(width: 80, height: 80))
        } ?? .zero
    }

    // MARK: - 显示 / 隐藏

    /// 挂载到 window 并执行进场动画
    func show(in window: UIWindow) {
        frame = window.bounds
        window.addSubview(self)

        // 初始状态：卡片在屏幕下方 + 略微缩小
        cardView.transform = CGAffineTransform(translationX: 0, y: 60).scaledBy(x: 0.98, y: 0.98)

        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.3,
                       options: [], animations: {
            self.dimView.alpha   = 1
            self.cardView.transform = .identity
        })

        // 星星依次弹入
        for (i, star) in starViews.enumerated() {
            UIView.animate(withDuration: 0.3, delay: 0.2 + Double(i) * 0.07,
                           usingSpringWithDamping: 0.55, initialSpringVelocity: 0,
                           options: [], animations: {
                star.tintColor  = UIColor(red: 1, green: 184/255, blue: 0, alpha: 1)
                star.transform  = CGAffineTransform(scaleX: 1.12, y: 1.12)
            })
        }
    }

    /// 退场动画后移除
    func dismiss() {
        UIView.animate(withDuration: 0.25, animations: {
            self.dimView.alpha = 0
            self.cardView.transform = CGAffineTransform(translationX: 0, y: 60).scaledBy(x: 0.96, y: 0.96)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    // MARK: - Actions

    @objc private func dimTapped() {
        dismiss()
    }

    @objc private func positiveTapped() {
        guard !hasHandledAction else { return }
        hasHandledAction = true

        // 0.4s 高亮 feedback
        UIView.animate(withDuration: 0.15, animations: {
            self.positiveBtn.alpha = 0.6
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) { self.positiveBtn.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.dismiss()
                self.onPositive?()
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.dismiss()
                self.onNegative?()
            }
        })
    }
}
```

- [ ] **Step 2：Commit**

```bash
git add Slidesh/Views/SatisfactionSheet.swift
git commit -m "feat: 添加 SatisfactionSheet 满意度底部弹窗"
```

---

## Task 3：创建 RatingManager 单例

**Files:**
- Create: `Slidesh/Managers/RatingManager.swift`

- [ ] **Step 1：创建 `Slidesh/Managers/` 目录（Xcode 中手动添加 Group，或直接建文件由 Xcode 识别）**

- [ ] **Step 2：新建文件并写入完整实现**

```swift
//
//  RatingManager.swift
//  Slidesh
//
//  评分引导系统：统一触发入口，全局只弹一次
//

import UIKit
import StoreKit

// 触发点枚举
enum TriggerPoint {
    case outlineGenerated       // T1：大纲生成完成
    case pptPreviewFromTemplate // T2：从模板流进入 PPT 预览
    case convertSuccess         // T4：格式转换成功
    case myWorksThirdVisit      // T6：第 3 次进入我的作品（有内容）
    case pptPreviewFromMyWorks  // T7：从我的作品打开 PPT 预览
    case outlineDownloaded      // T8：下载大纲
}

final class RatingManager {

    static let shared = RatingManager()
    private init() {}

    // MARK: - 状态

    private let promptedKey = "rating_has_prompted"

    private var hasPrompted: Bool {
        get { UserDefaults.standard.bool(forKey: promptedKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptedKey) }
    }

    // MARK: - 对外接口

    /// 触发点调用：检查是否已弹过，未弹过则展示 SatisfactionSheet
    func trigger(from point: TriggerPoint) {
        guard !hasPrompted else { return }
        DispatchQueue.main.async { self.presentSatisfactionSheet() }
    }

    /// Debug / 设置页直接展示（跳过 hasPrompted 检查）
    func presentSatisfactionSheet() {
        guard let window = keyWindow() else { return }

        hasPrompted = true

        let sheet = SatisfactionSheet()
        sheet.onPositive = { [weak self] in self?.handlePositive() }
        sheet.onNegative = { [weak self] in self?.handleNegative() }
        sheet.show(in: window)
    }

    // MARK: - 回调处理

    private func handlePositive() {
        let useSystemDialog = UserDefaults.standard.bool(forKey: "enable_star_or_comment")
        if useSystemDialog {
            // 系统评分弹窗
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            SKStoreReviewController.requestReview(in: scene)
        } else {
            // 跳转 App Store 评分页
            guard let url = URL(string: AppConfig.appStoreReviewURL) else { return }
            UIApplication.shared.open(url)
        }
    }

    private func handleNegative() {
        guard let topVC = topViewController() else { return }
        let feedbackVC = FeedbackViewController()
        if let nav = topVC.navigationController {
            nav.pushViewController(feedbackVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: feedbackVC)
            topVC.present(nav, animated: true)
        }
    }

    // MARK: - 工具方法

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private func topViewController() -> UIViewController? {
        guard var top = keyWindow()?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
```

- [ ] **Step 3：Commit**

```bash
git add Slidesh/Managers/RatingManager.swift
git commit -m "feat: 添加 RatingManager 评分引导单例"
```

---

## Task 4：PPTPreviewViewController 新增 source 参数（T2/T7 基础）

**Files:**
- Modify: `Slidesh/ViewControllers/PPTPreviewViewController.swift`

- [ ] **Step 1：在文件顶部（class 声明之前）添加 `PPTPreviewSource` 枚举**

在 `class PPTPreviewViewController` 之前插入：

```swift
/// PPT 预览来源，用于区分评分触发时机
enum PPTPreviewSource {
    case templateFlow   // 从模板流（TemplateSelectorViewController）进入 → T2
    case myWorks        // 从我的作品进入 → T7
    case other          // 其他来源，不触发评分
}
```

- [ ] **Step 2：在 `PPTPreviewViewController` 中添加 `source` 属性并更新 init**

找到当前 init（约 L40-46）：
```swift
    init(pptInfo: PPTInfo, canChangeTemplate: Bool = false) {
        self.pptInfo = pptInfo
        self.canChangeTemplate = canChangeTemplate
        super.init(nibName: nil, bundle: nil)
    }
```

替换为：
```swift
    private let source: PPTPreviewSource

    init(pptInfo: PPTInfo, canChangeTemplate: Bool = false, source: PPTPreviewSource = .other) {
        self.pptInfo = pptInfo
        self.canChangeTemplate = canChangeTemplate
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }
```

- [ ] **Step 3：在 `viewDidAppear` 中插入评分触发逻辑**

找到现有的 `viewDidAppear`（如果有），或在 `viewDidLoad` 之后添加：

```swift
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 根据来源触发评分
        switch source {
        case .templateFlow: RatingManager.shared.trigger(from: .pptPreviewFromTemplate)
        case .myWorks:      RatingManager.shared.trigger(from: .pptPreviewFromMyWorks)
        case .other:        break
        }
    }
```

- [ ] **Step 4：Commit**

```bash
git add Slidesh/ViewControllers/PPTPreviewViewController.swift
git commit -m "feat: PPTPreviewViewController 新增 source 参数，集成 T2/T7 评分触发"
```

---

## Task 5：更新 PPTPreviewViewController 的调用方

**Files:**
- Modify: `Slidesh/ViewControllers/TemplateSelectorViewController.swift`
- Modify: `Slidesh/ViewControllers/MyWorksViewController.swift`

- [ ] **Step 1：TemplateSelectorViewController — 两处 init 加 `source: .templateFlow`**

找到（约 L655）：
```swift
let previewVC = PPTPreviewViewController(pptInfo: info)
self.navigationController?.pushViewController(previewVC, animated: true)
```
替换为：
```swift
let previewVC = PPTPreviewViewController(pptInfo: info, source: .templateFlow)
self.navigationController?.pushViewController(previewVC, animated: true)
```

找到（约 L662）：
```swift
let previewVC = PPTPreviewViewController(pptInfo: stub)
self.navigationController?.pushViewController(previewVC, animated: true)
```
替换为：
```swift
let previewVC = PPTPreviewViewController(pptInfo: stub, source: .templateFlow)
self.navigationController?.pushViewController(previewVC, animated: true)
```

- [ ] **Step 2：MyWorksViewController — init 加 `source: .myWorks`**

找到（约 L336）：
```swift
navigationController?.pushViewController(PPTPreviewViewController(pptInfo: info, canChangeTemplate: true), animated: true)
```
替换为：
```swift
navigationController?.pushViewController(PPTPreviewViewController(pptInfo: info, canChangeTemplate: true, source: .myWorks), animated: true)
```

- [ ] **Step 3：Commit**

```bash
git add Slidesh/ViewControllers/TemplateSelectorViewController.swift Slidesh/ViewControllers/MyWorksViewController.swift
git commit -m "feat: 更新 PPTPreviewViewController 调用方，传入 source 参数"
```

---

## Task 6：集成 T1/T8（OutlineViewController）

**Files:**
- Modify: `Slidesh/ViewControllers/OutlineViewController.swift`

- [ ] **Step 1：T1 — 在 `transitionToEditable()` 末尾触发**

找到 `transitionToEditable()` 方法（约 L641）。在方法最后一行（`}`之前）添加：

```swift
        // T1：大纲生成完成，触发评分引导
        RatingManager.shared.trigger(from: .outlineGenerated)
```

- [ ] **Step 2：T8 — 在 `exportMarkdown()` 和 `exportPlainText()` 中 present 之前触发**

在 `exportMarkdown()` 中，找到：
```swift
        let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = bottomBar
        present(vc, animated: true)
```
在 `present(vc, animated: true)` 之前插入：
```swift
        // T8：下载大纲，触发评分引导
        RatingManager.shared.trigger(from: .outlineDownloaded)
```

在 `exportPlainText()` 中同样操作，找到末尾的：
```swift
        let vc = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = bottomBar
        present(vc, animated: true)
```
在 `present(vc, animated: true)` 之前插入：
```swift
        // T8：下载大纲，触发评分引导
        RatingManager.shared.trigger(from: .outlineDownloaded)
```

- [ ] **Step 3：Commit**

```bash
git add Slidesh/ViewControllers/OutlineViewController.swift
git commit -m "feat: OutlineViewController 集成 T1/T8 评分触发点"
```

---

## Task 7：集成 T4（ConvertJobViewController）

**Files:**
- Modify: `Slidesh/ViewControllers/ConvertJobViewController.swift`

- [ ] **Step 1：在 `state = .success(resultURLs: urls)` 之后插入触发**

找到（约 L682）：
```swift
                    state = .success(resultURLs: urls)
```
在其后插入：
```swift
                    // T4：格式转换成功，触发评分引导
                    RatingManager.shared.trigger(from: .convertSuccess)
```

- [ ] **Step 2：Commit**

```bash
git add Slidesh/ViewControllers/ConvertJobViewController.swift
git commit -m "feat: ConvertJobViewController 集成 T4 评分触发点"
```

---

## Task 8：集成 T6（MyWorksViewController.viewDidAppear）

**Files:**
- Modify: `Slidesh/ViewControllers/MyWorksViewController.swift`

- [ ] **Step 1：在文件属性区域添加访问计数器**

找到（约 L135）：
```swift
    private var ppts:     [PPTInfo]       = []
    private var outlines: [OutlineRecord] = []
```
在其后添加：
```swift
    // T6：记录进入页面次数，第3次且有作品时触发评分
    private var visitCount = 0
```

- [ ] **Step 2：重写 viewDidAppear，在数据加载完成后检查**

在 `viewDidLoad` 之后添加：
```swift
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        visitCount += 1
        // T6：第3次进入且已有 PPT 作品时触发
        if visitCount == 3, !ppts.isEmpty {
            RatingManager.shared.trigger(from: .myWorksThirdVisit)
        }
    }
```

> **注意：** `ppts` 在 `viewDidAppear` 时可能尚未加载（数据是异步拉取的）。如果测试时发现 `ppts` 为空，需改为在数据加载回调末尾判断，条件改为 `visitCount >= 3`。

- [ ] **Step 3：Commit**

```bash
git add Slidesh/ViewControllers/MyWorksViewController.swift
git commit -m "feat: MyWorksViewController 集成 T6 评分触发点"
```

---

## Task 9：SettingsViewController 添加 Debug 测试按钮

**Files:**
- Modify: `Slidesh/ViewControllers/SettingsViewController.swift`

- [ ] **Step 1：在 `makeDebugSection` 的 card rows 中追加测试评分弹窗行**

找到 `makeDebugSection()` 中的 `makeCard(rows: [` 数组（约 L545），在最后一个 `makeRow(...)` 之后、`])` 之前添加：

```swift
            makeRow(sfSymbol: "star.bubble", title: "测试评分弹窗") {
                RatingManager.shared.presentSatisfactionSheet()
            },
```

> **注意：** `presentSatisfactionSheet()` 内部会将 `hasPrompted` 置为 `true`。测试时如需反复弹出，可在此处先 `UserDefaults.standard.removeObject(forKey: "rating_has_prompted")` 再调用，或在 Debug 行改为直接构造 `SatisfactionSheet` 实例。

若需要可重复测试，改为：

```swift
            makeRow(sfSymbol: "star.bubble", title: "测试评分弹窗（可重复）") { [weak self] in
                UserDefaults.standard.removeObject(forKey: "rating_has_prompted")
                RatingManager.shared.presentSatisfactionSheet()
            },
```

- [ ] **Step 2：Commit**

```bash
git add Slidesh/ViewControllers/SettingsViewController.swift
git commit -m "feat: SettingsViewController Debug 区添加评分弹窗测试入口"
```

---

## 自检

### Spec 覆盖情况
- [x] 全局只弹一次（`rating_has_prompted`）→ Task 3
- [x] `enable_star_or_comment` 分支（系统弹窗 vs App Store URL）→ Task 3
- [x] SatisfactionSheet 视觉结构（drag bar / icon card / stars / 渐变按钮 / 文字按钮）→ Task 2
- [x] 星星依次弹入动画（spring, delay +0.07s）→ Task 2
- [x] `hasHandledAction` 防双击 → Task 2
- [x] 0.4s 颜色 feedback → Task 2
- [x] T1 OutlineVC.transitionToEditable → Task 6
- [x] T2 PPTPreviewVC from templateFlow → Task 4
- [x] T4 ConvertJobVC .success → Task 7
- [x] T6 MyWorksVC 第3次（有内容）→ Task 8
- [x] T7 PPTPreviewVC from myWorks → Task 4
- [x] T8 OutlineVC 下载大纲 → Task 6
- [x] Debug 测试按钮 → Task 9
- [x] `FeedbackViewController` 负向回调 → Task 3

### 类型一致性
- `TriggerPoint` 定义在 `RatingManager.swift`，所有触发点调用 `.outlineGenerated` / `.pptPreviewFromTemplate` / `.convertSuccess` / `.myWorksThirdVisit` / `.pptPreviewFromMyWorks` / `.outlineDownloaded`，与 Task 6/7/8/4 中的调用一致。
- `PPTPreviewSource` 定义在 `PPTPreviewViewController.swift`，调用方传入 `.templateFlow` / `.myWorks`，与 Task 5 一致。
- `SatisfactionSheet.show(in:)` 接收 `UIWindow`，`RatingManager` 中传入 `keyWindow()`，接口匹配。
