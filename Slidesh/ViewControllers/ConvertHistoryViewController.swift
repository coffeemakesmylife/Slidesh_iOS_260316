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
    private var records: [ConvertRecord] = []

    // QLPreviewController 数据源缓存
    private var previewURLs: [URL] = []

    // 日期格式化
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
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
        records = WorksStore.shared.converts
        tableView.reloadData()
        updateEmptyState()
    }

    @objc private func worksDidUpdate() {
        records = WorksStore.shared.converts
        tableView.reloadData()
        updateEmptyState()
    }

    // MARK: - UI

    private func setupTableView() {
        tableView.backgroundColor   = .clear
        tableView.separatorStyle    = .none
        tableView.rowHeight         = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
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
        emptyView.isHidden = !records.isEmpty
        tableView.isHidden = records.isEmpty
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
        let record = records[indexPath.row]
        // 删除本地文件
        if !record.isRemoteResult {
            record.resultPaths.forEach {
                try? FileManager.default.removeItem(at: resolveLocalPath($0))
            }
        }
        WorksStore.shared.deleteConvert(id: record.id)
        records.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateEmptyState()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ConvertHistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConvertHistoryCell.reuseID, for: indexPath) as! ConvertHistoryCell
        cell.configure(with: records[indexPath.row], dateFormatter: Self.dateFormatter)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        previewRecord(records[indexPath.row])
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
        cardView.layer.cornerRadius = 20
        cardView.layer.borderWidth  = 1
        cardView.layer.borderColor  = UIColor.appCardBorder.cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        // 图标背景
        iconBg.layer.cornerRadius = 14
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

    func configure(with record: ConvertRecord, dateFormatter: DateFormatter) {
        let color = resolveColor(record.toolColorName)

        iconBg.backgroundColor = color.withAlphaComponent(0.15)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image     = UIImage(systemName: record.toolIcon, withConfiguration: config)
        iconView.tintColor = color

        titleLabel.text = record.toolTitle
        fileLabel.text  = record.inputFileName
        dateLabel.text  = dateFormatter.string(from: record.savedAt)

        if let fmt = record.outputFormat {
            badgeLabel.text       = fmt
            badgeLabel.textColor  = color
            badgeView.backgroundColor = color.withAlphaComponent(0.12)
            badgeView.isHidden    = false
        } else {
            badgeView.isHidden = true
        }
    }

    // 主题切换时更新 CALayer border
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        cardView.layer.borderColor = UIColor.appCardBorder.cgColor
    }

    private func resolveColor(_ name: String) -> UIColor {
        switch name {
        case "appPrimary":   return .appPrimary
        case "systemRed":    return .systemRed
        case "systemBlue":   return .systemBlue
        case "systemIndigo": return .systemIndigo
        case "systemGreen":  return .systemGreen
        case "systemOrange": return .systemOrange
        case "systemTeal":   return .systemTeal
        case "systemPurple": return .systemPurple
        case "systemBrown":  return .systemBrown
        default:             return .appPrimary
        }
    }
}
