//
//  WorksStore.swift
//  Slidesh
//
//  本地作品持久化：大纲 + PPT，线程安全，磁盘 IO 在后台队列
//

import Foundation

// 通知名：作品数据有变更，MyWorksViewController 订阅刷新
extension Notification.Name {
    static let worksDidUpdate = Notification.Name("WorksStore.worksDidUpdate")
}

class WorksStore {
    static let shared = WorksStore()

    // 所有数组读写都通过此队列序列化
    private let queue = DispatchQueue(label: "WorksStore", qos: .utility)

    private var _outlines:  [OutlineRecord]  = []
    private var _ppts:      [PPTRecord]      = []
    private var _converts:  [ConvertRecord]  = []

    // 主线程只读快照（读时同步）
    var outlines:  [OutlineRecord]  { queue.sync { _outlines } }
    var ppts:      [PPTRecord]      { queue.sync { _ppts } }
    var converts:  [ConvertRecord]  { queue.sync { _converts } }

    private let storeURL: URL

    private init() {
        storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("works.json")
        loadSync()
    }

    // MARK: - 大纲

    // 保存或更新大纲（taskId 相同则覆盖）
    func saveOutline(_ record: OutlineRecord) {
        queue.async { [self] in
            if let idx = _outlines.firstIndex(where: { $0.id == record.id }) {
                _outlines[idx] = record
            } else {
                _outlines.insert(record, at: 0)
            }
            persistAsync()
        }
    }

    // MARK: - PPT

    // 保存或更新 PPT（pptId 相同则覆盖）
    func savePPT(_ record: PPTRecord) {
        queue.async { [self] in
            if let idx = _ppts.firstIndex(where: { $0.id == record.id }) {
                _ppts[idx] = record
            } else {
                _ppts.insert(record, at: 0)
            }
            persistAsync()
        }
    }

    // MARK: - 转换记录

    func saveConvert(_ record: ConvertRecord) {
        queue.async { [self] in
            _converts.insert(record, at: 0)
            persistAsync()
        }
    }

    func deleteConvert(id: String) {
        queue.async { [self] in
            _converts.removeAll { $0.id == id }
            persistAsync()
        }
    }

    // MARK: - 持久化（已在 queue 上执行）

    // converts 字段用 custom decoding 兼容旧 JSON（旧数据无此字段时默认空数组）
    private struct Store: Codable {
        var outlines: [OutlineRecord]
        var ppts:     [PPTRecord]
        var converts: [ConvertRecord]

        init(outlines: [OutlineRecord], ppts: [PPTRecord], converts: [ConvertRecord]) {
            self.outlines = outlines
            self.ppts     = ppts
            self.converts = converts
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            outlines = try c.decode([OutlineRecord].self,  forKey: .outlines)
            ppts     = try c.decode([PPTRecord].self,      forKey: .ppts)
            converts = (try? c.decode([ConvertRecord].self, forKey: .converts)) ?? []
        }
    }

    // 从磁盘同步加载，仅在 init 时调用（queue 尚未开始执行任务）
    private func loadSync() {
        guard let data  = try? Data(contentsOf: storeURL),
              let store = try? JSONDecoder().decode(Store.self, from: data) else { return }
        _outlines = store.outlines
        _ppts     = store.ppts
        _converts = store.converts
    }

    // 在 queue 内异步写盘，写完后切回主线程发通知
    private func persistAsync() {
        let snapshot = Store(outlines: _outlines, ppts: _ppts, converts: _converts)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storeURL, options: .atomic)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .worksDidUpdate, object: nil)
        }
    }
}
