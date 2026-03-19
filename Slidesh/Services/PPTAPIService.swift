//
//  PPTAPIService.swift
//  Slidesh
//
//  AIPPT 接口服务：筛选选项 + 分页查询模板
//

import Foundation
import UIKit

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

    /// 创建 PPT 任务（主题输入，type=1），返回 taskId，回调在主线程
    func createTask(subject: String, completion: @escaping (Result<String, Error>) -> Void) {
        let uuid = AppDelegate.getCurrentUserId() ?? "temp"
        let params = ["type": "1", "appId": appId, "uuid": uuid, "subject": subject]
        post(path: "/v1/api/ai/ppt/v2/createTask", params: params) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let raw):
                // taskId 可能是解密后的字符串，也可能封装在字典里
                if let taskId = raw as? String, !taskId.isEmpty {
                    completion(.success(taskId))
                } else if let dict = raw as? [String: Any],
                          let taskId = dict["taskId"] as? String ?? dict["id"] as? String {
                    completion(.success(taskId))
                } else {
                    completion(.failure(APIError.parseTaskIdFailed))
                }
            }
        }
    }

    /// 流式生成大纲内容（SSE），onChunk 实时回调增量文本，onComplete 返回完整 markdown，均在主线程
    @discardableResult
    func generateContent(
        taskId:   String,
        language: String   = "zh",
        length:   String   = "medium",
        scene:    String   = "",
        audience: String   = "",
        prompt:   String?  = nil,
        onChunk:    @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onError:    @escaping (Error) -> Void
    ) -> URLSessionDataTask {
        let uuid = AppDelegate.getCurrentUserId() ?? "temp"

        var body: [String: Any] = [
            "taskId":   taskId,
            "appId":    appId,
            "uuid":     uuid,
            "language": language,
            "length":   length,
        ]
        if !scene.isEmpty    { body["scene"]    = scene }
        if !audience.isEmpty { body["audience"] = audience }
        if let p = prompt, !p.isEmpty { body["prompt"] = p }

        guard let url      = URL(string: baseURL + "/v1/api/ai/ppt/v2/generateContent"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            DispatchQueue.main.async { onError(APIError.invalidURL) }
            // 返回一个已挂起的占位任务（不会发起请求）
            return URLSession.shared.dataTask(with: URLRequest(url: URL(string: "about:blank")!))
        }

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream",   forHTTPHeaderField: "Accept")
        request.httpBody = bodyData

        let delegate = SSEDelegate(onChunk: onChunk, onComplete: onComplete, onError: onError)
        let session  = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task     = session.dataTask(with: request)
        task.resume()
        return task
    }

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

    /// options 响应格式为字典 {category:[...], style:[...], themeColor:[...]}，按 key 分组展平
    private func parseOptions(_ raw: Any) -> [PPTOption] {
        guard let grouped = raw as? [String: Any] else { return [] }
        var options: [PPTOption] = []
        for (type, items) in grouped {
            guard let arr = items as? [[String: Any]] else { continue }
            for item in arr {
                guard let name  = item["name"]  as? String,
                      let value = item["value"] as? String
                else { continue }
                options.append(PPTOption(name: name, type: type, value: value))
            }
        }
        return options
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
    case parseTaskIdFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "无效的请求地址"
        case .noData:            return "服务器无响应"
        case .decryptFailed:     return "数据解密失败"
        case .parseTaskIdFailed: return "任务创建失败，无法获取 taskId"
        }
    }
}

// MARK: - SSE 流式代理

/// 解析 text/event-stream，提取 data: 行并回调
private class SSEDelegate: NSObject, URLSessionDataDelegate {

    private var buffer      = Data()   // 未处理的原始字节
    private var accumulated = ""       // 已拼接的完整内容

    private let onChunk:    (String) -> Void
    private let onComplete: (String) -> Void
    private let onError:    (Error) -> Void

    init(onChunk:    @escaping (String) -> Void,
         onComplete: @escaping (String) -> Void,
         onError:    @escaping (Error)  -> Void) {
        self.onChunk    = onChunk
        self.onComplete = onComplete
        self.onError    = onError
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)

        // SSE 事件以 \n\n 分隔
        guard var text = String(data: buffer, encoding: .utf8) else { return }
        while let separatorRange = text.range(of: "\n\n") {
            let event = String(text[..<separatorRange.lowerBound])
            text = String(text[separatorRange.upperBound...])

            for line in event.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("data:") else { continue }
                let chunk = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                guard chunk != "[DONE]", !chunk.isEmpty else { continue }
                accumulated += chunk
                let copy = chunk
                DispatchQueue.main.async { self.onChunk(copy) }
            }
        }
        // 保留尚未凑成完整事件的剩余数据
        buffer = text.data(using: .utf8) ?? Data()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let final = accumulated
        DispatchQueue.main.async {
            if let error = error {
                self.onError(error)
            } else {
                self.onComplete(final)
            }
        }
    }
}
