//
//  ParamsPickerViewController.swift
//  Slidesh
//
//  参数选择面板：篇幅长度、语言、场景、受众，配合 UISheetPresentationController medium detent 使用
//

import UIKit

class ParamsPickerViewController: UIViewController {

    // MARK: - 数据类型

    struct LengthOption {
        let display: String
        let detail:  String
        let value:   String
    }

    struct LanguageOption {
        let display: String
        let value:   String
    }

    // MARK: - 静态数据

    static let lengths: [LengthOption] = [
        .init(display: NSLocalizedString("短篇", comment: ""), detail: NSLocalizedString("10-15页", comment: ""), value: "short"),
        .init(display: NSLocalizedString("中篇", comment: ""), detail: NSLocalizedString("20-30页", comment: ""), value: "medium"),
        .init(display: NSLocalizedString("长篇", comment: ""), detail: NSLocalizedString("25-35页", comment: ""), value: "long"),
    ]

    static let languages: [LanguageOption] = [
        .init(display: NSLocalizedString("中文（简体）", comment: ""), value: "zh"),
        .init(display: NSLocalizedString("中文（繁體）", comment: ""), value: "zh-Hant"),
        .init(display: "English",      value: "en"),
        .init(display: "日本語",        value: "ja"),
        .init(display: "한국어",        value: "ko"),
        .init(display: "العربية",      value: "ar"),
        .init(display: "Deutsch",      value: "de"),
        .init(display: "Français",     value: "fr"),
        .init(display: "Italiano",     value: "it"),
        .init(display: "Português",    value: "pt"),
        .init(display: "Español",      value: "es"),
        .init(display: "Русский",      value: "ru"),
    ]

    static let scenes: [String] = [
        NSLocalizedString("通用", comment: ""), NSLocalizedString("分析报告", comment: ""), NSLocalizedString("教学课件", comment: ""),
        NSLocalizedString("宣传材料", comment: ""), NSLocalizedString("公众演讲", comment: ""), NSLocalizedString("在线媒体", comment: ""),
        NSLocalizedString("公告", comment: ""), NSLocalizedString("研究报告", comment: ""), NSLocalizedString("学术会议", comment: ""),
        NSLocalizedString("项目汇报", comment: ""), NSLocalizedString("个人介绍", comment: ""), NSLocalizedString("商业计划书", comment: ""),
        NSLocalizedString("解决方案", comment: ""), NSLocalizedString("产品介绍", comment: ""), NSLocalizedString("会议流程", comment: ""),
        NSLocalizedString("年度计划", comment: ""), NSLocalizedString("年度总结", comment: ""), NSLocalizedString("健康科普", comment: ""),
        NSLocalizedString("财务报告", comment: ""), NSLocalizedString("项目计划书", comment: ""), NSLocalizedString("商业博文", comment: ""),
    ]

    static let audiences: [String] = [
        NSLocalizedString("大众", comment: ""), NSLocalizedString("投资者", comment: ""), NSLocalizedString("商业", comment: ""),
        NSLocalizedString("学生", comment: ""), NSLocalizedString("教师", comment: ""), NSLocalizedString("老板", comment: ""),
        NSLocalizedString("面试官", comment: ""), NSLocalizedString("员工", comment: ""), NSLocalizedString("同事同行", comment: ""),
        NSLocalizedString("在线访客", comment: ""), NSLocalizedString("组员", comment: ""),
    ]

    // MARK: - 选择结果

    struct Selection {
        var lengthIndex:   Int    = 1   // 默认中篇
        var languageIndex: Int    = 0   // 默认中文简体
        var sceneIndex:    Int    = 0   // 默认通用
        var audienceIndex: Int    = 0   // 默认大众
        var customScene:   String = ""
        var customAudience:String = ""

        var length:   LengthOption   { ParamsPickerViewController.lengths[lengthIndex] }
        var language: LanguageOption { ParamsPickerViewController.languages[languageIndex] }

        // 若选中"自定义"（index == 数组末尾之后），返回自定义文本
        var scene: String {
            let s = ParamsPickerViewController.scenes
            return sceneIndex < s.count ? s[sceneIndex] : customScene
        }
        var audience: String {
            let a = ParamsPickerViewController.audiences
            return audienceIndex < a.count ? a[audienceIndex] : customAudience
        }
    }

    var onConfirm: ((Selection) -> Void)?
    private var selection: Selection

    // MARK: - 子视图

    private var sectionCollections: [UICollectionView] = []
    // tag → 自定义输入框（仅 tag 2/3 有）
    private var customTextFields: [Int: UITextField] = [:]
    private var contentScrollView: UIScrollView!

