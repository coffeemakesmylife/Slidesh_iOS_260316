//
//  TemplateModel.swift
//  Slidesh
//
//  模板数据模型、分类枚举、Mock 数据
//

import UIKit

// 布局模式（被 TemplateCell / FilterAndToggleBar / TemplatesViewController 共用）
enum LayoutMode {
    case grid
    case list
}

// 模板分类
enum TemplateCategory: String, CaseIterable {
    case all       = "全部场景"
    case report    = "总结汇报"
    case education = "教育培训"
    case medical   = "医学医疗"
    case other     = "其他"
}

// 模板风格
enum TemplateStyle: String, CaseIterable {
    case all        = "全部风格"
    case business   = "商务"
    case creative   = "创意"
    case minimalist = "简约"
    case tech       = "科技"
}

// 模板颜色主题
enum TemplateColor: String, CaseIterable {
    case all    = "全部颜色"
    case blue   = "蓝色"
    case red    = "红色"
    case green  = "绿色"
    case purple = "紫色"
    case orange = "橙色"
}

// 模板数据模型
struct TemplateModel {
    let id: String
    let name: String
    let description: String
    let category: TemplateCategory
    let style: TemplateStyle
    let color: TemplateColor
    /// 渐变颜色对，用于预览图占位渲染
    let gradientColors: [UIColor]
    let usageCount: Int
}

// MARK: - Mock 数据

extension TemplateModel {
    static let mockData: [TemplateModel] = [
        .init(id: "1", name: "季度总结报告", description: "适合企业季度业绩汇报，专业简洁",
              category: .report, style: .business, color: .blue,
              gradientColors: [UIColor(red: 0.039, green: 0.094, blue: 0.260, alpha: 1),
                               UIColor(red: 0.471, green: 0.710, blue: 0.953, alpha: 1)],
              usageCount: 3842),

        .init(id: "2", name: "项目进度汇报", description: "清晰展示里程碑与进度",
              category: .report, style: .business, color: .green,
              gradientColors: [UIColor(red: 0.05, green: 0.45, blue: 0.30, alpha: 1),
                               UIColor(red: 0.40, green: 0.85, blue: 0.60, alpha: 1)],
              usageCount: 2156),

        .init(id: "3", name: "课程教学课件", description: "生动活泼，适合课堂讲解",
              category: .education, style: .creative, color: .orange,
              gradientColors: [UIColor(red: 0.80, green: 0.35, blue: 0.05, alpha: 1),
                               UIColor(red: 0.98, green: 0.75, blue: 0.30, alpha: 1)],
              usageCount: 5621),

        .init(id: "4", name: "培训方案设计", description: "系统化培训内容结构",
              category: .education, style: .minimalist, color: .purple,
              gradientColors: [UIColor(red: 0.35, green: 0.10, blue: 0.70, alpha: 1),
                               UIColor(red: 0.75, green: 0.50, blue: 0.98, alpha: 1)],
              usageCount: 1890),

        .init(id: "5", name: "临床病例分析", description: "规范医疗数据展示格式",
              category: .medical, style: .business, color: .blue,
              gradientColors: [UIColor(red: 0.10, green: 0.30, blue: 0.70, alpha: 1),
                               UIColor(red: 0.40, green: 0.70, blue: 0.95, alpha: 1)],
              usageCount: 987),

        .init(id: "6", name: "科技产品发布", description: "未来感十足，科技感强",
              category: .other, style: .tech, color: .blue,
              gradientColors: [UIColor(red: 0.02, green: 0.02, blue: 0.15, alpha: 1),
                               UIColor(red: 0.10, green: 0.60, blue: 0.90, alpha: 1)],
              usageCount: 4320),

        .init(id: "7", name: "年度工作总结", description: "全面回顾年度成果与规划",
              category: .report, style: .business, color: .red,
              gradientColors: [UIColor(red: 0.65, green: 0.10, blue: 0.10, alpha: 1),
                               UIColor(red: 0.98, green: 0.45, blue: 0.45, alpha: 1)],
              usageCount: 6102),

        .init(id: "8", name: "创意头脑风暴", description: "激发创意，碰撞想法",
              category: .other, style: .creative, color: .orange,
              gradientColors: [UIColor(red: 0.85, green: 0.42, blue: 0.02, alpha: 1),
                               UIColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1)],
              usageCount: 2780),

        .init(id: "9", name: "医疗健康科普", description: "通俗易懂的医学知识传播",
              category: .medical, style: .creative, color: .green,
              gradientColors: [UIColor(red: 0.05, green: 0.55, blue: 0.40, alpha: 1),
                               UIColor(red: 0.30, green: 0.90, blue: 0.65, alpha: 1)],
              usageCount: 1543),

        .init(id: "10", name: "极简商务报告", description: "少即是多，留白设计哲学",
              category: .report, style: .minimalist, color: .purple,
              gradientColors: [UIColor(red: 0.28, green: 0.08, blue: 0.55, alpha: 1),
                               UIColor(red: 0.65, green: 0.45, blue: 0.92, alpha: 1)],
              usageCount: 3310),
    ]
}
