# 评分引导系统设计

**日期：** 2026-03-27
**项目：** Slidesh
**状态：** 待实现

---

## 1. 总体流程

```
触发点触发
    ↓
RatingManager.shared.trigger(from:)
    ↓
检查是否已触发过（UserDefaults: rating_has_prompted）
    ↓ 未触发
展示 SatisfactionSheet（自定义满意度视图）
    ↓
用户点击"帮到了，好评"          用户点击"有建议，说一下"
    ↓                                   ↓
enable_star_or_comment == true     打开 FeedbackViewController
    ↓ true              ↓ false
SKStoreReviewController    跳转 App Store 评分页
.requestReview(in:scene)   （AppConfig.appStoreReviewURL）
```

- **不控制频率**：每个触发点一旦满足条件即展示，不做时间间隔或次数限制
- **全局只弹一次**：`rating_has_prompted` 写入 UserDefaults 后，所有触发点永久跳过
- `enable_star_or_comment` 从服务端配置（AppConfig）读取，true = 系统弹窗，false = App Store URL

---

## 2. SatisfactionSheet UI

### 呈现方式
- `UIView` 直接 add 到 `UIWindow`（不依赖 presenting VC）
- 底部弹出，带半透明遮罩（`UIView` 黑色 alpha 0.4）
- `animateIn`：scale(0.98) + translateY(+20pt) → identity，duration 0.35s，spring
- `animateOut`：identity → scale(0.96) + translateY(+20pt)，duration 0.25s

### 视觉结构（从上到下）

```
┌─────────────────────────────────┐
│         ▬  (拖拽指示条)           │
│                                 │
│   [App 图标圆角卡片，紫蓝渐变]     │
│                                 │
│   ★ ★ ★ ★ ★  (依次弹入动画)      │
│                                 │
│      Slidesh 帮到你了吗？         │
│                                 │
│  ╔═════════════════════════╗    │
│  ║  帮到了，好评 ⭐️  (渐变按钮) ║  │
│  ╚═════════════════════════╝    │
│                                 │
│      有建议，说一下  (灰色小字)    │
└─────────────────────────────────┘
```

### 关键细节
- **星星动画**：`onAppear` 延迟 0.2s 后将 `starsLit` 从 0 → 5，每颗星 delay +0.07s，spring(response:0.28, dampingFraction:0.55)
- **App 图标**：`wand.and.stars`，圆角卡片 80×80pt，紫蓝渐变背景
- **正向按钮**：渐变背景（紫蓝系），点击后 0.4s 颜色 feedback 再 animateOut
- **负向按钮**：纯文字，灰色，点击后 0.4s feedback 再 animateOut
- **`hasHandledAction`**：防止双击重复触发回调

### 类结构
```swift
final class SatisfactionSheet: UIView {
    var onPositive: (() -> Void)?
    var onNegative: (() -> Void)?

    func show()      // add to window, animateIn, 记录 rating_has_prompted
    func dismiss()   // animateOut, removeFromSuperview
}
```

---

## 3. RatingManager

```swift
final class RatingManager {
    static let shared = RatingManager()

    // 外部调用入口
    func trigger(from point: TriggerPoint)

    // Debug / 设置页测试用
    func presentSatisfactionSheet()

    // SatisfactionSheet 回调
    func handlePositive()   // → 系统弹窗或 App Store URL
    func handleNegative()   // → FeedbackViewController
}

enum TriggerPoint {
    case outlineGenerated       // T1
    case pptPreviewFromTemplate // T2
    case convertSuccess         // T4
    case myWorksThirdVisit      // T6
    case pptPreviewFromMyWorks  // T7
    case outlineDownloaded      // T8
}
```

**UserDefaults key：**
- `rating_has_prompted`（Bool）：是否已展示过，写入后所有触发点跳过

---

## 4. 触发点集成

| ID | 触发时机 | 文件 | 插入位置 |
|----|---------|------|---------|
| T1 | 大纲生成完成 | `OutlineViewController.swift` | `transitionToEditable()` 末尾 |
| T2 | 从模板流进入 PPT 预览 | `PPTPreviewViewController.swift` | `viewDidAppear`，source == `.templateFlow` |
| T4 | 格式转换成功 | `ConvertJobViewController.swift` | `state = .success(resultURLs:)` 赋值后 |
| T6 | 第 3 次进入我的作品（有内容） | `MyWorksViewController.swift` | `viewDidAppear`，visitCount == 3 且 ppts 非空 |
| T7 | 从我的作品打开 PPT 预览 | `PPTPreviewViewController.swift` | `viewDidAppear`，source == `.myWorks` |
| T8 | 下载大纲（导出文件） | `OutlineViewController.swift` | `exportMarkdown()` / `exportPlainText()` 中 present picker 之前 |

**T2 / T7 区分来源：**
`PPTPreviewViewController` 新增 `source: PPTPreviewSource` 初始化参数：
```swift
enum PPTPreviewSource { case templateFlow, myWorks, other }
```
`MyWorksViewController` push 时传 `.myWorks`，`TemplatesViewController` 等传 `.templateFlow`。

---

## 5. Debug 测试入口

在 `SettingsViewController` 的 `#if DEBUG` 区块（`makeDebugSection`）中追加：
```swift
makeRow(sfSymbol: "star.bubble", title: "测试评分弹窗") {
    RatingManager.shared.presentSatisfactionSheet()
}
```
`presentSatisfactionSheet()` 跳过 `rating_has_prompted` 检查，直接展示 `SatisfactionSheet`，方便随时测试 UI 和回调流程。

---

## 6. 新增文件

| 文件 | 说明 |
|------|------|
| `Slidesh/Managers/RatingManager.swift` | 单例，触发逻辑，回调处理 |
| `Slidesh/Views/SatisfactionSheet.swift` | 满意度底部弹窗 UIView |
