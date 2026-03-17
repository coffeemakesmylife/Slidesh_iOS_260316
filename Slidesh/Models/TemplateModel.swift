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
        URL(string: coverUrl + "?token=6744651694")
    }
}

/// 筛选选项（来自 /v1/api/ai/ppt/templates-options 接口）
struct PPTOption {
    let name: String    // 显示名称
    let type: String    // category / style / themeColor
    let value: String   // 传给 API 的筛选值
}
