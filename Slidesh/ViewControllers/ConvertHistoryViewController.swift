//
//  ConvertHistoryViewController.swift
//  Slidesh
//
//  格式转换记录列表：支持点击预览、左滑删除
//

import UIKit
import QuickLook
import SafariServices

// MARK: - ConvertHistoryViewController

final class ConvertHistoryViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)

    // 按日期分组，每组 (dateKey: "yyyy-MM-dd", records: 当天记录按时间倒序)
    private var sections: [(dateKey: String, records: [ConvertRecord])] = []

    // QLPreviewController 数据源缓存
    private var previewURLs: [URL] = []

    // 日期分组键（section header 用）
    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    // cell 内时间显示
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "转换记录"
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()
        setupTableView()
        setupEmptyState()
        loadRecords()

        NotificationCenter.default.addObserver(
            self, selector: #selector(worksDidUpdate),
            name: .worksDidUpdate, object: nil)
    }

    // MARK: - 数据

    private func loadRecords() {
        sections = grouped(WorksStore.shared.converts)
        tableView.reloadData()
        updateEmptyState()
    }

    @objc private func worksDidUpdate() {
        sections = grouped(WorksStore.shared.converts)
        tableView.reloadData()
        updateEmptyState()
    }

    /// 将平铺记录按 yyyy-MM-dd 分组，组内按时间倒序，组间最新日期在前
    private func grouped(_ records: [ConvertRecord]) -> [(dateKey: String, records: [ConvertRecord])] {
        var dict: [String: [ConvertRecord]] = [:]
        for r in records {
            let key = Self.dateKeyFormatter.string(from: r.savedAt)
            dict[key, default: []].append(r)
        }
        return dict
            .map { (dateKey: $0.key, records: $0.value.sorted { $0.savedAt > $1.savedAt }) }
            .sorted { $0.dateKey > $1.dateKey }
    }

    // 取某 indexPath 对应的记录
    private func record(at indexPath: IndexPath) -> ConvertRecord {
        sections[indexPath.section].records[indexPath.row]
    }

    // MARK: - UI

    private func setupTableView() {
        tableView.backgroundColor    = .clear
        tableView.separatorStyle     = .none
        tableView.rowHeight          = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.sectionHeaderTopPadding = 0
        tableView.register(ConvertHistoryCell.self, forCellReuseIdentifier: ConvertHistoryCell.reuseID)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - 空状态

    private let emptyView = UIView()

    private func setupEmptyState() {
        let icon = UIImageView(image: UIImage(systemName: "clock.arrow.circlepath"))
        icon.tintColor   = .appTextSecondary.withAlphaComponent(0.4)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text          = "暂无转换记录"
        label.font          = .systemFont(ofSize: 16)
        label.textColor     = .appTextSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(icon)
        emptyView.addSubview(label)
        view.addSubview(emptyView)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: emptyView.topAnchor),
            icon.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 52),
            icon.heightAnchor.constraint(equalToConstant: 52),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor),

            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.widthAnchor.constraint(equalToConstant: 200),
        ])
    }

    private func updateEmptyState() {
        let isEmpty = sections.isEmpty
        emptyView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }

    // MARK: - 预览

    private func previewRecord(_ record: ConvertRecord) {
        if record.isRemoteResult {
            guard let urlStr = record.resultPaths.first,
                  let url = URL(string: urlStr) else {
                showExpiredAlert(); return
            }
            present(SFSafariViewController(url: url), animated: true)
        } else {
            let localURLs = record.resultPaths
                .map { resolveLocalPath($0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !localURLs.isEmpty else { showExpiredAlert(); return }
            previewURLs = localURLs
            let ql = QLPreviewController()
            ql.dataSource = self
            ql.currentPreviewItemIndex = 0
            present(ql, animated: true)
        }
    }

    private func resolveLocalPath(_ filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("convert_results")
            .appendingPathComponent(filename)
    }

    private func showExpiredAlert() {
        let alert = UIAlertController(title: "文件已失效", message: "转换结果已被清理，请重新转换", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 删除

    private func deleteRecord(at indexPath: IndexPath) {
        let rec = record(at: indexPath)
        if !rec.isRemoteResult {
            rec.resultPaths.forEach { try? FileManager.default.removeItem(at: resolveLocalPath($0)) }
        }
        WorksStore.shared.deleteConvert(id: rec.id)

        // 更新本地数据并做动画
        var sectionRecords = sections[indexPath.section].records
        sectionRecords.remove(at: indexPath.row)

        if sectionRecords.isEmpty {
            // 该天已无记录，删除整个 section
            sections.remove(at: indexPath.section)
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
        } else {
            sections[indexPath.section] = (sections[indexPath.section].dateKey, sectionRecords)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        updateEmptyState()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ConvertHistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].records.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConvertHistoryCell.reuseID, for: indexPath) as! ConvertHistoryCell
        cell.configure(with: record(at: indexPath), timeFormatter: Self.timeFormatter)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = .clear

        let bar = UIView()
        bar.backgroundColor    = .appPrimary
        bar.layer.cornerRadius = 2
        bar.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(bar)

        let label = UILabel()
        label.text      = sections[section].dateKey
        label.font      = .systemFont(ofSize: 18, weight: .heavy)
        label.textColor = .appTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            bar.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            bar.widthAnchor.constraint(equalToConstant: 4),
            bar.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 52 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        previewRecord(record(at: indexPath))
    }

    // 左滑删除
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let del = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            self?.deleteRecord(at: indexPath)
            done(true)
        }
        del.image = UIImage(systemName: "trash.fill")
        return UISwipeActionsConfiguration(actions: [del])
    }
}

