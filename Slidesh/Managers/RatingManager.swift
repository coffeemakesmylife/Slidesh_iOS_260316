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
        hasPrompted = true  // 先占位，防止并发重复触发
        DispatchQueue.main.async { self.presentSatisfactionSheet() }
    }

    /// Debug / 设置页直接展示（跳过 hasPrompted 检查）
    func presentSatisfactionSheet() {
        hasPrompted = true
        SatisfactionSheet.present(
            onPositive: { [weak self] in self?.handlePositive() },
            onNegative: { [weak self] in self?.handleNegative() }
        )
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
        // sheet 收起后 topViewController 可能返回 TabBarController，需取其选中的导航栈
        var vc = topViewController()
        if let tab = vc as? UITabBarController {
            vc = tab.selectedViewController
        }
        let nav = (vc as? UINavigationController) ?? vc?.navigationController
        nav?.pushViewController(FeedbackViewController(), animated: true)
    }

    // MARK: - 工具方法

    private func topViewController() -> UIViewController? {
        guard var top = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
