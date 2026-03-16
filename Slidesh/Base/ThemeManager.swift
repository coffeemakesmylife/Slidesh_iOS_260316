//
//  ThemeManager.swift
//  Slidesh
//
//  统一管理 App 主题（跟随系统/浅色/深色），持久化到 UserDefaults
//  切换时通过 window.overrideUserInterfaceStyle 驱动 AppColors 动态颜色联动
//

import UIKit

final class ThemeManager {

    static let shared = ThemeManager()
    private init() {}

    private let userDefaultsKey = "AppThemeStyle"

    // 通知名，自定义绘制的视图监听此通知后重绘
    static let didChangeNotification = Notification.Name("ThemeManagerDidChange")

    // MARK: - 当前主题

    /// 读取持久化的主题样式
    var currentStyle: UIUserInterfaceStyle {
        let raw = UserDefaults.standard.integer(forKey: userDefaultsKey)
        return UIUserInterfaceStyle(rawValue: raw) ?? .unspecified
    }

    // MARK: - 切换主题

    /// 切换主题并持久化，同时驱动 window 刷新所有动态颜色
    func apply(_ style: UIUserInterfaceStyle, animated: Bool = true) {
        UserDefaults.standard.set(style.rawValue, forKey: userDefaultsKey)

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        let applyBlock = {
            window.overrideUserInterfaceStyle = style
        }

        if animated {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: applyBlock)
        } else {
            applyBlock()
        }

        // 通知自定义绘制的视图（如 MeshGradientView）刷新
        NotificationCenter.default.post(name: Self.didChangeNotification, object: style)
    }

    // MARK: - 启动时恢复

    /// 在 AppDelegate 中调用，将已保存的主题应用到 window（无动画）
    func applyOnLaunch(to window: UIWindow) {
        window.overrideUserInterfaceStyle = currentStyle
    }

    // MARK: - 辅助

    /// 当前主题的中文显示名
    var currentStyleName: String {
        switch currentStyle {
        case .dark:  return "深色"
        case .light: return "浅色"
        default:     return "跟随系统"
        }
    }
}
