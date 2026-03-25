# Paywall Strategy Implementation Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在关键操作节点拦截免费用户，通过极简半屏付费墙引导订阅，最大化付费转化率。

**Architecture:** QuotaManager 单例负责 Keychain 配额读写和 Premium 状态缓存；PaywallSheet 作为轻量半屏入口，展示轮播权益并跳转现有 PremiumViewController 完成购买；拦截逻辑分散在各业务 ViewController 的操作触发点。

**Tech Stack:** StoreKit 2 (Transaction 验证)、KeychainHelper（已有）、UIKit

---

## 核心策略

- **免费配额**：永不重置（生命周期配额），Keychain 存储防卸载重装绕过
- **拦截时机**：在用户已投入时间后的最高价值节点拦截，而非入口处
- **付费墙形式**：半屏极简 Sheet，展示单行权益轮播 + 大按钮，不处理支付，跳转 PremiumViewController

---

## 配额规则

| Feature Key | 功能 | 免费上限 |
|---|---|---|
| `aiOutline` | AI 生成大纲 + 重写大纲（合计） | 5 次 |
| `convert` | 格式转换 | 5 次 |
| `pptGenerate` | 从大纲生成 PPT | 1 次 |

Premium 用户（StoreKit 2 验证有效订阅）跳过所有配额检查，无限使用。

---

## 拦截时机

| 触发点 | 位置 | Feature |
|---|---|---|
| 点击转换工具项 | `ConvertViewController.collectionView(_:didSelectItemAt:)` | `.convert` |
| 点击「立即生成」大纲 | `NewProjectViewController.startAIGeneration()` | `.aiOutline` |
| 点击「重新生成」大纲 | `OutlineViewController` 重写按钮 | `.aiOutline` |
| 点击「生成 PPT」| `OutlineViewController` 生成PPT按钮 | `.pptGenerate` |

`pptGenerate` 只有 1 次机会，不在按钮上做额外视觉提示，按钮行为与有次数时完全一致，点击后触发 Paywall。

---

## 文件结构

| 文件 | 类型 | 职责 |
|---|---|---|
| `Services/QuotaManager.swift` | 新建 | 配额读写、Premium 状态缓存 |
| `Views/PaywallSheet.swift` | 新建 | 半屏付费墙 UI |
| `ConvertViewController.swift` | 修改 | 转换前拦截 |
| `NewProjectViewController.swift` | 修改 | 生成大纲前拦截 |
| `OutlineViewController.swift` | 修改 | 重写大纲、生成PPT前拦截 |

---

## QuotaManager 设计

```swift
enum QuotaFeature {
    case aiOutline      // AI生成大纲 + 重写大纲
    case convert        // 格式转换
    case pptGenerate    // 从大纲生成PPT

    var limit: Int {
        switch self {
        case .aiOutline:    return 5
        case .convert:      return 5
        case .pptGenerate:  return 1
        }
    }
}

class QuotaManager {
    static let shared = QuotaManager()

    // 内存缓存的 Premium 状态，由 refreshPremiumStatus() 更新
    private(set) var isPremium: Bool = false

    // 刷新 Premium 状态（异步，从 StoreKit 2 Transaction.currentEntitlements 查询）
    // 各 ViewController 在 viewWillAppear 调用，结果存入 isPremium 内存缓存
    func refreshPremiumStatus() async

    // 原子性检查并消耗配额，返回 true 表示可继续操作
    // Premium 用户始终返回 true 且不消耗配额
    // 同步调用，直接使用内存缓存的 isPremium 值
    func consumeIfAvailable(_ feature: QuotaFeature) -> Bool

    // 当前剩余次数（用于调试，不用于 UI 展示）
    func remaining(_ feature: QuotaFeature) -> Int
}
```

**Keychain 键名：**
- `slidesh.quota.aiOutline`（存储已使用次数 Int）
- `slidesh.quota.convert`
- `slidesh.quota.pptGenerate`

**isPremium 缓存规则：**
- 存储在 QuotaManager 的内存属性中（非持久化），App 启动时默认 `false`
- 各需要拦截的 ViewController 在 `viewWillAppear` 调用 `Task { await QuotaManager.shared.refreshPremiumStatus() }`
- `consumeIfAvailable()` 同步读取 `isPremium` 内存值，无网络延迟
- 刷新无固定时间间隔，依赖 `viewWillAppear` 触发，足以覆盖用户在 PremiumViewController 完成购买后返回的场景

---

## PaywallSheet 设计

半屏 Sheet（`UISheetPresentationController`），高度约 220pt（`.custom` detent），从底部弹出。

**布局（从上到下）：**
1. 标题：「解锁 Slidesh Pro」，粗体居中，顶部间距 28pt
2. 权益轮播：单行文字，每 2.5 秒淡入淡出切换，文字居中
   - ✓ AI 大纲无限次生成
   - ✓ 格式转换无限次使用
   - ✓ 一键生成完整 PPT
3. 「查看升级计划」按钮：高度 56pt，主题色背景（`.appGradientMid`），圆角 28pt，左右边距 24pt

**购买完成回调流程：**

```
PaywallSheet
  └── 点击「查看升级计划」
        └── present PremiumViewController（含 NavigationController）
              └── 用户完成购买，PremiumViewController 调用 onPurchased()
                    └── PremiumViewController dismiss
                          └── PaywallSheet 调用 completionHandler（外部传入）
                                └── 触发原操作继续执行
```

PaywallSheet 的 `show(from:completion:)` 接受一个 `completion: (() -> Void)?` 参数，购买成功后调用。PaywallSheet 通过 `PaywallSheetDelegate` 协议接收 PremiumViewController 的购买成功通知，随后 dismiss 自身并调用 completion。

若用户在 PremiumViewController 内点取消返回，PaywallSheet 保持展示状态，不调用 completion。

---

## 拦截逻辑模式

所有拦截点遵循统一模式（同步，无 async）：

```swift
guard QuotaManager.shared.consumeIfAvailable(.featureKey) else {
    PaywallSheet.show(from: self) { [weak self] in
        // 购买成功回调：继续执行原操作
        QuotaManager.shared.consumeIfAvailable(.featureKey) // Premium 用户此时不消耗
        self?.continueOriginalAction()
    }
    return
}
continueOriginalAction()
```

`consumeIfAvailable()` 内部加锁保证原子性，避免连续快速点击导致重复通过检查。