    private struct SectionMeta {
        let title:         String
        let options:       [String]
        let columns:       Int
        let supportsCustom: Bool
    }

    private lazy var sections: [SectionMeta] = [
        SectionMeta(title: NSLocalizedString("篇幅长度", comment: ""),
                    options: Self.lengths.map { "\($0.display)  \($0.detail)" },
                    columns: 1, supportsCustom: false),
        SectionMeta(title: NSLocalizedString("语言", comment: ""),
                    options: Self.languages.map { $0.display },
                    columns: 3, supportsCustom: false),
        SectionMeta(title: NSLocalizedString("场景", comment: ""),
                    options: Self.scenes + [NSLocalizedString("自定义", comment: "")],
                    columns: 3, supportsCustom: true),
        SectionMeta(title: NSLocalizedString("受众", comment: ""),
                    options: Self.audiences + [NSLocalizedString("自定义", comment: "")],
                    columns: 3, supportsCustom: true),
    ]

    // MARK: - Init

    init(selection: Selection) {
        self.selection = selection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildContent()

        // 恢复自定义选中状态
        if selection.sceneIndex >= Self.scenes.count {
            toggleCustomField(tag: 2, show: true, animated: false)
        }
        if selection.audienceIndex >= Self.audiences.count {
            toggleCustomField(tag: 3, show: true, animated: false)
        }

        // 键盘监听：输入框上移
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed { onConfirm?(selection) }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 内容布局

    private func buildContent() {
        let titleLabel = UILabel()
        titleLabel.text      = NSLocalizedString("参数设置", comment: "")
        titleLabel.font      = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle(NSLocalizedString("完成", comment: ""), for: .normal)
        doneBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        doneBtn.tintColor = .appPrimary
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(doneBtn)

        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentScrollView = scrollView
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)

        let contentStack = UIStackView()
        contentStack.axis    = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        for (idx, meta) in sections.enumerated() {
            contentStack.addArrangedSubview(buildSection(meta: meta, tag: idx))
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            doneBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    private func buildSection(meta: SectionMeta, tag: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text      = meta.title
        header.font      = .systemFont(ofSize: 13, weight: .medium)
        header.textColor = .appTextSecondary
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let layout = makeSectionLayout(columns: meta.columns)
        let cv     = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.register(InlineChipCell.self, forCellWithReuseIdentifier: InlineChipCell.reuseID)
        cv.dataSource = self
        cv.delegate   = self
        cv.tag        = tag
        cv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cv)
        sectionCollections.append(cv)

        let rows    = Int(ceil(Double(meta.options.count) / Double(meta.columns)))
        let chipH:  CGFloat = 40
        let rowGap: CGFloat = 8
        let cvH = CGFloat(rows) * chipH + CGFloat(max(rows - 1, 0)) * rowGap

        if meta.supportsCustom {
            // 自定义输入框：初始高度 0，选中"自定义"后展开
            let tf = buildCustomTextField(placeholder: NSLocalizedString("请输入自定义内容...", comment: ""), tag: tag)
            tf.isHidden = true
            container.addSubview(tf)
            customTextFields[tag] = tf

            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: container.topAnchor),
                header.leadingAnchor.constraint(equalTo: container.leadingAnchor),

                cv.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
                cv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                cv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                cv.heightAnchor.constraint(equalToConstant: cvH),

                tf.topAnchor.constraint(equalTo: cv.bottomAnchor, constant: 8),
                tf.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                tf.heightAnchor.constraint(equalToConstant: 44),
                tf.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: container.topAnchor),
                header.leadingAnchor.constraint(equalTo: container.leadingAnchor),

                cv.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
                cv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                cv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                cv.heightAnchor.constraint(equalToConstant: cvH),
                cv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        return container
    }

