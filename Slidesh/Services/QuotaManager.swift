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
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil {
                hasPremium = true
                break
            }
        }
        await MainActor.run { self.isPremium = hasPremium }
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
        _ = KeychainHelper.save(key: feature.keychainKey, data: String(used + 1))
        return true
    }

    /// 当前剩余次数（调试用）
    func remaining(_ feature: QuotaFeature) -> Int {
        let used = Int(KeychainHelper.load(key: feature.keychainKey) ?? "0") ?? 0
        return max(0, feature.limit - used)
    }
}
