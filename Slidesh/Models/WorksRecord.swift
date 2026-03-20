// Slidesh/Models/WorksRecord.swift
import Foundation

// 本地保存的大纲记录
struct OutlineRecord: Codable, Identifiable {
    let id: String          // taskId
    var subject: String
    var markdown: String
    var savedAt: Date
}

// 本地保存的 PPT 记录
struct PPTRecord: Codable, Identifiable {
    let id: String          // pptId
    var taskId: String?
    var subject: String
    var fileUrl: String
    var coverUrl: String?
    var savedAt: Date
}
