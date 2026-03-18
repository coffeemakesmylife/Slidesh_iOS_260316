//
//  InspirationPickerViewController.swift
//  Slidesh
//
//  行业灵感选择器：展示行业分类网格，选中后返回对应的 3 条主题建议
//

import UIKit

// MARK: - 数据模型

struct InspirationCategory {
    let name:   String
    let symbol: String    // SF Symbol 名称
    let topics: [String]  // 3 条主题建议
}

// MARK: - InspirationPickerViewController

class InspirationPickerViewController: UIViewController {

    // MARK: - 行业数据（15 个主流行业，每个 3 条主题）

    static let categories: [InspirationCategory] = [
        .init(name: "科技",     symbol: "cpu",                   topics: [
            "人工智能驱动的企业数字化转型实践",
            "2025 年云计算市场发展趋势分析",
            "大数据与智能决策：从数据到价值"
        ]),
        .init(name: "教育",     symbol: "book.fill",             topics: [
            "在线教育平台用户增长与留存策略",
            "项目制学习在 K12 教育中的落地实践",
            "职业技能培训体系建设全面方案"
        ]),
        .init(name: "医疗",     symbol: "stethoscope",           topics: [
            "互联网医疗发展现状与未来机遇",
            "慢性病数字化管理解决方案",
            "医院智慧服务体系建设与规划"
        ]),
        .init(name: "金融",     symbol: "chart.bar.fill",        topics: [
            "Q3 季度财务业绩分析与展望",
            "数字金融创新产品与风险防控",
            "ESG 投资理念与企业可持续发展"
        ]),
        .init(name: "商业",     symbol: "briefcase.fill",        topics: [
            "新消费品牌市场破局策略与路径",
            "企业并购整合全流程方案",
            "年度运营复盘与战略规划报告"
        ]),
        .init(name: "营销",     symbol: "megaphone.fill",        topics: [
            "品牌年度营销策略与预算规划",
            "私域流量运营与用户留存方法论",
            "短视频内容营销效果提升方案"
        ]),
        .init(name: "人力资源", symbol: "person.3.fill",         topics: [
            "新员工入职培训体系建设方案",
            "绩效管理体系优化与落地实践",
            "人才梯队建设与接班人计划"
        ]),
        .init(name: "法律",     symbol: "building.columns.fill", topics: [
            "企业合规管理体系建设指南",
            "数据安全与个人信息保护合规实务",
            "劳动法律风险防控培训"
        ]),
        .init(name: "制造",     symbol: "gearshape.2.fill",      topics: [
            "智能制造工厂转型升级路径",
            "供应链韧性建设与精益管理实践",
            "工业 4.0 背景下的生产效率提升"
        ]),
        .init(name: "房地产",   symbol: "house.fill",            topics: [
            "城市更新项目可行性分析报告",
            "商业地产运营与招商策略",
            "物业管理服务品质提升方案"
        ]),
        .init(name: "餐饮",     symbol: "fork.knife",            topics: [
            "连锁餐饮品牌标准化运营手册",
            "餐饮新零售模式与供应链优化",
            "餐厅会员体系搭建与用户运营"
        ]),
        .init(name: "零售",     symbol: "bag.fill",              topics: [
            "全渠道零售数字化转型路径",
            "门店选址分析与商圈评估方法",
            "零售商品陈列优化与销售提升"
        ]),
        .init(name: "创意文化", symbol: "paintbrush.fill",       topics: [
            "文化 IP 开发与商业化运营策略",
            "创意产业园区规划与招商方案",
            "品牌视觉升级与设计系统建设"
        ]),
        .init(name: "环保能源", symbol: "leaf.fill",             topics: [
            "碳中和目标下的企业减排路径",
            "新能源产业链投资机会分析",
            "绿色建筑节能改造与认证方案"
        ]),
        .init(name: "政务",     symbol: "flag.fill",             topics: [
            "智慧城市建设规划与实施路径",
            "政务数字化服务能力提升方案",
            "公共卫生应急体系建设研究"
        ]),
    ]

    // MARK: - 回调（返回完整分类，包含名称和主题）

    var onSelect: ((InspirationCategory) -> Void)?

    // MARK: - 子视图

    private var collectionView: UICollectionView!

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackgroundSecondary
        buildContent()
    }

    // MARK: - 布局

    private func buildContent() {
        let titleLabel = UILabel()
        titleLabel.text      = "主题灵感"
        titleLabel.font      = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let subLabel = UILabel()
        subLabel.text      = "选择行业，获取主题建议"
        subLabel.font      = .systemFont(ofSize: 13)
        subLabel.textColor = .appTextSecondary
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subLabel)

        // 3 列网格布局
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / 3.0),
                                                  heightDimension: .absolute(80))
            let item  = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                   heightDimension: .absolute(80))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 14, bottom: 20, trailing: 14)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(InspireCategoryCell.self, forCellWithReuseIdentifier: InspireCategoryCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            subLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            subLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension InspirationPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        Self.categories.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: InspireCategoryCell.reuseID, for: indexPath) as! InspireCategoryCell
        cell.configure(with: Self.categories[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let category = Self.categories[indexPath.item]
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(category)
        }
    }
}

// MARK: - InspireCategoryCell

private class InspireCategoryCell: UICollectionViewCell {

    static let reuseID = "InspireCategoryCell"

    private let iconView  = UIImageView()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.backgroundColor    = .appChipUnselectedBackground
        contentView.layer.cornerRadius = 14
        contentView.clipsToBounds      = true

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        iconView.preferredSymbolConfiguration = iconCfg
        iconView.tintColor   = .appPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font          = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor     = .appTextPrimary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            nameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -4),
        ])
    }

    func configure(with category: InspirationCategory) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        iconView.image = UIImage(systemName: category.symbol, withConfiguration: cfg)
        nameLabel.text = category.name
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.contentView.alpha     = self.isHighlighted ? 0.65 : 1.0
                self.contentView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
            }
        }
    }
}