    private func buildCustomTextField(placeholder: String, tag: Int) -> UITextField {
        let tf = UITextField()
        tf.placeholder            = placeholder
        tf.font                   = .systemFont(ofSize: 14)
        tf.textColor              = .appTextPrimary
        tf.backgroundColor        = .appBackgroundTertiary
        tf.layer.cornerRadius     = 10
        tf.layer.borderWidth      = 1
        tf.layer.borderColor      = UIColor.appSeparator.cgColor
        tf.leftView               = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        tf.leftViewMode           = .always
        tf.rightView              = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        tf.rightViewMode          = .always
        tf.returnKeyType          = .done
        tf.tag                    = tag
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.addTarget(self, action: #selector(customTextChanged(_:)), for: .editingChanged)
        tf.delegate               = self
        return tf
    }

    private func makeSectionLayout(columns: Int) -> UICollectionViewLayout {
        let fraction  = 1.0 / CGFloat(columns)
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction),
                                               heightDimension: .absolute(40))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .absolute(40))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section   = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - 自定义输入框 展开/收起

    private func toggleCustomField(tag: Int, show: Bool, animated: Bool = true) {
        guard let tf = customTextFields[tag] else { return }

        let duration = animated ? 0.25 : 0.0

        if show {
            tf.alpha    = 0
            tf.isHidden = false
            UIView.animate(withDuration: duration) {
                tf.alpha = 1
                self.view.layoutIfNeeded()
            }
            tf.becomeFirstResponder()
        } else {
            UIView.animate(withDuration: animated ? 0.2 : 0.0,
                           animations: { tf.alpha = 0 },
                           completion: { _ in tf.isHidden = true })
            tf.resignFirstResponder()
        }
    }

    // MARK: - 键盘处理

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info     = notification.userInfo,
              let kbValue  = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        // 键盘高度（相对于 scrollView 所在的 window 坐标系）
        let kbFrame = kbValue.cgRectValue
        let kbHeight = kbFrame.height

        // 增大 scrollView 底部 inset，使内容可滚动到键盘上方
        contentScrollView.contentInset.bottom = kbHeight
        contentScrollView.scrollIndicatorInsets.bottom = kbHeight

        // 找到当前第一响应者（自定义输入框），滚动使其可见
        let activeTF = customTextFields.values.first { $0.isFirstResponder }
        if let tf = activeTF {
            let tfFrame = contentScrollView.convert(tf.frame, from: tf.superview)
            let visibleRect = CGRect(x: 0, y: 0,
                                     width: contentScrollView.bounds.width,
                                     height: contentScrollView.bounds.height - kbHeight)
            if !visibleRect.contains(tfFrame) {
                UIView.animate(withDuration: duration, delay: 0,
                               options: UIView.AnimationOptions(rawValue: curve << 16)) {
                    self.contentScrollView.scrollRectToVisible(tfFrame, animated: false)
                }
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info     = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.contentScrollView.contentInset.bottom = 0
            self.contentScrollView.scrollIndicatorInsets.bottom = 0
        }
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func customTextChanged(_ tf: UITextField) {
        let text = tf.text ?? ""
        if tf.tag == 2 { selection.customScene    = text }
        if tf.tag == 3 { selection.customAudience = text }
    }

    private func selectedIndex(for tag: Int) -> Int {
        switch tag {
        case 0: return selection.lengthIndex
        case 1: return selection.languageIndex
        case 2: return selection.sceneIndex
        case 3: return selection.audienceIndex
        default: return 0
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension ParamsPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        sections[collectionView.tag].options.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: InlineChipCell.reuseID, for: indexPath) as! InlineChipCell
        let meta     = sections[collectionView.tag]
        let option   = meta.options[indexPath.item]
        let selected = indexPath.item == selectedIndex(for: collectionView.tag)
        // "自定义"使用虚线边框样式区分
        let isCustomChip = meta.supportsCustom && indexPath.item == meta.options.count - 1
        cell.configure(title: option, selected: selected, isCustomChip: isCustomChip)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let meta     = sections[collectionView.tag]
        let isCustom = meta.supportsCustom && indexPath.item == meta.options.count - 1

        // 选中非自定义 chip 时收起键盘
        if !isCustom { view.endEditing(true) }

        switch collectionView.tag {
        case 0: selection.lengthIndex   = indexPath.item
        case 1: selection.languageIndex = indexPath.item
        case 2:
            selection.sceneIndex = indexPath.item
            toggleCustomField(tag: 2, show: isCustom)
        case 3:
            selection.audienceIndex = indexPath.item
            toggleCustomField(tag: 3, show: isCustom)
        default: break
        }
        collectionView.reloadData()
    }
}

// MARK: - UITextFieldDelegate

extension ParamsPickerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - InlineChipCell

private class InlineChipCell: UICollectionViewCell {

    static let reuseID = "InlineChipCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds      = true

        label.font          = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -4),
        ])
    }

    func configure(title: String, selected: Bool, isCustomChip: Bool = false) {
        label.text = title
        // 选中：主色低透明度背景 + 主色文字；未选中：三级背景 + 一级文字
        contentView.backgroundColor = selected ? .appPrimarySubtle : .appBackgroundTertiary
        label.textColor             = selected ? .appPrimary : .appTextPrimary
        contentView.layer.borderWidth = 0
    }
}
