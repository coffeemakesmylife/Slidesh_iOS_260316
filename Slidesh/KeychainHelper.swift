//
//  KeychainHelper.swift
//  Slidesh
//
//  Created by Ted on 2026/3/16.
//

import Security
import Foundation

/// Keychain 操作工具类，用于安全存储敏感数据
class KeychainHelper {

    /// 保存字符串数据到 Keychain
    static func save(key: String, data: String) -> Bool {
        guard let dataToSave = data.data(using: .utf8) else {
            print("KeychainHelper: 无法将字符串转换为 Data")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: dataToSave,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // 删除旧数据（如果存在）
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("KeychainHelper: 保存成功，key: \(key)")
            return true
        } else {
            print("KeychainHelper: 保存失败，状态码: \(status)")
            return false
        }
    }

    /// 从 Keychain 读取字符串数据
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            if let data = result as? Data,
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return nil
        } else if status == errSecItemNotFound {
            return nil
        } else {
            print("KeychainHelper: 读取失败，状态码: \(status)，key: \(key)")
            return nil
        }
    }

    /// 从 Keychain 删除数据
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
