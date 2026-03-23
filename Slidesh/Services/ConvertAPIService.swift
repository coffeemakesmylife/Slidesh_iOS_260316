//
//  ConvertAPIService.swift
//  Slidesh
//
//  文档格式转换接口服务：multipart/form-data 上传 + 进度回调 + 结果文件下载
//

import Foundation
import ObjectiveC

// MARK: - Associated Object Key（用于给 URLSessionDataTask 附加响应数据缓冲区）

private var responseDataKey: UInt8 = 0

// MARK: - ConvertAPIService

final class ConvertAPIService: NSObject {

    static let shared = ConvertAPIService()

    // 统一文档格式转换服务器
    private let convertBaseURL = "http://43.163.228.96:8080/open_cat"

    // 当前上传任务（用于 cancel）
    private var currentTask: URLSessionDataTask?

    // 上传进度 / 完成回调（delegate 方法中使用）
    private var uploadProgressHandler: ((Double) -> Void)?
    private var completionHandler: ((Result<[URL], Error>) -> Void)?
    // 当前转换的目标文件扩展名（用于 URL 无扩展时 fallback）
    private var currentFallbackExt: String = ""

    // 每次请求创建独立 URLSession，避免 delegate 永久持有 self
    private var currentSession: URLSession?

    private override init() { super.init() }

    // MARK: - 公开接口

    /// 发起文件转换请求，所有回调均在主线程
    func convert(
        tool: ConvertToolKind,
        files: [URL],
        outputFormat: String?,
        onUploadProgress: @escaping (Double) -> Void,
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        // 保存回调供 delegate 方法使用
        uploadProgressHandler = onUploadProgress
        completionHandler = completion
        // 推导目标扩展名（URL 无扩展时用作 fallback）
        currentFallbackExt = fallbackExtension(tool: tool, outputFormat: outputFormat)

        // 构建 multipart boundary
        let boundary = "Boundary-\(UUID().uuidString)"

        // 一次性构建请求（避免重复读取磁盘文件）
        let buildResult = buildRequest(tool: tool, files: files, outputFormat: outputFormat, boundary: boundary)

        switch buildResult {
        case .failure(let error):
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        case .success(let request):
            // 每次请求创建新 session，避免 delegate 生命周期问题
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            currentSession = session
            let task = session.dataTask(with: request)
            currentTask = task
            task.resume()
        }
    }

    /// 取消当前上传任务
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - 私有：构建请求

