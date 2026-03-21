//
//  SavedOutlineViewController.swift
//  Slidesh
//
//  只读展示已保存的大纲，样式与生成结果页完全一致
//

import UIKit

class SavedOutlineViewController: UIViewController {

    private let record: OutlineRecord
    private var sections: [OutlineSection] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(record: OutlineRecord) {
        self.record = record
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = record.subject
        view.backgroundColor = .systemGroupedBackground
        addMeshGradientBackground()
        sections = MarkdownParser.parse(record.markdown)
        setupTableView()
    }

    private func setupTableView() {
        tableView.dataSource    = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle  = .none
        tableView.allowsSelection = false
        tableView.register(OutlineHeaderCell.self, forCellReuseIdentifier: OutlineHeaderCell.reuseID)
        tableView.register(OutlineBulletCell.self, forCellReuseIdentifier: OutlineBulletCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: - UITableViewDataSource

extension SavedOutlineViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1 + sections[section].bullets.count  // 1 header + n bullets
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sec = sections[indexPath.section]

        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: OutlineHeaderCell.reuseID, for: indexPath) as! OutlineHeaderCell
            cell.configure(tag: sec.tagLabel, title: sec.title)
            cell.setReadOnly()
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: OutlineBulletCell.reuseID, for: indexPath) as! OutlineBulletCell
            cell.configure(with: sec.bullets[indexPath.row - 1])
            cell.setReadOnly()
            return cell
        }
    }
}
