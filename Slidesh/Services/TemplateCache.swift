//
//  TemplateCache.swift
//  Slidesh
//
//  版本/语言感知的模板缓存服务（内存 + 磁盘两级，stale-while-revalidate）
//

import Foundation

// MARK: - 缓存查询结果

enum CacheFetchResult {
    case fresh(Any)  // 未过期；调用方用 isAging(key:) 判断是否触发后台刷新
    case stale(Any)  // 已过期但有旧数据；调用方立即展示并前台刷新
    case miss        // 无缓存
}

// MARK: - 缓存条目（NSCache value 必须是 AnyObject）

private final class CacheEntry: NSObject {
    let data:      Any
    let timestamp: TimeInterval
    let ttl:       TimeInterval

    init(data: Any, timestamp: TimeInterval, ttl: TimeInterval) {
        self.data      = data
        self.timestamp = timestamp
        self.ttl       = ttl
    }

    var age:       TimeInterval { Date().timeIntervalSince1970 - timestamp }
    var isExpired: Bool         { age >= ttl }
    var isAging:   Bool         { age >= ttl * 0.8 }
}

// MARK: - TemplateCache

final class TemplateCache {

    static let shared = TemplateCache()
    private init() {}

    static let templatesTTL: TimeInterval = 10 * 60          // 10 分钟
    static let optionsTTL:   TimeInterval = 24 * 60 * 60     // 24 小时

    private let memory    = NSCache<NSString, CacheEntry>()
    // 所有磁盘写操作通过串行队列，防止并发冲突
    private let diskQueue = DispatchQueue(label: "com.slidesh.cache.disk", qos: .utility)

    // MARK: - Key 生成

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private static var lang: String {
        Locale.preferredLanguages.first ?? "zh"
    }

    /// type 只允许 "options"（无下划线），不含筛选/页码后缀
    static func optionsKey() -> String {
        "options_\(appVersion)_\(lang)"
    }

    /// type 只允许 "templates"（无下划线）；未选中的筛选传空字符串，位置固定
    static func templatesKey(category: String, style: String,
                             color: String, page: Int = 1) -> String {
        "templates_\(appVersion)_\(lang)_\(category)_\(style)_\(color)_p\(page)"
    }

    // MARK: - 模板读写

    func fetchTemplates(key: String) -> CacheFetchResult {
        switch fetchRaw(key: key) {
        case .fresh(let data):
            guard let t = decodeTemplates(data) else { return .miss }
            return .fresh(t)
        case .stale(let data):
            guard let t = decodeTemplates(data) else { return .miss }
            return .stale(t)
        case .miss:
            return .miss
        }
    }

    func storeTemplates(key: String, templates: [PPTTemplate]) {
        store(key: key, data: templates.map { $0.asDictionary }, ttl: Self.templatesTTL)
    }

    // MARK: - 筛选选项读写

    func fetchOptions(key: String) -> CacheFetchResult {
        switch fetchRaw(key: key) {
        case .fresh(let data):
            guard let o = decodeOptions(data) else { return .miss }
            return .fresh(o)
        case .stale(let data):
            guard let o = decodeOptions(data) else { return .miss }
            return .stale(o)
        case .miss:
            return .miss
        }
    }

    func storeOptions(key: String, options: [PPTOption]) {
        let encoded = options.map { ["name": $0.name, "type": $0.type, "value": $0.value] }
        store(key: key, data: encoded, ttl: Self.optionsTTL)
    }

    /// 缓存是否接近过期（≥80% TTL），供调用方决定是否触发后台刷新
    func isAging(key: String) -> Bool {
        memory.object(forKey: key as NSString)?.isAging ?? false
    }

    // MARK: - 孤立文件清理（App 启动时调用）

