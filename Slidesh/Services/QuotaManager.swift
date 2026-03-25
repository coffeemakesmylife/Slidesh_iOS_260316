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

@MainActor
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
        // 使用 contains 消除跨 await 的可变变量
        let hasPremium = await Transaction.currentEntitlements.contains { result in
            guard case .verified(let tx) = result else { return false }
            return tx.revocationDate == nil
        }
        isPremium = hasPremium   // @MainActor 类，直接赋值无需 MainActor.run
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
        let saved = KeychainHelper.save(key: feature.keychainKey, data: String(used + 1))
        if !saved { print("QuotaManager: Keychain 写入失败，key: \(feature.keychainKey)") }
        return true
    }

    /// 当前剩余次数（调试用）
    func remaining(_ feature: QuotaFeature) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let used = Int(KeychainHelper.load(key: feature.keychainKey) ?? "0") ?? 0
        return max(0, feature.limit - used)
    }

    // MARK: - Debug 专用

    #if DEBUG
    /// 直接覆盖 Premium 状态（仅 Debug 构建可用）
    func debugSetPremium(_ value: Bool) {
        isPremium = value
    }

    /// 将所有功能的 Keychain 配额计数重置为 0
    func debugResetAllQuotas() {
        for feature in [QuotaFeature.aiOutline, .convert, .pptGenerate] {
            _ = KeychainHelper.save(key: feature.keychainKey, data: "0")
        }
    }
    #endif
}