    /// 根据工具类型构建 multipart/form-data 请求，返回 Result 避免强制解包
    private func buildRequest(
        tool: ConvertToolKind,
        files: [URL],
        outputFormat: String?,
        boundary: String
    ) -> Result<URLRequest, Error> {
        // 合并 PDF 使用独立服务器，其余使用 convert 服务器
        let selectedBase = convertBaseURL
        // 确定接口路径和表单字段
        let path: String
        var body = Data()

        switch tool {
        case .pdfToWord:
            // 固定输出 WORD 格式
            path = "/v1/api/document/pdf/pdftofile"
            body.appendField("type", value: "WORD", boundary: boundary)
            guard let file = files.first else {
                return .failure(APIError.serverError("未选择文件"))
            }
            if let err = body.appendFile(field: "file", url: file, boundary: boundary, mimeType: mimeType(for: file)) {
                return .failure(err)
            }

        case .pdfConvert:
            // 输出格式由调用方传入
            path = "/v1/api/document/pdf/pdftofile"
            body.appendField("type", value: outputFormat ?? "WORD", boundary: boundary)
            guard let file = files.first else {
                return .failure(APIError.serverError("未选择文件"))
            }
            if let err = body.appendFile(field: "file", url: file, boundary: boundary, mimeType: mimeType(for: file)) {
                return .failure(err)
            }

        case .mergePDF:
            if files.count >= 3 {
                // TODO: confirm multipart key name for mergemorepdf ("file" vs "files")
                path = "/v1/api/document/pdf/mergemorepdf"
                for file in files {
                    if let err = body.appendFile(field: "files", url: file, boundary: boundary, mimeType: mimeType(for: file)) {
                        return .failure(err)
                    }
                }
            } else {
                // 两个文件合并：file1 / file2
                path = "/v1/api/document/pdf/mergetwopdf"
                guard files.count >= 2 else {
                    return .failure(APIError.serverError("合并需要至少 2 个文件"))
                }
                if let err = body.appendFile(field: "file1", url: files[0], boundary: boundary, mimeType: mimeType(for: files[0])) {
                    return .failure(err)
                }
                if let err = body.appendFile(field: "file2", url: files[1], boundary: boundary, mimeType: mimeType(for: files[1])) {
                    return .failure(err)
                }
            }

        case .wordConvert:
            path = "/v1/api/document/word/wordtofile"
            body.appendField("type", value: outputFormat ?? "PDF", boundary: boundary)
            guard let file = files.first else {
                return .failure(APIError.serverError("未选择文件"))
            }
            if let err = body.appendFile(field: "file", url: file, boundary: boundary, mimeType: mimeType(for: file)) {
                return .failure(err)
            }

        case .excelConvert:
            path = "/v1/api/document/excel/exceltofile"
            body.appendField("type", value: outputFormat ?? "PDF", boundary: boundary)
            guard let file = files.first else {
                return .failure(APIError.serverError("未选择文件"))
            }
            if let err = body.appendFile(field: "file", url: file, boundary: boundary, mimeType: mimeType(for: file)) {
                return .failure(err)
            }

        case .pptConvert:
            path = "/v1/api/document/ppt/ppttofile"
            body.appendField("type", value: outputFormat ?? "PDF", boundary: boundary)
            guard let file = files.first else {
                return .failure(APIError.serverError("未选择文件"))
            }
            if let err = body.appendFile(field: "file", url: file, boundary: boundary, mimeType: mimeType(for: file)) {
                return .failure(err)
            }

        case .fileToImage:
            path = "/v1/api/document/images/filetoimages"
            guard let file = files.first else {
                return .failure(APIError.serverError("未选择文件"))
            }
            if let err = body.appendFile(field: "file", url: file, boundary: boundary, mimeType: mimeType(for: file)) {
                return .failure(err)
            }
        }

        // multipart 结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        guard let url = URL(string: selectedBase + path) else {
            return .failure(APIError.invalidURL)
        }

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        return .success(request)
    }

    // MARK: - 私有：响应解析

    /// 解析响应 JSON，提取 newslist 字段并下载结果文件
    private func handleResponse(_ data: Data, completion: @escaping (Result<[URL], Error>) -> Void) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            DispatchQueue.main.async { completion(.failure(APIError.noData)) }
            return
        }

        // 检查业务错误码
        if let code = json["code"] as? Int, code != 0 && code != 200 {
            let msg = json["msg"] as? String ?? "服务器错误（code: \(code)）"
            DispatchQueue.main.async { completion(.failure(APIError.serverError(msg))) }
            return
        }

        let newslist = json["newslist"]

        // DEBUG 打印原始值，方便联调
        #if DEBUG
        print("[ConvertAPI] newslist raw: \(String(describing: newslist))")
        #endif

        // TODO: confirm newslist schema with real server
        var urlStrings: [String] = []

        if let str = newslist as? String, !str.isEmpty {
            // newslist 直接是单个 URL 字符串
            urlStrings = [str]
        } else if let dict = newslist as? [String: Any] {
            // newslist 是字典，探测常见 key
            if let single = dict["url"] as? String ?? dict["fileUrl"] as? String
                            ?? dict["downloadUrl"] as? String ?? dict["path"] as? String {
                urlStrings = [single]
            } else if let arr = dict["urls"] as? [String] ?? dict["list"] as? [String]
                                ?? dict["images"] as? [String] {
                urlStrings = arr
            } else {
                #if DEBUG
                print("[ConvertAPI] newslist dict 未识别结构：\(dict)")
                #endif
                DispatchQueue.main.async { completion(.failure(APIError.serverError("转换结果解析失败，请重试"))) }
                return
            }
        } else if let arr = newslist as? [String] {
            // newslist 直接是 URL 数组
            urlStrings = arr
        } else {
            #if DEBUG
            print("[ConvertAPI] newslist 未识别类型：\(String(describing: newslist))")
            #endif
            DispatchQueue.main.async { completion(.failure(APIError.serverError("转换结果解析失败，请重试"))) }
            return
        }

        downloadFiles(from: urlStrings, fallbackExt: currentFallbackExt, completion: completion)
    }

    // MARK: - 私有：串行下载结果文件

    /// 逐个下载 URL 到临时目录，全部完成后调用 completion(.success([URL]))
    /// fallbackExt：当 URL 无扩展名时使用（如 "docx"、"pdf"）
    private func downloadFiles(
        from urlStrings: [String],
        fallbackExt: String = "",
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        var results: [URL] = []

        func downloadNext(index: Int) {
            guard index < urlStrings.count else {
                DispatchQueue.main.async { completion(.success(results)) }
                return
            }

            let urlString = urlStrings[index]
            guard let url = URL(string: urlString) else {
                #if DEBUG
                print("[ConvertAPI] 无效下载 URL：\(urlString)")
                #endif
                downloadNext(index: index + 1)
                return
            }

            #if DEBUG
            print("[ConvertAPI] 下载文件：\(url)")
            #endif

            URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                // 检查 HTTP 状态码，非 2xx 视为下载失败
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    let err = APIError.serverError("文件下载失败（HTTP \(http.statusCode)），请重试")
                    DispatchQueue.main.async { completion(.failure(err)) }
                    return
                }
                guard let tempURL = tempURL else {
                    DispatchQueue.main.async { completion(.failure(APIError.noData)) }
                    return
                }

                // 保留原文件名；若无扩展名则补充 fallbackExt
                var fileName = url.lastPathComponent.isEmpty ? "result_\(index)" : url.lastPathComponent
                if url.pathExtension.isEmpty, !fallbackExt.isEmpty {
                    fileName = "\(fileName).\(fallbackExt)"
                }
                let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    results.append(destURL)
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }

                downloadNext(index: index + 1)
            }.resume()
        }

        downloadNext(index: 0)
    }

    // MARK: - 私有：目标扩展名推导

    /// 根据工具类型和输出格式推导文件扩展名（大写 format → 小写 ext）
    private func fallbackExtension(tool: ConvertToolKind, outputFormat: String?) -> String {
        switch tool {
        case .pdfToWord:            return "docx"
        case .mergePDF:             return "pdf"
        case .fileToImage:          return "png"
        case .pdfConvert, .wordConvert, .excelConvert, .pptConvert:
            switch (outputFormat ?? "").uppercased() {
            case "WORD":  return "docx"
            case "PDF":   return "pdf"
            case "EXCEL": return "xlsx"
            case "PPT":   return "pptx"
            case "PNG":   return "png"
            case "HTML":  return "html"
            case "XML":   return "xml"
            default:      return ""
            }
        }
    }

    // MARK: - 私有：MIME 类型映射

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":  return "application/pdf"
        case "doc":  return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":  return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":  return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default:     return "application/octet-stream"
        }
    }
}