    func cleanupOrphanedFiles() {
        let currentVersion = Self.appVersion
        diskQueue.async { [weak self] in
            guard let dir   = self?.cacheDir,
                  let files = try? FileManager.default.contentsOfDirectory(
                      at: dir, includingPropertiesForKeys: nil,
                      options: .skipsHiddenFiles)
            else { return }

            for file in files {
                // Key 格式：{type}_{appVersion}_{lang}...
                // type 不含下划线，index 1 即版本号，做精确匹配
                let base       = file.deletingPathExtension().lastPathComponent
                let components = base.split(separator: "_",
                                            omittingEmptySubsequences: false).map(String.init)
                if components.count < 2 || components[1] != currentVersion {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - 私有：内部通用 fetch

    private func fetchRaw(key: String) -> CacheFetchResult {
        // 1. 内存命中
        if let entry = memory.object(forKey: key as NSString) {
            if !entry.isExpired { return .fresh(entry.data) }
            memory.removeObject(forKey: key as NSString)
        }
        // 2. 磁盘命中
        if let entry = loadFromDisk(key: key) {
            memory.setObject(entry, forKey: key as NSString)
            return entry.isExpired ? .stale(entry.data) : .fresh(entry.data)
        }
        return .miss
    }

    private func store(key: String, data: Any, ttl: TimeInterval) {
        let entry = CacheEntry(data: data,
                               timestamp: Date().timeIntervalSince1970,
                               ttl: ttl)
        memory.setObject(entry, forKey: key as NSString)
        diskQueue.async { [weak self] in
            self?.writeToDisk(key: key, entry: entry)
        }
    }

    // MARK: - 磁盘 I/O

    private var cacheDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PPTTemplateCache")
    }

    private func ensureCacheDir() -> URL? {
        guard let dir = cacheDir else { return nil }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 只允许 [A-Za-z0-9._-]，其余替换为 -
    private func filename(for key: String) -> String {
        let safe = key.unicodeScalars.map { scalar -> Character in
            let c = Character(scalar)
            return (c.isLetter || c.isNumber || c == "." || c == "_" || c == "-") ? c : "-"
        }
        return String(safe) + ".json"
    }

    private func writeToDisk(key: String, entry: CacheEntry) {
        guard let dir = ensureCacheDir(),
              JSONSerialization.isValidJSONObject(entry.data) else { return }

        evictIfNeeded(dir: dir)

        let envelope: [String: Any] = [
            "timestamp": entry.timestamp,
            "ttl":       entry.ttl,
            "data":      entry.data,
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: envelope) else { return }
        try? bytes.write(to: dir.appendingPathComponent(filename(for: key)))
    }

    private func loadFromDisk(key: String) -> CacheEntry? {
        guard let dir  = cacheDir else { return nil }
        let fileURL    = dir.appendingPathComponent(filename(for: key))
        guard let bytes     = try? Data(contentsOf: fileURL),
              let envelope  = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let timestamp = envelope["timestamp"] as? TimeInterval,
              let ttl       = envelope["ttl"]       as? TimeInterval,
              let data      = envelope["data"]
        else { return nil }
        return CacheEntry(data: data, timestamp: timestamp, ttl: ttl)
    }

    /// 超过 50 个文件时删除最旧的（已在 diskQueue 上调用）
    private func evictIfNeeded(dir: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles),
              files.count >= 50 else { return }

        let oldest = files.min {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            return a < b
        }
        if let oldest { try? fm.removeItem(at: oldest) }
    }

    // MARK: - 解码辅助

    private func decodeTemplates(_ data: Any) -> [PPTTemplate]? {
        guard let arr = data as? [[String: Any]] else { return nil }
        return arr.compactMap { PPTTemplate(dictionary: $0) }
    }

    private func decodeOptions(_ data: Any) -> [PPTOption]? {
        guard let arr = data as? [[String: Any]] else { return nil }
        return arr.compactMap { dict -> PPTOption? in
            guard let name  = dict["name"]  as? String,
                  let type  = dict["type"]  as? String,
                  let value = dict["value"] as? String else { return nil }
            return PPTOption(name: name, type: type, value: value)
        }
    }
}
