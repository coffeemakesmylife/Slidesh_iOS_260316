// Slidesh/Services/WorksStore.swift
import Foundation

// 通知名：作品数据有变更，MyWorksViewController 订阅刷新
extension Notification.Name {
    static let worksDidUpdate = Notification.Name("WorksStore.worksDidUpdate")
}

class WorksStore {
    static let shared = WorksStore()
    private init() { load() }

    private(set) var outlines: [OutlineRecord] = []
    private(set) var ppts:     [PPTRecord]     = []

    // MARK: - 大纲

    // 保存或更新大纲（taskId 相同则覆盖）
    func saveOutline(_ record: OutlineRecord) {
        if let idx = outlines.firstIndex(where: { $0.id == record.id }) {
            outlines[idx] = record
        } else {
            outlines.insert(record, at: 0)
        }
        persist()
    }

    // MARK: - PPT

    // 保存或更新 PPT（pptId 相同则覆盖）
    func savePPT(_ record: PPTRecord) {
        if let idx = ppts.firstIndex(where: { $0.id == record.id }) {
            ppts[idx] = record
        } else {
            ppts.insert(record, at: 0)
        }
        persist()
    }

    // MARK: - 持久化

    private var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("works.json")
    }

    private struct Store: Codable {
        var outlines: [OutlineRecord]
        var ppts:     [PPTRecord]
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let store = try? JSONDecoder().decode(Store.self, from: data) else { return }
        outlines = store.outlines
        ppts     = store.ppts
    }

    private func persist() {
        let store = Store(outlines: outlines, ppts: ppts)
        if let data = try? JSONEncoder().encode(store) {
            try? data.write(to: storeURL, options: .atomic)
        }
        NotificationCenter.default.post(name: .worksDidUpdate, object: nil)
    }
}
