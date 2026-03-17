//
//  TemplateModel.swift
//  Slidesh
//
//  AIPPT 真实数据模型
//

import Foundation

// 布局模式（被 TemplateCell / FilterAndToggleBar / TemplatesViewController 共用）
enum LayoutMode {
    case grid
    case list
}

// MARK: - API 数据模型

/// AIPPT 模板（来自 /v1/api/ai/ppt/templates 接口）
struct PPTTemplate {
    let id: String
    let type: Int
    let coverUrl: String
    let category: String
    let style: String
    let themeColor: String
    let subject: String
    let num: Int
    let createTime: String

    /// 封面图片完整 URL（需拼接 token 才能访问）
    var coverImageURL: URL? {
        URL(string: coverUrl)
    }
}

/// 筛选选项（来自 /v1/api/ai/ppt/templates-options 接口）
struct PPTOption {
    let name: String    // 显示名称
    let type: String    // category / style / themeColor
    let value: String   // 传给 API 的筛选值
}

// MARK: - 缓存序列化辅助（供 TemplateCache 磁盘存取使用）

extension PPTTemplate {
    /// 从字典还原模型（字段与 API 响应一致）
    init?(dictionary: [String: Any]) {
        guard let id       = dictionary["id"]       as? String,
              let coverUrl = dictionary["coverUrl"]  as? String,
              let subject  = dictionary["subject"]   as? String
        else { return nil }
        self.id         = id
        self.type       = dictionary["type"]       as? Int    ?? 1
        self.coverUrl   = coverUrl
        self.category   = dictionary["category"]   as? String ?? ""
        self.style      = dictionary["style"]      as? String ?? ""
        self.themeColor = dictionary["themeColor"] as? String ?? ""
        self.subject    = subject
        self.num        = dictionary["num"]        as? Int    ?? 0
        self.createTime = dictionary["createTime"] as? String ?? ""
    }

    /// 序列化为字典（JSONSerialization 兼容）
    var asDictionary: [String: Any] {
        [
            "id":         id,
            "type":       type,
            "coverUrl":   coverUrl,
            "category":   category,
            "style":      style,
            "themeColor": themeColor,
            "subject":    subject,
            "num":        num,
            "createTime": createTime,
        ]
    }
}
