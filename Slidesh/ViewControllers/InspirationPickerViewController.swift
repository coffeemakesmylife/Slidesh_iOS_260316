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
    let color:  UIColor   // icon 颜色
}

// MARK: - InspirationPickerViewController

class InspirationPickerViewController: UIViewController {

    // MARK: - 行业数据（15 个主流行业，每个 3 条主题）

    static let categories: [InspirationCategory] = [
        .init(name: NSLocalizedString("科技", comment: ""),     symbol: "cpu",                   topics: [
            NSLocalizedString("人工智能驱动的企业数字化转型实践", comment: ""),
            NSLocalizedString("2025 年云计算市场发展趋势分析", comment: ""),
            NSLocalizedString("大数据与智能决策：从数据到价值", comment: "")
        ], color: UIColor(red: 0.20, green: 0.55, blue: 1.00, alpha: 1)),   // 蓝
        .init(name: NSLocalizedString("教育", comment: ""),     symbol: "book.fill",             topics: [
            NSLocalizedString("在线教育平台用户增长与留存策略", comment: ""),
            NSLocalizedString("项目制学习在 K12 教育中的落地实践", comment: ""),
            NSLocalizedString("职业技能培训体系建设全面方案", comment: "")
        ], color: UIColor(red: 1.00, green: 0.60, blue: 0.10, alpha: 1)),   // 橙
        .init(name: NSLocalizedString("医疗", comment: ""),     symbol: "stethoscope",           topics: [
            NSLocalizedString("互联网医疗发展现状与未来机遇", comment: ""),
            NSLocalizedString("慢性病数字化管理解决方案", comment: ""),
            NSLocalizedString("医院智慧服务体系建设与规划", comment: "")
        ], color: UIColor(red: 0.95, green: 0.27, blue: 0.35, alpha: 1)),   // 红
        .init(name: NSLocalizedString("金融", comment: ""),     symbol: "chart.bar.fill",        topics: [
            NSLocalizedString("Q3 季度财务业绩分析与展望", comment: ""),
            NSLocalizedString("数字金融创新产品与风险防控", comment: ""),
            NSLocalizedString("ESG 投资理念与企业可持续发展", comment: "")
        ], color: UIColor(red: 0.20, green: 0.78, blue: 0.55, alpha: 1)),   // 绿
        .init(name: NSLocalizedString("商业", comment: ""),     symbol: "briefcase.fill",        topics: [
            NSLocalizedString("新消费品牌市场破局策略与路径", comment: ""),
            NSLocalizedString("企业并购整合全流程方案", comment: ""),
            NSLocalizedString("年度运营复盘与战略规划报告", comment: "")
        ], color: UIColor(red: 0.55, green: 0.38, blue: 1.00, alpha: 1)),   // 紫
        .init(name: NSLocalizedString("营销", comment: ""),     symbol: "megaphone.fill",        topics: [
            NSLocalizedString("品牌年度营销策略与预算规划", comment: ""),
            NSLocalizedString("私域流量运营与用户留存方法论", comment: ""),
            NSLocalizedString("短视频内容营销效果提升方案", comment: "")
        ], color: UIColor(red: 1.00, green: 0.22, blue: 0.60, alpha: 1)),   // 粉
        .init(name: NSLocalizedString("人力资源", comment: ""), symbol: "person.3.fill",         topics: [
            NSLocalizedString("新员工入职培训体系建设方案", comment: ""),
            NSLocalizedString("绩效管理体系优化与落地实践", comment: ""),
            NSLocalizedString("人才梯队建设与接班人计划", comment: "")
        ], color: UIColor(red: 0.00, green: 0.72, blue: 0.83, alpha: 1)),   // 青
        .init(name: NSLocalizedString("法律", comment: ""),     symbol: "building.columns.fill", topics: [
            NSLocalizedString("企业合规管理体系建设指南", comment: ""),
            NSLocalizedString("数据安全与个人信息保护合规实务", comment: ""),
            NSLocalizedString("劳动法律风险防控培训", comment: "")
        ], color: UIColor(red: 0.48, green: 0.48, blue: 0.55, alpha: 1)),   // 灰蓝
        .init(name: NSLocalizedString("制造", comment: ""),     symbol: "gearshape.2.fill",      topics: [
            NSLocalizedString("智能制造工厂转型升级路径", comment: ""),
            NSLocalizedString("供应链韧性建设与精益管理实践", comment: ""),
            NSLocalizedString("工业 4.0 背景下的生产效率提升", comment: "")
        ], color: UIColor(red: 0.70, green: 0.45, blue: 0.20, alpha: 1)),   // 棕
        .init(name: NSLocalizedString("房地产", comment: ""),   symbol: "house.fill",            topics: [
            NSLocalizedString("城市更新项目可行性分析报告", comment: ""),
            NSLocalizedString("商业地产运营与招商策略", comment: ""),
            NSLocalizedString("物业管理服务品质提升方案", comment: "")
        ], color: UIColor(red: 0.98, green: 0.75, blue: 0.10, alpha: 1)),   // 金
        .init(name: NSLocalizedString("餐饮", comment: ""),     symbol: "fork.knife",            topics: [
            NSLocalizedString("连锁餐饮品牌标准化运营手册", comment: ""),
            NSLocalizedString("餐饮新零售模式与供应链优化", comment: ""),
            NSLocalizedString("餐厅会员体系搭建与用户运营", comment: "")
        ], color: UIColor(red: 1.00, green: 0.42, blue: 0.20, alpha: 1)),   // 橘红
        .init(name: NSLocalizedString("零售", comment: ""),     symbol: "bag.fill",              topics: [
            NSLocalizedString("全渠道零售数字化转型路径", comment: ""),
            NSLocalizedString("门店选址分析与商圈评估方法", comment: ""),
            NSLocalizedString("零售商品陈列优化与销售提升", comment: "")
        ], color: UIColor(red: 0.10, green: 0.65, blue: 0.42, alpha: 1)),   // 深绿
        .init(name: NSLocalizedString("创意文化", comment: ""), symbol: "paintbrush.fill",       topics: [
            NSLocalizedString("文化 IP 开发与商业化运营策略", comment: ""),
            NSLocalizedString("创意产业园区规划与招商方案", comment: ""),
            NSLocalizedString("品牌视觉升级与设计系统建设", comment: "")
        ], color: UIColor(red: 0.85, green: 0.25, blue: 0.85, alpha: 1)),   // 洋红
        .init(name: NSLocalizedString("环保能源", comment: ""), symbol: "leaf.fill",             topics: [
            NSLocalizedString("碳中和目标下的企业减排路径", comment: ""),
            NSLocalizedString("新能源产业链投资机会分析", comment: ""),
            NSLocalizedString("绿色建筑节能改造与认证方案", comment: "")
        ], color: UIColor(red: 0.25, green: 0.80, blue: 0.30, alpha: 1)),   // 草绿
        .init(name: NSLocalizedString("政务", comment: ""),     symbol: "flag.fill",             topics: [
            NSLocalizedString("智慧城市建设规划与实施路径", comment: ""),
            NSLocalizedString("政务数字化服务能力提升方案", comment: ""),
            NSLocalizedString("公共卫生应急体系建设研究", comment: "")
        ], color: UIColor(red: 0.15, green: 0.40, blue: 0.80, alpha: 1)),   // 深蓝
    ]

    // MARK: - 回调（返回完整分类，包含名称和主题）

    var onSelect: ((InspirationCategory) -> Void)?

    // MARK: - 子视图

    private var collectionView: UICollectionView!

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildContent()
    }

    // MARK: - 布局

    private func buildContent() {
        let titleLabel = UILabel()
        titleLabel.text      = NSLocalizedString("主题灵感", comment: "")
        titleLabel.font      = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let subLabel = UILabel()
        subLabel.text      = NSLocalizedString("选择行业，获取主题建议", comment: "")
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
        contentView.backgroundColor    = .appBackgroundTertiary
        contentView.layer.cornerRadius = 14
        contentView.clipsToBounds      = true

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        iconView.preferredSymbolConfiguration = iconCfg
        iconView.tintColor   = .appPrimary  // configure() 会覆盖为分类专属颜色
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
        iconView.image     = UIImage(systemName: category.symbol, withConfiguration: cfg)
        iconView.tintColor = category.color
        nameLabel.text     = category.name
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                // 高亮时切换为主色低透明度背景，恢复时回到三级背景
                self.contentView.backgroundColor = self.isHighlighted
                    ? .appPrimarySubtle : .appBackgroundTertiary
                self.contentView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
            }
        }
    }
}
