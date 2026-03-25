# Paywall Strategy Implementation Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在关键操作节点拦截免费用户，通过极简半屏付费墙引导订阅，最大化付费转化率。

**Architecture:** QuotaManager 单例负责 Keychain 配额读写和 Premium 状态验证；PaywallSheet 作为轻量半屏入口，展示轮播权益并跳转现有 PremiumViewController 完成购买；拦截逻辑分散在各业务 ViewController 的操作触发点。

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

---

## 文件结构

| 文件 | 类型 | 职责 |
|---|---|---|
| `Services/QuotaManager.swift` | 新建 | 配额读写、Premium 验证 |
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
}

class QuotaManager {
    static let shared = QuotaManager()

    // 检查是否可用（Premium 用户始终返回 true）
    func canUse(_ feature: QuotaFeature) -> Bool

    // 消耗一次配额（Premium 用户调用无效果）
    func consume(_ feature: QuotaFeature)

    // 当前剩余次数（用于 UI 展示，如有需要）
    func remaining(_ feature: QuotaFeature) -> Int

    // 基于 StoreKit 2 验证当前是否有效订阅
    var isPremium: Bool { get async }
}
```

Keychain 键名：`slidesh.quota.aiOutline`、`slidesh.quota.convert`、`slidesh.quota.pptGenerate`

存储值为已使用次数（Int），与上限比较判断是否可用。

---

## PaywallSheet 设计

半屏 Sheet，高度约 220pt，从底部弹出。

**布局（从上到下）：**
1. 标题：「解锁 Slidesh Pro」，粗体居中
2. 权益轮播：单行文字，每 2.5 秒淡入淡出切换
   - ✓ AI 大纲无限次生成
   - ✓ 格式转换无限次使用
   - ✓ 一键生成完整 PPT
   - ✓ 解锁全部精选模板
3. 「查看升级计划」按钮：高度 56pt，主题色背景，圆角，占满横向宽度

点击按钮：present `PremiumViewController`（包裹在 NavigationController 中）。
购买成功后 PremiumViewController dismiss，原操作自动继续执行（通过回调实现）。

---

## 拦截逻辑模式

所有拦截点遵循统一模式：

```swift
// 检查配额（异步，需在 Task 中调用）
guard await QuotaManager.shared.canUse(.featureKey) else {
    PaywallSheet.show(from: self) { [weak self] in
        // 用户完成订阅后的回调：继续执行原操作
        self?.continueOriginalAction()
    }
    return
}
// 消耗配额后执行操作
QuotaManager.shared.consume(.featureKey)
continueOriginalAction()
```

---

## Premium 状态验证

使用 StoreKit 2 的 `Transaction.currentEntitlements` 异步验证，不依赖本地缓存标志，确保订阅过期后自动失效。验证结果不持久化，每次调用 `canUse()` 时实时查询。

为避免每次操作都有网络延迟感，`isPremium` 结果在 ViewController 生命周期内（`viewWillAppear`）预加载缓存，操作触发时使用缓存值，定期刷新。
