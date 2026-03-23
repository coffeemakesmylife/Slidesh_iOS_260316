# ConvertViewController 完整功能设计

**日期**: 2026-03-23
**状态**: v2（已修复审核问题）

---

## 背景

ConvertViewController 目前仅有静态 UI 展示，点击任何工具卡片只弹出"功能开发中"提示。本设计基于 `cover_api_doc.md` 接口文档，实现所有 7 个格式转换工具的完整交互功能。

---

## API 接口映射

| 工具 | API 端点 | 格式参数 | 接受文件 | newslist 类型 |
|------|----------|----------|---------|--------------|
| PDF 转 Word（精选卡） | `POST /v1/api/document/pdf/pdftofile` | 固定 `type=WORD` | PDF | object |
| PDF 转换器 | `POST /v1/api/document/pdf/pdftofile` | WORD/XML/EXCEL/PPT/PNG/HTML | PDF | object |
| 合并 PDF（2个） | `POST /v1/api/document/pdf/mergetwopdf` | 无 | PDF | object |
| 合并 PDF（3+个） | `POST /v1/api/document/pdf/mergemorepdf` | 无 | PDF | object |
| Word 转换 | `POST /v1/api/document/word/wordtofile` | PDF/HTML/PNG | .doc/.docx | **string**（URL） |
| Excel 转换 | `POST /v1/api/document/excel/exceltofile` | PDF/HTML/PNG | .xls/.xlsx | **string**（URL） |
| PPT 转换 | `POST /v1/api/document/ppt/ppttofile` | PDF/HTML/PNG | .ppt/.pptx | object |
| 文件转图片 | `POST /v1/api/document/images/filetoimages` | 无 | PDF/Word/Excel/PPT | object（多张图片 URL 数组） |

### newslist 解析策略

无 RSA 加密（document convert APIs 为明文，与 PPT 生成 API 不同）。

- **newslist 为 string**：直接作为下载 URL 使用
- **newslist 为 object**：按以下优先级查找 URL 字段：`"url"` → `"fileUrl"` → `"downloadUrl"` → `"path"`；取第一个非空字符串
- **fileToImage 特殊情况**：`newslist` 对象中包含图片 URL 数组，查找字段 `"urls"` → `"list"` → `"images"`，提取为 `[String]`；若 newslist 本身就是数组则直接使用
- 解析失败统一报错："转换结果解析失败，请重试"

**注意**：`ConvertAPIService` 完全独立于 `PPTAPIService`，不复用其 RSA 解密逻辑。

---

## ConvertToolItem 完整数据表

`ConvertToolItem` 新增字段：`kind: ConvertToolKind`、`formatOptions: [String]`、`acceptedExtensions: [String]`、`allowsMultiple: Bool`。

| 工具 | kind | formatOptions | acceptedExtensions | allowsMultiple |
|------|------|---------------|--------------------|----------------|
| PDF 转 Word | `.pdfToWord` | `[]` | `["pdf"]` | false |
| PDF 转换器 | `.pdfConvert` | `["WORD","XML","EXCEL","PPT","PNG","HTML"]` | `["pdf"]` | false |
| 合并 PDF | `.mergePDF` | `[]` | `["pdf"]` | true（最少 2 个） |
| Word 转换 | `.wordConvert` | `["PDF","HTML","PNG"]` | `["doc","docx"]` | false |
| Excel 转换 | `.excelConvert` | `["PDF","HTML","PNG"]` | `["xls","xlsx"]` | false |
| PPT 转换 | `.pptConvert` | `["PDF","HTML","PNG"]` | `["ppt","pptx"]` | false |
| 文件转图片 | `.fileToImage` | `[]` | `["pdf","doc","docx","xls","xlsx","ppt","pptx"]` | false |

文件选择器通过 `UTType(filenameExtension: ext)` 逐个构建 `allowedContentTypes`，例如：

```swift
// Word
[UTType(filenameExtension: "doc"), UTType(filenameExtension: "docx")].compactMap { $0 }
// PDF
[UTType.pdf]
```

---

## 整体架构

### 新增文件

#### 1. `ConvertAPIService.swift`

职责：
- `multipart/form-data` 上传，`URLSession.uploadTask` 获取精确上传进度
- 根据 `ConvertToolKind` 决定端点和参数
- 合并 PDF：`files.count == 2` → `mergetwopdf`（字段 `file1`, `file2`）；`files.count >= 3` → `mergemorepdf`（字段名均为 `"files"`，多部分重复 key）
- 解析 `newslist` → `[URL]`（所有工具统一返回数组，单文件工具返回单元素数组）
- 下载结果文件到 `FileManager.default.temporaryDirectory`
- 复用项目现有 `APIError` 枚举
- 上传超时：`timeoutInterval = 120`

公开方法：

```swift
func convert(
    tool: ConvertToolKind,
    files: [URL],
    outputFormat: String?,
    onUploadProgress: @escaping (Double) -> Void,
    completion: @escaping (Result<[URL], Error>) -> Void
)
```

统一返回 `[URL]`：
- 单文件工具：数组包含 1 个本地临时文件 URL
- `fileToImage`：数组包含每张图片的本地临时文件 URL（≥1）

#### 2. `ConvertJobViewController.swift`

单次转换任务 VC，push 方式进入，背景使用 `addMeshGradientBackground()`。

**状态机**（含所有转换路径）：

```
idle ──────────────────────────────→ fileSelected
                                          │
                                    「开始转换」
                                          ↓
                                     converting ──「取消」──→ fileSelected
                                          │
                              ┌───────────┴────────────┐
                           success                   error
                              │                        │
                        「再转一个」             「重试」→ fileSelected
                              ↓               「重新选择」→ idle
                            idle
```

