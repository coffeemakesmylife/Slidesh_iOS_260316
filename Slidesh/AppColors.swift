//
//  AppColors.swift
//  Slidesh
//
//  Created by ted on 2026/3/16.
//

import UIKit

// MARK: - App 颜色系统
// 主色调：#0640AD（深宝蓝），用于按钮背景等主要交互元素
// 浅色主题：纯净白色系，参考截图风格
// 深色主题：深邃蓝黑色调
// 使用方式: view.backgroundColor = .appBackgroundPrimary
extension UIColor {

    // MARK: - 主题色

    // 品牌主色 #0640AD 深宝蓝（按钮背景等）
    static var appPrimary: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.098, green: 0.306, blue: 0.761, alpha: 1.0)   // #1A4EC2 暗时适当提亮
                : UIColor(red: 0.024, green: 0.251, blue: 0.678, alpha: 1.0)   // #0640AD 深宝蓝
        }
    }

    // 主题色-浅色变体（轻量背景、图标等）
    static var appPrimaryLight: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1.0)      // #598CF2 亮蓝
                : UIColor(red: 0.16, green: 0.40, blue: 0.85, alpha: 1.0)      // #2966D9 中宝蓝
        }
    }

    // 主题色-深色变体（按下状态）
    static var appPrimaryDark: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.016, green: 0.180, blue: 0.541, alpha: 1.0)   // #042E8A 深暗蓝
                : UIColor(red: 0.010, green: 0.157, blue: 0.478, alpha: 1.0)   // #02287A 更深宝蓝
        }
    }

    // 主题色背景上的文字（白色可读性最佳）
    static var appOnPrimary: UIColor {
        return UIColor.white
    }

    // 主题色半透明背景（次要按钮、标签选中背景）
    static var appPrimarySubtle: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.098, green: 0.306, blue: 0.761, alpha: 0.20)  // 主色 20% 透明
                : UIColor(red: 0.024, green: 0.251, blue: 0.678, alpha: 0.10)  // 主色 10% 透明
        }
    }

    // MARK: - 背景颜色

    // 一级背景色（页面主背景）
    static var appBackgroundPrimary: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.031, green: 0.059, blue: 0.118, alpha: 1.0)   // #08101E 深邃蓝黑
                : UIColor(red: 0.961, green: 0.965, blue: 0.976, alpha: 1.0)   // #F5F7F9 微蓝白
        }
    }

    // 二级背景色（侧边栏、列表分组背景）
    static var appBackgroundSecondary: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.051, green: 0.086, blue: 0.157, alpha: 1.0)   // #0D1628 深蓝
                : UIColor(red: 0.929, green: 0.937, blue: 0.953, alpha: 1.0)   // #EDF0F3 浅蓝灰
        }
    }

    // 三级背景色（卡片、弹窗、Sheet 背景）
    static var appBackgroundTertiary: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.071, green: 0.114, blue: 0.196, alpha: 1.0)   // #121D32 蓝灰
                : UIColor(red: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1.0)   // #FFFFFF 纯白
        }
    }

    // MARK: - 文字颜色

    // 一级文字（标题、主要内容）
    static var appTextPrimary: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.910, green: 0.929, blue: 0.961, alpha: 1.0)   // #E8EDF5 柔和白蓝
                : UIColor(red: 0.067, green: 0.094, blue: 0.157, alpha: 1.0)   // #111828 近黑蓝
        }
    }

    // 二级文字（副标题、说明文字）
    static var appTextSecondary: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.541, green: 0.592, blue: 0.710, alpha: 1.0)   // #8A97B5 中蓝灰
                : UIColor(red: 0.294, green: 0.337, blue: 0.451, alpha: 1.0)   // #4B5673 蓝灰
        }
    }

    // 三级文字（占位符、禁用文字、时间戳）
    static var appTextTertiary: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.337, green: 0.384, blue: 0.490, alpha: 1.0)   // #56627D 暗蓝灰
                : UIColor(red: 0.545, green: 0.584, blue: 0.698, alpha: 1.0)   // #8B95B2 浅蓝灰
        }
    }

    // MARK: - 卡片颜色

    // 卡片背景色
    static var appCardBackground: UIColor {
        return appBackgroundTertiary
    }

    // 卡片边框颜色
    static var appCardBorder: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.145, green: 0.212, blue: 0.337, alpha: 1.0)   // #253656 深蓝边框
                : UIColor(red: 0.871, green: 0.894, blue: 0.929, alpha: 1.0)   // #DEE4ED 浅蓝灰边框
        }
    }

    // MARK: - 按钮颜色

    // 主要按钮背景色（使用主色）
    static var appButtonPrimary: UIColor {
        return appPrimary
    }

    // 主要按钮按下状态
    static var appButtonPrimaryPressed: UIColor {
        return appPrimaryDark
    }

    // 主要按钮文字颜色
    static var appButtonPrimaryText: UIColor {
        return appOnPrimary
    }

    // 次要按钮背景色（主色透明底）
    static var appButtonSecondary: UIColor {
        return appPrimarySubtle
    }

    // 次要按钮文字颜色
    static var appButtonSecondaryText: UIColor {
        return appPrimary
    }

    // 文字按钮颜色
    static var appButtonText: UIColor {
        return appPrimary
    }

    // 禁用按钮背景色
    static var appButtonDisabled: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.114, green: 0.145, blue: 0.220, alpha: 1.0)   // #1D2538 暗蓝灰
                : UIColor(red: 0.894, green: 0.906, blue: 0.929, alpha: 1.0)   // #E4E7ED 浅灰
        }
    }

    // 禁用按钮文字颜色
    static var appButtonDisabledText: UIColor {
        return appTextTertiary
    }

    // MARK: - TabBar 颜色

    // TabBar 选中颜色
    static var appTabBarSelected: UIColor {
        return appPrimary
    }

    // TabBar 未选中颜色
    static var appTabBarUnselected: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.42, green: 0.47, blue: 0.58, alpha: 1.0)      // #6B7894 蓝灰
                : UIColor(red: 0.55, green: 0.58, blue: 0.67, alpha: 1.0)      // #8C94AB 中灰蓝
        }
    }

    // MARK: - 分割线颜色

    static var appSeparator: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.24, blue: 0.35, alpha: 0.6)      // 深蓝分割线
                : UIColor(red: 0.86, green: 0.89, blue: 0.93, alpha: 1.0)      // #DBE3ED 浅灰蓝分割线
        }
    }

    // MARK: - 状态颜色

    // 成功
    static var appSuccess: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.38, green: 0.78, blue: 0.55, alpha: 1.0)      // #61C78C 柔绿
                : UIColor(red: 0.18, green: 0.65, blue: 0.42, alpha: 1.0)      // #2EA66B 清新绿
        }
    }

    // 警告
    static var appWarning: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.95, green: 0.72, blue: 0.30, alpha: 1.0)      // #F2B84D 柔橙
                : UIColor(red: 0.88, green: 0.60, blue: 0.12, alpha: 1.0)      // #E0991F 暖橙
        }
    }

    // 错误
    static var appError: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.92, green: 0.42, blue: 0.42, alpha: 1.0)      // #EB6B6B 柔红
                : UIColor(red: 0.84, green: 0.22, blue: 0.27, alpha: 1.0)      // #D63845 温和红
        }
    }

    // MARK: - 输入框颜色

    // 输入框背景
    static var appInputBackground: UIColor {
        return appBackgroundSecondary
    }

    // 输入框边框
    static var appInputBorder: UIColor {
        return appCardBorder
    }

    // 输入框聚焦边框
    static var appInputBorderFocused: UIColor {
        return appPrimary
    }

    // 输入框占位符
    static var appInputPlaceholder: UIColor {
        return appTextTertiary
    }

    // MARK: - 遮罩颜色

    // 半透明遮罩（弹窗背景）
    static var appOverlay: UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.0, green: 0.02, blue: 0.07, alpha: 0.75)      // 深蓝黑遮罩
                : UIColor(red: 0.0, green: 0.0,  blue: 0.0,  alpha: 0.40)      // 标准黑色遮罩
        }
    }
}