// MARK: - QLPreviewControllerDataSource

extension ConvertHistoryViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewURLs.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURLs[index] as NSURL
    }
}

// MARK: - ConvertHistoryCell

private final class ConvertHistoryCell: UITableViewCell {
    static let reuseID = "ConvertHistoryCell"

    private let cardView    = UIView()
    private let iconBg      = UIView()
    private let iconView    = UIImageView()
    private let titleLabel  = UILabel()
    private let fileLabel   = UILabel()
    private let badgeView   = UIView()
    private let badgeLabel  = UILabel()
    private let dateLabel   = UILabel()
    private let chevron     = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none
        setupCard()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupCard() {
        cardView.backgroundColor    = .appCardBackground.withAlphaComponent(0.7)
        cardView.layer.cornerRadius = 24
        cardView.layer.borderWidth  = 1
        cardView.layer.borderColor  = UIColor.appCardBorder.cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        // 图标背景
        iconBg.layer.cornerRadius = 16
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconBg)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        // 工具名称
        titleLabel.font      = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // 输入文件名
        fileLabel.font          = .systemFont(ofSize: 12)
        fileLabel.textColor     = .appTextSecondary
        fileLabel.lineBreakMode = .byTruncatingMiddle
        fileLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(fileLabel)

        // 格式 badge
        badgeView.layer.cornerRadius = 6
        badgeView.clipsToBounds      = true
        badgeView.isHidden           = true
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(badgeView)

        badgeLabel.font      = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(badgeLabel)

        // 日期
        dateLabel.font      = .systemFont(ofSize: 11)
        dateLabel.textColor = .appTextSecondary
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(dateLabel)

        // 右箭头
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevron.image       = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevron.tintColor   = .appTextSecondary.withAlphaComponent(0.5)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(chevron)

        NSLayoutConstraint.activate([
            // 卡片
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            // 图标背景：左侧垂直居中
            iconBg.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconBg.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            iconBg.widthAnchor.constraint(equalToConstant: 44),
            iconBg.heightAnchor.constraint(equalToConstant: 44),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            // 右箭头
            chevron.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevron.widthAnchor.constraint(equalToConstant: 12),

            // 工具名称：图标右侧，日期右对齐
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),

            // 日期：右上角
            dateLabel.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            // 文件名 + badge
            fileLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            fileLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            fileLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            // badge 紧跟文件名右侧
            badgeView.centerYAnchor.constraint(equalTo: fileLabel.centerYAnchor),
            badgeView.leadingAnchor.constraint(equalTo: fileLabel.trailingAnchor, constant: 6),
            badgeView.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            badgeView.heightAnchor.constraint(equalToConstant: 18),

            badgeLabel.topAnchor.constraint(equalTo: badgeView.topAnchor),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 6),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -6),
        ])
    }

    func configure(with record: ConvertRecord, timeFormatter: DateFormatter) {
        // 图标和颜色均来自输出格式
        let (iconName, color) = outputIconInfo(toolKind: record.toolKind, outputFormat: record.outputFormat)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconBg.backgroundColor = color.withAlphaComponent(0.15)
        iconView.image     = UIImage(systemName: iconName, withConfiguration: config)
        iconView.tintColor = color

        titleLabel.text = record.toolTitle
        fileLabel.text  = record.inputFileName
        dateLabel.text  = timeFormatter.string(from: record.savedAt)

        // badge 显示输出格式，颜色与图标一致
        let effectiveFormat = effectiveOutputFormat(toolKind: record.toolKind, outputFormat: record.outputFormat)
        if !effectiveFormat.isEmpty {
            badgeLabel.text           = effectiveFormat
            badgeLabel.textColor      = color
            badgeView.backgroundColor = color.withAlphaComponent(0.12)
            badgeView.isHidden        = false
        } else {
            badgeView.isHidden = true
        }
    }

    // 主题切换时更新 CALayer border
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        cardView.layer.borderColor = UIColor.appCardBorder.cgColor
    }

    // 根据工具类型和输出格式推导有效的输出格式字符串（用于 badge 文字）
    private func effectiveOutputFormat(toolKind: String, outputFormat: String?) -> String {
        switch toolKind {
        case "pdfToWord":   return "WORD"
        case "mergePDF":    return "PDF"
        case "fileToImage": return "PNG"
        default:            return outputFormat?.uppercased() ?? ""
        }
    }

    // 根据输出格式返回对应图标和颜色（与 FormatPickerSheet 保持一致）
    private func outputIconInfo(toolKind: String, outputFormat: String?) -> (String, UIColor) {
        let fmt = effectiveOutputFormat(toolKind: toolKind, outputFormat: outputFormat)
        switch fmt {
        case "WORD":  return ("doc.richtext.fill",                        .systemIndigo)
        case "PDF":   return ("book.pages.fill",                          .systemRed)
        case "EXCEL": return ("tablecells.fill",                          .systemGreen)
        case "PPT":   return ("tv.fill",                                  .systemOrange)
        case "PNG":   return ("photo.fill",                               .systemTeal)
        case "HTML":  return ("globe",                                    .systemPurple)
        case "XML":   return ("chevron.left.forwardslash.chevron.right",  .systemBrown)
        default:      return ("doc.fill",                                 .appPrimary)
        }
    }
}
