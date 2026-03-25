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
    static let appId = "REPLACE_WITH_REAL_APP_ID"

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
