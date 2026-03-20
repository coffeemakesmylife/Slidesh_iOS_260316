//
//  MyWorksViewController.swift
//  Slidesh
//
//  我的作品页：分两个 section 展示 PPT 和大纲，点击跳转预览
//

import UIKit

class MyWorksViewController: UIViewController {

    // MARK: - 数据

    private var ppts:     [PPTRecord]     = []
    private var outlines: [OutlineRecord] = []

    // MARK: - 视图

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "我的作品"
        view.backgroundColor = .systemGroupedBackground
        addMeshGradientBackground()
        setupTableView()
        reloadData()

        // 订阅 WorksStore 变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(worksDidUpdate),
            name: .worksDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 布局

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - 数据刷新

    private func reloadData() {
        ppts     = WorksStore.shared.ppts
        outlines = WorksStore.shared.outlines
        tableView.reloadData()
    }

    @objc private func worksDidUpdate() {
        DispatchQueue.main.async { self.reloadData() }
    }

    // MARK: - 辅助

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()
}

// MARK: - UITableViewDataSource

extension MyWorksViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? max(ppts.count, 1) : max(outlines.count, 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "PPT 文件（\(ppts.count)）" : "大纲（\(outlines.count)）"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        var config = UIListContentConfiguration.subtitleCell()

        if indexPath.section == 0 {
            if ppts.isEmpty {
                config.text = "暂无 PPT 记录"
                config.textProperties.color = .secondaryLabel
                cell.accessoryType  = .none
                cell.selectionStyle = .none
            } else {
                let record = ppts[indexPath.row]
                config.text          = record.subject
                config.secondaryText = MyWorksViewController.dateFormatter.string(from: record.savedAt)
                config.image         = UIImage(systemName: "doc.richtext")
                cell.accessoryType   = .disclosureIndicator
                cell.selectionStyle  = .default
            }
        } else {
            if outlines.isEmpty {
                config.text = "暂无大纲记录"
                config.textProperties.color = .secondaryLabel
                cell.accessoryType  = .none
                cell.selectionStyle = .none
            } else {
                let record = outlines[indexPath.row]
                config.text          = record.subject
                config.secondaryText = MyWorksViewController.dateFormatter.string(from: record.savedAt)
                config.image         = UIImage(systemName: "list.bullet.rectangle")
                cell.accessoryType   = .disclosureIndicator
                cell.selectionStyle  = .default
            }
        }

        cell.contentConfiguration = config
        cell.backgroundColor = .clear
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MyWorksViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0, !ppts.isEmpty {
            let record = ppts[indexPath.row]
            let info   = PPTInfo(
                pptId:    record.id,
                taskId:   record.taskId,
                subject:  record.subject,
                fileUrl:  record.fileUrl,
                coverUrl: record.coverUrl,
                status:   "SUCCESS",
                total:    nil
            )
            let vc = PPTPreviewViewController(pptInfo: info)
            navigationController?.pushViewController(vc, animated: true)

        } else if indexPath.section == 1, !outlines.isEmpty {
            let record = outlines[indexPath.row]
            let vc = SavedOutlineViewController(record: record)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
