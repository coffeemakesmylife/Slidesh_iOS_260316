# Paywall Strategy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为三条核心功能（格式转换/AI大纲/生成PPT）添加 Keychain 配额限制，配合极简半屏付费墙在高价值节点拦截免费用户。

**Architecture:** QuotaManager 单例持有内存缓存的 Premium 状态和 Keychain 配额计数；PaywallSheet 作为轻量半屏入口展示轮播权益并跳转 PremiumViewController；PremiumViewController 新增 `onPurchased` 回调通知订阅成功；各 ViewController 在 `viewWillAppear` 刷新 Premium 状态，在操作触发点同步调用 `consumeIfAvailable()`。

**Tech Stack:** StoreKit 2, Keychain (KeychainHelper 已有), UIKit, UISheetPresentationController

---

## 文件结构

| 文件 | 类型 | 变更 |
|---|---|---|
| `Slidesh/Services/QuotaManager.swift` | 新建 | 配额读写、Premium 状态缓存 |
| `Slidesh/Views/PaywallSheet.swift` | 新建 | 半屏付费墙 UI |
| `Slidesh/ViewControllers/PremiumViewController.swift` | 修改 | 添加 `onPurchased` 回调 |
| `Slidesh/ViewControllers/ConvertViewController.swift` | 修改 | 转换前拦截 |
| `Slidesh/ViewControllers/NewProjectViewController.swift` | 修改 | 生成大纲前拦截 |
| `Slidesh/ViewControllers/OutlineViewController.swift` | 修改 | 重写大纲、生成PPT前拦截 |

---

## Task 1: QuotaManager

**Files:**
- Create: `Slidesh/Services/QuotaManager.swift`

- [ ] **Step 1: 创建 QuotaManager.swift，写完整实现**

```swift
//
//  QuotaManager.swift
//  Slidesh
//
//  配额管理：Keychain 存储免费使用次数 + StoreKit 2 Premium 状态缓存
//

import Foundation
import StoreKit

enum QuotaFeature {
    case aiOutline      // AI生成大纲 + 重写大纲（合计）
    case convert        // 格式转换
    case pptGenerate    // 从大纲生成PPT

    var limit: Int {
        switch self {
        case .aiOutline:   return 5
        case .convert:     return 5
        case .pptGenerate: return 1
        }
    }

    var keychainKey: String {
        switch self {
        case .aiOutline:   return "slidesh.quota.aiOutline"
        case .convert:     return "slidesh.quota.convert"
        case .pptGenerate: return "slidesh.quota.pptGenerate"
        }
    }
}

class QuotaManager {
    static let shared = QuotaManager()
    private init() {}

    // NSLock 保证 consumeIfAvailable 原子性，防止连续快速点击绕过
    private let lock = NSLock()

    // 内存缓存的 Premium 状态，由 refreshPremiumStatus() 更新，非持久化
    private(set) var isPremium: Bool = false

    // MARK: - Premium 状态刷新（异步，在 viewWillAppear 调用）

    /// 通过 StoreKit 2 Transaction.currentEntitlements 验证有效订阅
    func refreshPremiumStatus() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                hasPremium = true
                break
            }
        }
        await MainActor.run { self.isPremium = hasPremium }
    }

    // MARK: - 配额操作

    /// 原子性检查并消耗配额。
    /// Premium 用户始终返回 true 且不消耗配额。
    /// 返回 false 表示配额已用完，应弹出 PaywallSheet。
    func consumeIfAvailable(_ feature: QuotaFeature) -> Bool {
        if isPremium { return true }
        lock.lock()
        defer { lock.unlock() }
        let used = Int(KeychainHelper.load(key: feature.keychainKey) ?? "0") ?? 0
        guard used < feature.limit else { return false }
        _ = KeychainHelper.save(key: feature.keychainKey, data: String(used + 1))
        return true
    }

    /// 当前剩余次数（调试用）
    func remaining(_ feature: QuotaFeature) -> Int {
        let used = Int(KeychainHelper.load(key: feature.keychainKey) ?? "0") ?? 0
        return max(0, feature.limit - used)
    }
}
```

- [ ] **Step 2: 构建项目，确认无编译错误**

在 Xcode 中按 Cmd+B，预期：Build Succeeded

- [ ] **Step 3: 提交**

