//
//  AppConfig.swift
//  Slidesh
//
//  全局应用配置：appId、服务器地址等可部署时替换的参数
//

import Foundation

struct AppConfig {

    // TODO: 上线前替换为正式 appId（当前为测试 ID）
    static let appId = "6744651694"

    // TODO: 替换为正式的配置分发服务器地址
    static let configServerURL = "http://8.134.126.1:8080/api/app/host/list"

    // TODO: 替换为配置分发服务器对应的 RSA 公钥（用于加密请求 + 解密响应）
    static let configPublicKey = """
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCZjwQxE/33I+E+WWPNbvcrq/yPHVFGXOonC8evV2OkCs7rDCCXCW2pwoy5MF5cfDVXqoLzkP4L3X8kXgsEribUztfpp3I34BSushpfrHLghbTKr6WGWTl+jOmNQgHNertkdDd1pLshneVcV7JGBWsP2yZ4uwmYSqBQgK8idk58PwIDAQAB
    -----END PUBLIC KEY-----
    """

    // MARK: - UserDefaults 键

    private static let pptBaseURLKey     = "slidesh.config.pptBaseURL"
    private static let convertBaseURLKey = "slidesh.config.convertBaseURL"

    // MARK: - 兜底地址（配置拉取失败时生效）

    static let fallbackPptBaseURL     = "http://43.156.217.34:8080"
    /// 注意：convertBaseURL 含路径前缀 /open_cat，配置服务器返回的值也应包含此前缀
    static let fallbackConvertBaseURL = "http://43.163.228.96:8080/open_cat"

    // MARK: - 运行时地址（优先已拉取的配置，否则回退兜底）

    static var pptBaseURL: String {
        UserDefaults.standard.string(forKey: pptBaseURLKey) ?? fallbackPptBaseURL
    }

    static var convertBaseURL: String {
        UserDefaults.standard.string(forKey: convertBaseURLKey) ?? fallbackConvertBaseURL
    }

    // MARK: - 持久化

    /// 保存从配置服务器拉取到的地址；nil 表示本次未收到该项，保留旧值
    static func save(pptBase: String? = nil, convertBase: String? = nil) {
        if let v = pptBase     { UserDefaults.standard.set(v, forKey: pptBaseURLKey) }
        if let v = convertBase { UserDefaults.standard.set(v, forKey: convertBaseURLKey) }
        UserDefaults.standard.synchronize()
    }
}
