//
//  AppDelegate.swift
//  Slidesh
//
//  Created by ted on 2026/3/15.
//

import UIKit
import ZXRequestBlock

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow? = nil

    /// 用户唯一标识符，用于网络请求
    var userId = "1"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        ZXRequestBlock.disableHttpProxy()

        // 从 Keychain 获取或生成用户唯一标识
        userId = generateOrRetrieveUserId()

        // 设置根视图控制器（由 StartupViewController 完成配置后切换到主界面）
        self.window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = StartupViewController()
        window?.makeKeyAndVisible()

        // 恢复上次保存的主题（必须在 makeKeyAndVisible 之后）
        if let w = window {
            ThemeManager.shared.applyOnLaunch(to: w)
        }

        // 清理旧版本遗留的缓存文件
        TemplateCache.shared.cleanupOrphanedFiles()

        return true
    }

    // MARK: - User ID Management

    /// 静态方法：获取当前用户 ID（线程安全）
    static func getCurrentUserId() -> String? {
        if Thread.isMainThread {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                print("❌ 无法获取 AppDelegate 实例")
                return nil
            }
            return appDelegate.userId
        } else {
            return DispatchQueue.main.sync {
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                    print("❌ 无法获取 AppDelegate 实例")
                    return nil
                }
                return appDelegate.userId
            }
        }
    }

    /// 从 Keychain 获取已有 userId，若不存在则生成新的 UUID 并保存
    private func generateOrRetrieveUserId() -> String {
        let keychainKey = "com.slidesh.userId"

        // 尝试从 Keychain 加载已有 ID
        if let existingId = KeychainHelper.load(key: keychainKey) {
            print("从 Keychain 加载用户 ID 成功: \(existingId)")
            return existingId
        }

        // 检查 UserDefaults 中是否有旧版 ID（兼容迁移）
        if let legacyUserId = UserDefaults.standard.object(forKey: "appUserId") as? String {
            print("发现旧版用户 ID，迁移到 Keychain: \(legacyUserId)")
            if KeychainHelper.save(key: keychainKey, data: legacyUserId) {
                UserDefaults.standard.removeObject(forKey: "appUserId")
                return legacyUserId
            }
        }

        // 生成新的 UUID 并保存到 Keychain
        let newUserId = UUID().uuidString
        if KeychainHelper.save(key: keychainKey, data: newUserId) {
            print("生成并保存新用户 ID: \(newUserId)")
            return newUserId
        } else {
            print("保存用户 ID 到 Keychain 失败，使用临时 ID")
            return "temp_\(UUID().uuidString)"
        }
    }


}

