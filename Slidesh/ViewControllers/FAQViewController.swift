//
//  FAQViewController.swift
//  Slidesh
//

import UIKit

class FAQViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()

    private let items: [(question: String, answer: String)] = [
        ("如何创建新的演示文稿？",
         "点击底部中间的「+」按钮，选择模板或从空白开始，即可快速创建一份新的演示文稿。"),
        ("支持哪些格式导出？",
         "目前支持导出为 PDF、PPT（PowerPoint）、PNG 图片序列。Pro 会员可解锁更多格式选项。"),
        ("如何导入已有文件？",
         "在首页点击右上角「导入」按钮，支持从文件 App、iCloud Drive 导入 PDF 或 PPT 文件。"),
        ("会员有哪些特权？",
         "Pro 会员可无限制导出、解锁全部精选模板、使用高级格式转换功能，以及优先获得新功能体验资格。"),
        ("如何取消订阅？",
         "前往「设置」→「Apple ID」→「订阅」，找到 \(AppConfig.appName) 后点击取消即可。取消后当前周期内仍可使用会员功能。"),
        ("数据会保存在哪里？",
         "作品默认保存在本地设备，同时支持 iCloud 备份。开启 iCloud 后，在其他设备上也能访问您的作品。"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "FAQ"
        addMeshGradientBackground()
        setupScrollView()
        buildItems()
    }

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .always
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    private func buildItems() {
        for (i, item) in items.enumerated() {
            let cell = FAQCell(question: item.question, answer: item.answer, index: i)
            stackView.addArrangedSubview(cell)
        }
    }
}

// MARK: - FAQ 可折叠卡片

private class FAQCell: UIView {

    private let questionLabel = UILabel()
    private let answerLabel   = UILabel()
    private let chevron       = UIImageView()
    private var isExpanded    = false
    private var answerHeightConstraint: NSLayoutConstraint!

    init(question: String, answer: String, index: Int) {
        super.init(frame: .zero)
        backgroundColor = .appCardBackground.withAlphaComponent(0.65)
        layer.cornerRadius = 18
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6

        questionLabel.text = question
        questionLabel.font = .systemFont(ofSize: 15, weight: .medium)
        questionLabel.textColor = .appTextPrimary
        questionLabel.numberOfLines = 0

        answerLabel.text = answer
        answerLabel.font = .systemFont(ofSize: 14)
        answerLabel.textColor = .appTextSecondary
        answerLabel.numberOfLines = 0
        answerLabel.alpha = 0

        chevron.image = UIImage(systemName: "chevron.down")
        chevron.tintColor = .appTextTertiary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevron.contentMode = .scaleAspectFit

        [questionLabel, answerLabel, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        answerHeightConstraint = answerLabel.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            questionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            questionLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            chevron.centerYAnchor.constraint(equalTo: questionLabel.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.widthAnchor.constraint(equalToConstant: 20),
            chevron.heightAnchor.constraint(equalToConstant: 20),

            answerLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 0),
            answerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            answerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            answerHeightConstraint,
            answerLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggle))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func toggle() {
        isExpanded.toggle()
        // 展开时移除高度约束，折叠时归零
        answerHeightConstraint.isActive = !isExpanded

        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseInOut) {
            self.answerLabel.alpha = self.isExpanded ? 1 : 0
            // 顶部间距
            if let topConstraint = self.answerLabel.constraints.first(where: {
                $0.firstAttribute == .top && $0.secondItem === self.questionLabel
            }) {
                topConstraint.constant = self.isExpanded ? 10 : 0
            }
            self.chevron.transform = self.isExpanded
                ? CGAffineTransform(rotationAngle: .pi)
                : .identity
            // 触发父层级重新布局
            self.superview?.layoutIfNeeded()
        }
    }
}
