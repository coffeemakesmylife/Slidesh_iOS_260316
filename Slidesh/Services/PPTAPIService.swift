//
//  PPTAPIService.swift
//  Slidesh
//
//  AIPPT 接口服务：筛选选项 + 分页查询模板
//

import Foundation

class PPTAPIService {

    static let shared = PPTAPIService()
    private init() {}

    private let appId   = "6744651694"
    private let baseURL = "http://43.156.217.34:8080"

    // RSA 公钥——用于解密服务端用私钥签名的响应数据
    private let publicKey = """
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCZjwQxE/33I+E+WWPNbvcrq/yPHVFGXOonC8evV2OkCs7rDCCXCW2pwoy5MF5cfDVXqoLzkP4L3X8kXgsEribUztfpp3I34BSushpfrHLghbTKr6WGWTl+jOmNQgHNertkdDd1pLshneVcV7JGBWsP2yZ4uwmYSqBQgK8idk58PwIDAQAB
    -----END PUBLIC KEY-----
    """

    // MARK: - 公开接口

    /// 获取筛选选项（分类 / 风格 / 颜色），回调在主线程
    func fetchOptions(completion: @escaping (Result<[PPTOption], Error>) -> Void) {
        post(path: "/v1/api/ai/ppt/templates-options",
             params: ["appId": appId, "lang": "zh"]) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let raw):
                completion(.success(self.parseOptions(raw)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 分页查询 PPT 模板，空字符串筛选参数表示不过滤，回调在主线程
    func fetchTemplates(
        category:   String?,
        style:      String?,
        themeColor: String?,
        page:       Int,
        pageSize:   Int = 20,
        completion: @escaping (Result<[PPTTemplate], Error>) -> Void
    ) {
        var params: [String: String] = [
            "appId":       appId,
            "currentPage": "\(page)",
            "pageSize":    "\(pageSize)"
        ]
        if let c = category,   !c.isEmpty { params["category"]   = c }
        if let s = style,      !s.isEmpty { params["style"]      = s }
        if let t = themeColor, !t.isEmpty { params["themeColor"] = t }

        post(path: "/v1/api/ai/ppt/templates", params: params) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let raw):
                completion(.success(self.parseTemplates(raw)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 私有：网络请求

    private func post(
        path: String,
        params: [String: String],
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + path) else {
            DispatchQueue.main.async { completion(.failure(APIError.invalidURL)) }
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data, let self else {
                DispatchQueue.main.async { completion(.failure(APIError.noData)) }
                return
            }
            if let decrypted = self.decryptResponse(data) {
                DispatchQueue.main.async { completion(.success(decrypted)) }
            } else {
                DispatchQueue.main.async { completion(.failure(APIError.decryptFailed)) }
            }
        }.resume()
    }

    // MARK: - 私有：RSA 解密

    /// 响应格式：{"code":0, "newslist":"<URL编码的Base64 RSA密文>"}
    /// newslist 解密后为 JSON 数组
    private func decryptResponse(_ data: Data) -> Any? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ 响应 JSON 解析失败，原始内容：\(String(data: data, encoding: .utf8) ?? "-")")
            return nil
        }
        guard let encrypted = json["newslist"] as? String else {
            print("❌ newslist 字段缺失，响应：\(json)")
            return nil
        }
        let decoded = encrypted.removingPercentEncoding ?? encrypted
        guard let decrypted = RSAHelper.decryptString(decoded, publicKey: publicKey) else {
            print("❌ RSA 解密失败")
            return nil
        }
        guard let resultData = decrypted.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: resultData) else {
            print("❌ 解密后 JSON 解析失败：\(decrypted.prefix(200))")
            return nil
        }
        return result
    }

    // MARK: - 私有：JSON → Model

    private func parseOptions(_ raw: Any) -> [PPTOption] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { dict in
            guard let name  = dict["name"]  as? String,
                  let type  = dict["type"]  as? String,
                  let value = dict["value"] as? String
            else { return nil }
            return PPTOption(name: name, type: type, value: value)
        }
    }

    private func parseTemplates(_ raw: Any) -> [PPTTemplate] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { dict in
            guard let id       = dict["id"]       as? String,
                  let coverUrl = dict["coverUrl"] as? String,
                  let subject  = dict["subject"]  as? String
            else { return nil }
            return PPTTemplate(
                id:         id,
                type:       dict["type"]       as? Int    ?? 1,
                coverUrl:   coverUrl,
                category:   dict["category"]   as? String ?? "",
                style:      dict["style"]      as? String ?? "",
                themeColor: dict["themeColor"] as? String ?? "",
                subject:    subject,
                num:        dict["num"]        as? Int    ?? 0,
                createTime: dict["createTime"] as? String ?? ""
            )
        }
    }
}

// MARK: - 错误类型

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decryptFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:     return "无效的请求地址"
        case .noData:         return "服务器无响应"
        case .decryptFailed:  return "数据解密失败"
        }
    }
}