```bash
git add Slidesh/Services/QuotaManager.swift
git commit -m "feat: 添加 QuotaManager，Keychain 配额存储 + StoreKit 2 Premium 验证"
```

---

## Task 2: PaywallSheet

**Files:**
- Create: `Slidesh/Views/PaywallSheet.swift`
- Modify: `Slidesh/ViewControllers/PremiumViewController.swift`（添加 onPurchased 回调）

- [ ] **Step 1: 修改 PremiumViewController，添加 onPurchased 回调**

在 `PremiumViewController` 类定义的 `cardViews` 属性后添加：

```swift
// 购买成功回调（由 PaywallSheet 设置，购买完成后调用）
var onPurchased: (() -> Void)?
```

将 `subscribeTapped()` 中 `case .success` 分支里的购买成功处理（只有一处）从：
```swift
await transaction.finish()
await MainActor.run { self.dismiss(animated: true) }
```
修改为：
```swift
await transaction.finish()
// 先刷新 Premium 缓存，确保回调触发时 consumeIfAvailable 直接返回 true
await QuotaManager.shared.refreshPremiumStatus()
let callback = self.onPurchased
await MainActor.run {
    // self.dismiss 会关闭包含 PremiumVC 的 NavigationController
    // 动画完成后调用 callback，此时 PaywallSheet 再 dismiss 自身
    self.dismiss(animated: true) {
        callback?()
    }
}
```

- [ ] **Step 2: 创建 PaywallSheet.swift，写完整实现**

```swift
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
        "✓  AI 大纲无限次生成",
        "✓  格式转换无限次使用",
        "✓  一键生成完整 PPT",
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
        titleLabel.text = "解锁 Slidesh Pro"
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
        upgradeButton.setTitle("查看升级计划  →", for: .normal)
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
```

- [ ] **Step 3: 构建项目，确认无编译错误**

Cmd+B，预期：Build Succeeded

- [ ] **Step 4: 提交**

```bash
git add Slidesh/Views/PaywallSheet.swift Slidesh/ViewControllers/PremiumViewController.swift
git commit -m "feat: 添加 PaywallSheet 半屏付费墙，PremiumViewController 新增 onPurchased 回调"
```

---

## Task 3: ConvertViewController + NewProjectViewController 拦截

**Files:**
- Modify: `Slidesh/ViewControllers/ConvertViewController.swift`
- Modify: `Slidesh/ViewControllers/NewProjectViewController.swift`

**背景：**
- `ConvertViewController` 的拦截点在 `collectionView(_:didSelectItemAt:)` → 调用 `startConvertFlow(for:)` 前
- `NewProjectViewController` 的拦截点在 `startAIGeneration()` 开头

- [ ] **Step 1: ConvertViewController — viewWillAppear 刷新 Premium 状态**

在 `ConvertViewController` 的 `viewWillAppear(_:)` 中添加（若无此方法则新增）：

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Task { await QuotaManager.shared.refreshPremiumStatus() }
}
```

- [ ] **Step 2: ConvertViewController — 在 collectionView(_:didSelectItemAt:) 添加拦截**

找到 `collectionView(_:didSelectItemAt:)` 中调用 `startConvertFlow(for: item)` 的位置，改为：

```swift
// 检查格式转换配额
guard QuotaManager.shared.consumeIfAvailable(.convert) else {
    PaywallSheet.show(from: self) { [weak self] in
        self?.startConvertFlow(for: item)
    }
    return
}
startConvertFlow(for: item)
```

- [ ] **Step 3: NewProjectViewController — viewWillAppear 刷新 Premium 状态**

在 `NewProjectViewController` 的 `viewWillAppear(_:)` 中添加（若无则新增）：

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Task { await QuotaManager.shared.refreshPremiumStatus() }
}
```

- [ ] **Step 4: NewProjectViewController — startAIGeneration 头部添加拦截**

在 `startAIGeneration()` 方法开头，`view.endEditing(true)` 之前插入：

```swift
private func startAIGeneration() {
    // 检查 AI 大纲配额
    guard QuotaManager.shared.consumeIfAvailable(.aiOutline) else {
        PaywallSheet.show(from: self) { [weak self] in
            // 购买成功时 PremiumVC 已调用 refreshPremiumStatus()，
            // isPremium == true，再次进入 consumeIfAvailable 直接通过不消耗配额
            self?.startAIGeneration()
        }
        return
    }
    view.endEditing(true)
    // ... 原有逻辑不变
```

