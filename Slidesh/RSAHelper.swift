//
//  RSAHelper.swift
//  Slidesh
//
//  RSA 加密解密工具类（用于解密 AIPPT API 响应）
//  参考: https://github.com/ideawu/Objective-C-RSA
//

import Foundation
import Security

class RSAHelper {

    // MARK: - 公开方法 - 字符串加密/解密

    static func encryptString(_ str: String, publicKey: String) -> String? {
        guard let data = str.data(using: .utf8) else { return nil }
        guard let encryptedData = encryptData(data, publicKey: publicKey) else { return nil }
        return encryptedData.base64EncodedString()
    }

    /// 使用公钥解密字符串（服务端用私钥加密，客户端用公钥解密）
    static func decryptString(_ str: String, publicKey: String) -> String? {
        let decodedStr = str.removingPercentEncoding ?? str
        guard let data = Data(base64Encoded: decodedStr, options: .ignoreUnknownCharacters) else {
            print("❌ RSA解密失败: Base64解码失败")
            return nil
        }
        guard let decryptedData = decryptData(data, publicKey: publicKey) else {
            print("❌ RSA解密失败: 解密数据失败")
            return nil
        }
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            print("❌ RSA解密失败: 数据转字符串失败")
            return nil
        }
        return result
    }

    // MARK: - 公开方法 - 数据加密/解密

    static func encryptData(_ data: Data, publicKey: String) -> Data? {
        guard let keyRef = addPublicKey(publicKey) else {
            print("❌ RSA加密失败: 无法创建公钥")
            return nil
        }
        return encryptData(data, withKeyRef: keyRef, isSign: false)
    }

    static func decryptData(_ data: Data, publicKey: String) -> Data? {
        guard let keyRef = addPublicKey(publicKey) else {
            print("❌ RSA解密失败: 无法创建公钥")
            return nil
        }
        return decryptData(data, withKeyRef: keyRef)
    }

    // MARK: - 私有方法 - 密钥管理

    private static func addPublicKey(_ key: String) -> SecKey? {
        var keyString = key

        // 移除 PEM 头尾
        if let startRange = keyString.range(of: "-----BEGIN PUBLIC KEY-----"),
           let endRange = keyString.range(of: "-----END PUBLIC KEY-----") {
            keyString = String(keyString[startRange.upperBound..<endRange.lowerBound])
        }

        // 移除空白字符
        keyString = keyString
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard var data = Data(base64Encoded: keyString) else {
            print("❌ 公钥Base64解码失败")
            return nil
        }

        guard let strippedData = stripPublicKeyHeader(data) else {
            print("❌ 去除公钥头部失败")
            return nil
        }
        data = strippedData

        let tag = "RSAUtil_PubKey_Slidesh"
        guard let tagData = tag.data(using: .utf8) else { return nil }

        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag: tagData
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag: tagData,
            kSecValueData: data,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecReturnPersistentRef: true
        ]

        var persistentRef: CFTypeRef?
        let addStatus = SecItemAdd(addQuery as CFDictionary, &persistentRef)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            print("❌ 添加公钥到Keychain失败: \(addStatus)")
            return nil
        }

        let getQuery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag: tagData,
            kSecReturnRef: true,
            kSecAttrKeyClass: kSecAttrKeyClassPublic
        ]

        var keyRef: CFTypeRef?
        let getStatus = SecItemCopyMatching(getQuery as CFDictionary, &keyRef)
        if getStatus != errSecSuccess {
            print("❌ 获取公钥失败: \(getStatus)")
            return nil
        }

        return (keyRef as! SecKey)
    }

    private static func stripPublicKeyHeader(_ data: Data) -> Data? {
        guard data.count > 0 else { return nil }
        let bytes = [UInt8](data)
        var idx = 0

        guard bytes[idx] == 0x30 else { return nil }
        idx += 1

        if bytes[idx] > 0x80 {
            idx += Int(bytes[idx]) - 0x80 + 1
        } else {
            idx += 1
        }

        let seqiod: [UInt8] = [
            0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
            0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        ]
        guard idx + 15 <= bytes.count else { return nil }
        for i in 0..<15 {
            if bytes[idx + i] != seqiod[i] { return nil }
        }
        idx += 15

        guard bytes[idx] == 0x03 else { return nil }
        idx += 1

        if bytes[idx] > 0x80 {
            idx += Int(bytes[idx]) - 0x80 + 1
        } else {
            idx += 1
        }

        guard bytes[idx] == 0x00 else { return nil }
        idx += 1

        return data.subdata(in: idx..<data.count)
    }

    // MARK: - 私有方法 - 加密（分块）

    private static func encryptData(_ data: Data, withKeyRef keyRef: SecKey, isSign: Bool) -> Data? {
        let blockSize = SecKeyGetBlockSize(keyRef)
        let srcBlockSize = blockSize - 11
        var encryptedData = Data()
        let bytes = [UInt8](data)
        var idx = 0
        while idx < data.count {
            let dataLen = min(srcBlockSize, data.count - idx)
            var outLen = blockSize
            var outBuf = [UInt8](repeating: 0, count: blockSize)
            let status = SecKeyEncrypt(keyRef, .PKCS1, Array(bytes[idx..<idx + dataLen]), dataLen, &outBuf, &outLen)
            if status != errSecSuccess { return nil }
            encryptedData.append(Data(outBuf[0..<outLen]))
            idx += dataLen
        }
        return encryptedData
    }

    // MARK: - 私有方法 - 解密（分块）

    private static func decryptData(_ data: Data, withKeyRef keyRef: SecKey) -> Data? {
        let blockSize = SecKeyGetBlockSize(keyRef)
        var decryptedData = Data()
        let bytes = [UInt8](data)
        var idx = 0
        while idx < data.count {
            let dataLen = min(blockSize, data.count - idx)
            var outLen = blockSize
            var outBuf = [UInt8](repeating: 0, count: blockSize)
            let status = SecKeyDecrypt(keyRef, [], Array(bytes[idx..<idx + dataLen]), dataLen, &outBuf, &outLen)
            if status != errSecSuccess {
                print("❌ SecKeyDecrypt失败: \(status)")
                return nil
            }
            // 定位真实数据起始位置（跳过填充零字节）
            var idxFirstZero = -1
            for i in 0..<outLen where outBuf[i] == 0 {
                idxFirstZero = i
                break
            }
            if idxFirstZero >= 0 && idxFirstZero + 1 < outLen {
                decryptedData.append(Data(outBuf[(idxFirstZero + 1)..<outLen]))
            }
            idx += dataLen
        }
        return decryptedData
    }
}
