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

// 本地保存的格式转换记录
struct ConvertRecord: Codable, Identifiable {
    let id: String
    let toolKind: String        // ConvertToolKind.rawValue
    let toolTitle: String
    let toolIcon: String        // SF Symbol name
    let toolColorName: String
    let inputFileName: String   // 单文件名，多文件时为 "x.pdf 等 N 个文件"
    let outputFormat: String?
    // 本地文件：Documents/convert_results/ 下的文件名；远程：完整 URL 字符串
    var resultPaths: [String]
    var isRemoteResult: Bool
    var savedAt: Date
}