- [ ] **Step 5: 构建项目**

Cmd+B，预期：Build Succeeded

- [ ] **Step 6: 手动验证 ConvertViewController 拦截**

1. 清空 Keychain 或新安装运行
2. 连续点击转换工具 5 次，确认前 5 次正常进入转换流程
3. 第 6 次点击，确认弹出 PaywallSheet
4. 关闭 Sheet，确认 PaywallSheet 消失，未触发转换

- [ ] **Step 7: 手动验证 NewProjectViewController 拦截**

1. 进入 AI 生成页，连续生成大纲 5 次（注意：每次生成消耗 1 次 aiOutline 配额）
2. 第 6 次点击「立即生成」，确认弹出 PaywallSheet

- [ ] **Step 8: 提交**

```bash
git add Slidesh/ViewControllers/ConvertViewController.swift Slidesh/ViewControllers/NewProjectViewController.swift
git commit -m "feat: ConvertViewController/NewProjectViewController 添加配额拦截"
```

---

## Task 4: OutlineViewController 拦截（重写大纲 + 生成PPT）

**Files:**
- Modify: `Slidesh/ViewControllers/OutlineViewController.swift`

**背景：**
- 重写大纲：`regenerateTapped()` 方法开头拦截，feature = `.aiOutline`（与生成大纲共享配额）
- 生成PPT：`templateTapped()` 方法开头拦截，feature = `.pptGenerate`

- [ ] **Step 1: OutlineViewController — viewWillAppear 刷新 Premium 状态**

在 `OutlineViewController` 的 `viewWillAppear(_:)` 中添加（若无则新增）：

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Task { await QuotaManager.shared.refreshPremiumStatus() }
}
```

- [ ] **Step 2: OutlineViewController — regenerateTapped 添加拦截**

在 `regenerateTapped()` 开头，`sseTask?.cancel()` 之前插入：

```swift
@objc private func regenerateTapped() {
    // 重写大纲与生成大纲共享 aiOutline 配额
    guard QuotaManager.shared.consumeIfAvailable(.aiOutline) else {
        PaywallSheet.show(from: self) { [weak self] in
            // 购买成功后 isPremium == true，再次调用 consumeIfAvailable 直接通过不消耗
            self?.regenerateTapped()
        }
        return
    }
    // 取消当前请求，重置状态，重新启动流式生成
    sseTask?.cancel()
    // ... 原有逻辑不变
```

- [ ] **Step 3: OutlineViewController — templateTapped 添加拦截**

在 `templateTapped()` 开头，`guard !sections.isEmpty` 之前插入：

```swift
@objc private func templateTapped() {
    // 生成PPT配额检查（免费用户仅1次机会，上限最严格）
    guard QuotaManager.shared.consumeIfAvailable(.pptGenerate) else {
        PaywallSheet.show(from: self) { [weak self] in
            // PremiumVC 在触发 onPurchased 前已调用 refreshPremiumStatus()，
            // 确保 isPremium == true，re-dispatch 时 consumeIfAvailable 直接通过不消耗
            self?.templateTapped()
        }
        return
    }
    guard !sections.isEmpty else { return }
    // ... 原有逻辑不变
```

- [ ] **Step 4: 构建项目**

Cmd+B，预期：Build Succeeded

- [ ] **Step 5: 手动验证 regenerateTapped 拦截**

注意：aiOutline 配额与生成大纲共享上限 5 次。
1. 先通过 NewProjectViewController 生成大纲（消耗配额至 5/5）
2. 进入 OutlineViewController，点击「重写大纲」
3. 确认立即弹出 PaywallSheet（配额已满）

- [ ] **Step 6: 手动验证 templateTapped 拦截（最关键路径）**

1. 新安装或清空配额环境
2. 生成大纲进入 OutlineViewController
3. 点击「挑选PPT模板」第 1 次：确认正常进入模板选择器
4. 返回，再次点击「挑选PPT模板」第 2 次：确认弹出 PaywallSheet
5. 点击「查看升级计划」：确认跳转 PremiumViewController
6. 取消购买返回：确认 PaywallSheet 仍显示（未 dismiss）

- [ ] **Step 7: 提交**

```bash
git add Slidesh/ViewControllers/OutlineViewController.swift
git commit -m "feat: OutlineViewController 重写大纲/生成PPT添加配额拦截"
```
