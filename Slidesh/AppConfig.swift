//
//  AppConfig.swift
//  Slidesh
//
//  全局应用配置：appId、服务器地址等可部署时替换的参数
//

import Foundation

struct AppConfig {

    /// 上线时使用的正式 appId，用于配置拉取请求
    /// TODO: 替换为服务端分配的正式 appId
    static let appId = "6761677729"

    // TODO: 替换为正式的配置分发服务器地址
    static let configServerURL = "http://8.134.126.1:8080/api/app/host/list"

    /// 配置分发服务器（host/list 接口）专用 RSA 公钥，与 PPT 服务公钥相互独立
    /// TODO: 替换为配置分发服务器对应的 RSA 公钥
    static let configPublicKey = """
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC80suK11DAidjBJIzvi9g9n8ACxvDoBqKj1t5PZiMkEJA7EsuHCeZVWktXn3dTYM7WSUPjmqBx5L7nfC0QdTU+5Ih988+GS3xgDm2gkVYRmONfvH7WWUVfoWGflPNCdmUffW7E6qRX3DVb9Tr2CvubpLouVXaSsnE3GwMWrtV+pQIDAQAB
    -----END PUBLIC KEY-----
    """

    // MARK: - UserDefaults 键

    private static let configBaseURLKey  = "slidesh.config.configBaseURL"   // ipOrPort=1
    private static let convertBaseURLKey = "slidesh.config.convertBaseURL"  // ipOrPort=2
    private static let pptBaseURLKey     = "slidesh.config.pptBaseURL"      // ipOrPort=3

    // MARK: - 兜底地址（host/list 请求失败时生效）

    static let fallbackConfigBaseURL  = "http://8.134.126.1:8080"    // 配置/通知/反馈 API
    static let fallbackConvertBaseURL = "http://43.163.228.96:8080"  // 格式转换服务
    static let fallbackPptBaseURL     = "http://43.156.217.34:8080"  // PPT 生成服务

    // MARK: - 运行时地址（优先已拉取的配置，否则回退兜底）

    /// ipOrPort=1：用于 notice、feedback 等通用 API
    static var configBaseURL: String {
        UserDefaults.standard.string(forKey: configBaseURLKey) ?? fallbackConfigBaseURL
    }

    /// ipOrPort=2：格式转换服务
    static var convertBaseURL: String {
        UserDefaults.standard.string(forKey: convertBaseURLKey) ?? fallbackConvertBaseURL
    }

    /// ipOrPort=3：PPT 生成服务
    static var pptBaseURL: String {
        UserDefaults.standard.string(forKey: pptBaseURLKey) ?? fallbackPptBaseURL
    }

    // MARK: - 持久化

    /// 保存从 host/list 拉取到的地址；nil 表示本次未收到该项，保留旧值
    static func save(configBase: String? = nil, convertBase: String? = nil, pptBase: String? = nil) {
        if let v = configBase  { UserDefaults.standard.set(v, forKey: configBaseURLKey) }
        if let v = convertBase { UserDefaults.standard.set(v, forKey: convertBaseURLKey) }
        if let v = pptBase     { UserDefaults.standard.set(v, forKey: pptBaseURLKey) }
        UserDefaults.standard.synchronize()
    }

    // MARK: - App Store

    /// App Store 评分页直链（enable_star_or_comment == false 时使用）
    /// TODO: 上线前替换为正式 Apple ID（数字）
    static let appStoreReviewURL = "https://apps.apple.com/app/id\(appId)?action=write-review"

    // MARK: - Legal URLs

    /// 隐私政策链接
    static let privacyPolicyURLString = "https://docs.google.com/document/d/10jQz1h_h5Sj5OSdnDRME86BdRCKg-1o9y03ndZIXAdg/edit?usp=sharing"

    /// 用户协议链接
    static let termsOfServiceURLString = "https://docs.google.com/document/d/1KxSeuHffh0ko6f22XIyO_DLYrajOdtfpi0mWzRY4GYw/edit?usp=sharing"

    static var privacyPolicyURL: URL {
        URL(string: privacyPolicyURLString)!
    }

    static var termsOfServiceURL: URL {
        URL(string: termsOfServiceURLString)!
    }

    // MARK: - 应用名称

    /// 运行时读取 bundle displayName，避免 UI 硬编码
    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Slidesh"
    }
}