// MARK: - URLSessionDataDelegate（上传进度 + 响应数据累积）

extension ConvertAPIService: URLSessionDataDelegate {

    /// 上传进度回调
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let handler = uploadProgressHandler
        DispatchQueue.main.async { handler?(progress) }
    }

    /// 累积响应数据（用 Associated Object 存储，避免在 extension 中声明存储属性）
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 取出已有缓冲区
        var buffer: Data
        if let existing = objc_getAssociatedObject(dataTask, &responseDataKey) as? Data {
            buffer = existing
        } else {
            buffer = Data()
        }
        buffer.append(data)
        objc_setAssociatedObject(dataTask, &responseDataKey, buffer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// 请求完成（成功或失败）
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let completion = completionHandler
        completionHandler = nil
        uploadProgressHandler = nil
        currentTask = nil

        // 完成后使 session 失效，释放 delegate 引用
        currentSession?.finishTasksAndInvalidate()
        currentSession = nil

        if let error = error {
            // 用户主动取消，不触发错误回调
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }
            DispatchQueue.main.async { completion?(.failure(error)) }
            return
        }

        // 取出累积的响应数据
        guard let dataTask = task as? URLSessionDataTask,
              let responseData = objc_getAssociatedObject(dataTask, &responseDataKey) as? Data,
              !responseData.isEmpty else {
            DispatchQueue.main.async { completion?(.failure(APIError.noData)) }
            return
        }

        // 清理 Associated Object
        objc_setAssociatedObject(dataTask, &responseDataKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        handleResponse(responseData) { result in
            // handleResponse 内部已 dispatch 到主线程
            completion?(result)
        }
    }
}

// MARK: - Data 多部分表单工具扩展（私有）

private extension Data {

    /// 追加普通文本字段
    mutating func appendField(_ name: String, value: String, boundary: String) {
        var field = "--\(boundary)\r\n"
        field += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        field += "\(value)\r\n"
        if let d = field.data(using: .utf8) { append(d) }
    }

    /// 追加文件字段，读取失败返回 Error
    @discardableResult
    mutating func appendFile(
        field: String,
        url: URL,
        boundary: String,
        mimeType: String
    ) -> Error? {
        let fileName = url.lastPathComponent
        var header = "--\(boundary)\r\n"
        header += "Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(fileName)\"\r\n"
        header += "Content-Type: \(mimeType)\r\n\r\n"
        guard let headerData = header.data(using: .utf8) else { return nil }

        // 从磁盘读取文件内容
        do {
            let fileData = try Data(contentsOf: url)
            append(headerData)
            append(fileData)
            if let tail = "\r\n".data(using: .utf8) { append(tail) }
            return nil
        } catch {
            return error
        }
    }
}