**各状态 UI**：

| 状态 | 主要 UI 元素 |
|------|-------------|
| `idle` | 工具大图标 + 名称 + 支持格式说明 + 「选择文件」主按钮；合并PDF按钮文字改为「选择多个文件（至少2个）」 |
| `fileSelected` | 文件卡片（图标+文件名+大小）+ 格式标签（→ PDF 等）+ 「开始转换」主按钮 + 「重新选择」次要按钮；合并PDF显示文件列表（可逐个删除，少于2个时「开始转换」禁用） |
| `converting` | 两阶段进度：① 精确上传进度条 → ② 服务端处理不确定进度动画；「取消」按钮；禁用返回手势（`isModalInPresentation = true`） |
| `success` | 成功勾选动画 + 「预览结果」主按钮 + 「再转一个」次要按钮 |
| `error` | 错误图标 + 错误文字（API `msg`）+ 「重试」主按钮 + 「重新选择文件」次要按钮 |

**成功后预览**：
- 单 URL（大多数工具）：`present(QLPreviewController, animated: true)`，QLPreviewController 通过 `dataSource` 加载本地临时文件
- 多 URL（`fileToImage`）：同样使用 `QLPreviewController`，通过 `dataSource` 实现多页预览（`numberOfPreviewItems` 返回图片数量，`previewController(_:previewItemAt:)` 返回对应 URL）
- QLPreviewController 内置系统分享按钮，用户可保存到文件、AirDrop、分享到其他应用

**视觉规范**：
- 背景：`addMeshGradientBackground()`
- 颜色：全部使用颜色系统（`.appPrimary`、`.appTextPrimary`、`.appTextSecondary`、`.appCardBackground`）
- 进度条：`appGradientStart → appGradientEnd` 渐变色，`CAGradientLayer`
- 主按钮：渐变背景（与 FeaturedCell 一致），白色文字
- 次要按钮：`appCardBackground`，`appTextSecondary` 文字

### 修改文件

#### `ConvertViewController.swift`

**新增枚举**（顶层，`Sendable`）：

```swift
enum ConvertToolKind: String, Sendable {
    case pdfToWord
    case pdfConvert
    case mergePDF
    case wordConvert
    case excelConvert
    case pptConvert
    case fileToImage
}
```

**`ConvertToolItem` 新增字段**：`kind`、`formatOptions`、`acceptedExtensions`、`allowsMultiple`（见上方数据表）。

**交互逻辑**（`didSelectItemAt` 替换原有 alert）：

```
有格式选项（formatOptions 非空）:
  → present FormatPickerSheet
  → 用户选格式后 → UIDocumentPickerViewController（单选）
  → 选好文件后 → push ConvertJobViewController

无格式选项，非合并 PDF:
  → UIDocumentPickerViewController（单选）
  → 选好文件后 → push ConvertJobViewController

合并 PDF:
  → UIDocumentPickerViewController（多选）
  → 选好文件后 → push ConvertJobViewController
```

---

## FormatPickerSheet（格式选择底部面板）

以 `modalPresentationStyle = .overFullScreen`，`modalTransitionStyle = .crossDissolve` 呈现，背景半透明遮罩（黑色 alpha 0.4）。面板本体从底部弹入（`UIViewPropertyAnimator`）。

**UI 结构**：
- 顶部拖动条（4×36pt，`appTextSecondary` alpha 0.4）
- 标题「选择输出格式」（heavy 18pt，`appTextPrimary`）
- 格式列表行（StackView）：
  - 行高 64pt，`appCardBackground` alpha 0.7 背景，cornerRadius 16，`appCardBorder` 边框
  - 左侧：彩色圆形图标背景（对应格式颜色 alpha 0.15）+ SF Symbol 图标
  - 中间：格式名（bold 16pt，`appTextPrimary`）+ 扩展名说明（12pt，`appTextSecondary`）
  - 右侧：chevron.right（`appTextSecondary`）
  - 点击行 → 回调格式字符串 → dismiss
- 「取消」独立卡片按钮（`appCardBackground`，`appTextSecondary` 文字）

格式图标和颜色对应表：

| 格式 | SF Symbol | 颜色 |
|------|-----------|------|
| WORD / PDF（Word转） | `doc.richtext.fill` | systemIndigo |
| EXCEL | `tablecells.fill` | systemGreen |
| PPT | `tv.fill` | systemOrange |
| XML | `chevron.left.forwardslash.chevron.right` | systemBrown |
| PNG | `photo.fill` | systemPurple |
| HTML | `globe` | systemTeal |
| PDF（PDF转） | `book.pages.fill` | systemRed |
| HTML（Word/Excel/PPT转） | `globe` | systemTeal |

---

## 错误处理

| 场景 | 处理方式 |
|------|---------|
| 网络超时 / 无网络 | error 状态，显示系统错误信息，提示重试 |
| 服务端 code != 0 | 显示 API `msg` 字段内容 |
| newslist 解析失败 | "转换结果解析失败，请重试" |
| 下载结果文件失败 | "文件下载失败，请重试" |
| 用户取消（converting 中） | 取消 URLSessionTask → 回到 fileSelected 状态 |
| 合并 PDF 文件数 < 2 | 「开始转换」按钮 disabled，提示"请至少选择 2 个文件" |

---

## 不在本期范围内

- 转换历史记录（WorksStore 集成）
- 后台下载（App 退出后继续）
- 批量转换多个文件（每次一个任务）
- VIP 权限校验
