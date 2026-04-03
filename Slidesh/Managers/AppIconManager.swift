//
//  AppIconManager.swift
//  Slidesh
//
//  备用图标管理：定义可用图标列表，封装切换逻辑
//
//  ⚠️ 使用前需将图标 PNG 文件直接放入项目（Build Phases → Copy Bundle Resources），
//  不能放在 Assets.xcassets 内。每个图标至少需要：
//    IconXxx@2x.png  (120×120)
//    IconXxx@3x.png  (180×180)
//  文件名需与 Info.plist CFBundleAlternateIcons 中的 key 一致。
//

import UIKit

struct AppIconEntry {
    /// nil 表示主图标（恢复默认）
    let identifier: String?
    let displayName: String
}

final class AppIconManager {
    static let shared = AppIconManager()
    private init() {}

    // 新增图标只需在此数组追加一个 AppIconEntry，并在 Info.plist 和项目文件里同步添加
    let icons: [AppIconEntry] = [
        AppIconEntry(identifier: nil,         displayName: "默认"),
        AppIconEntry(identifier: "IconDark",  displayName: "深色"),
        AppIconEntry(identifier: "IconLight", displayName: "浅色"),
    ]

    /// 当前使用的图标 identifier（nil = 主图标）
    var currentIdentifier: String? {
        UIApplication.shared.alternateIconName
    }

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    /// 切换图标，completion 在主线程回调，true = 成功
    func setIcon(_ identifier: String?, completion: @escaping (Bool) -> Void) {
        guard supportsAlternateIcons else {
            completion(false)
            return
        }
        UIApplication.shared.setAlternateIconName(identifier) { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }

    /// 加载图标预览图：备用图标直接从 bundle 读文件；主图标尝试读 AppIcon
    func previewImage(for entry: AppIconEntry) -> UIImage? {
        if let id = entry.identifier {
            // 备用图标文件在 bundle 根目录，UIImage(named:) 会自动匹配 @2x/@3x
            return UIImage(named: id)
        } else {
            // 主图标在 xcassets 里，iOS 允许用 "AppIcon" 名读取
            return UIImage(named: "AppIcon")
        }
    }
}
