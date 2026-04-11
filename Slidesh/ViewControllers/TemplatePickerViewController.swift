//
//  TemplatePickerViewController.swift
//  Slidesh
//
//  轻量模板选择器，用于 PPTPreviewViewController 换模板场景
//

import UIKit
import Kingfisher

class TemplatePickerViewController: UIViewController {

    /// 用户确认选择后回调 templateId
    var onSelect: ((String) -> Void)?

    private var templates:     [PPTTemplate] = []
    private var selectedIndex: IndexPath?
    private var currentPage  = 1
    private var isLoading    = false
    private var hasMore      = true

    private let collectionView: UICollectionView
    private let bottomBar   = UIView()
    private let confirmBtn  = UIButton(type: .custom)
    private let spinner     = UIActivityIndicatorView(style: .medium)

    // MARK: - Init

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing      = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("换模板", comment: "")
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("取消", comment: ""), style: .plain, target: self, action: #selector(cancelTapped))

        setupCollectionView()
        setupBottomBar()
        loadNextPage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCellSize()
    }

    // MARK: - 布局

    private func setupCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.register(TemplatePickerCell.self, forCellWithReuseIdentifier: TemplatePickerCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
    }

    private func setupBottomBar() {
        bottomBar.backgroundColor = .systemBackground
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        sep.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(sep)

        confirmBtn.setTitle(NSLocalizedString("使用此模板", comment: ""), for: .normal)
        confirmBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
        confirmBtn.backgroundColor = .appPrimary
        confirmBtn.layer.cornerRadius = 26
        confirmBtn.isEnabled = false
        confirmBtn.alpha = 0.5
        confirmBtn.translatesAutoresizingMaskIntoConstraints = false
        confirmBtn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        bottomBar.addSubview(confirmBtn)

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(spinner)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sep.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            confirmBtn.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            confirmBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            confirmBtn.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            confirmBtn.heightAnchor.constraint(equalToConstant: 52),
            confirmBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            spinner.centerXAnchor.constraint(equalTo: confirmBtn.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: confirmBtn.centerYAnchor),

            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
        ])
    }

    private func updateCellSize() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let inset: CGFloat = 16
        let spacing: CGFloat = 12
        let width = floor((collectionView.bounds.width - inset * 2 - spacing) / 2)
        let height = width * (9.0 / 16.0) + 46   // 封面 + 标题区域
        let newSize = CGSize(width: width, height: height)
        if layout.itemSize != newSize {
            layout.itemSize = newSize
            layout.invalidateLayout()
        }
    }

    // MARK: - 数据

    private func loadNextPage() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        PPTAPIService.shared.fetchTemplates(
            category: nil, style: nil, themeColor: nil, page: currentPage
        ) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            if case .success(let list) = result {
                if list.isEmpty {
                    self.hasMore = false
                } else {
                    let start = self.templates.count
                    self.templates += list
                    self.currentPage += 1
                    let paths = (start ..< self.templates.count).map { IndexPath(item: $0, section: 0) }
                    self.collectionView.insertItems(at: paths)
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func confirmTapped() {
        guard let idx = selectedIndex else { return }
        let templateId = templates[idx.item].id
        // 显示加载状态
        confirmBtn.setTitle("", for: .normal)
        confirmBtn.isEnabled = false
        spinner.startAnimating()
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(templateId)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension TemplatePickerViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        templates.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TemplatePickerCell.reuseID, for: indexPath) as! TemplatePickerCell
        cell.configure(with: templates[indexPath.item], selected: indexPath == selectedIndex)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension TemplatePickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let prev = selectedIndex
        selectedIndex = indexPath
        var toReload = [indexPath]
        if let p = prev, p != indexPath { toReload.append(p) }
        collectionView.reloadItems(at: toReload)
        confirmBtn.isEnabled = true
        UIView.animate(withDuration: 0.2) { self.confirmBtn.alpha = 1.0 }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let threshold = scrollView.contentSize.height - scrollView.frame.height - 200
        if scrollView.contentOffset.y > threshold { loadNextPage() }
    }
}

// MARK: - Cell

private class TemplatePickerCell: UICollectionViewCell {
    static let reuseID = "TemplatePickerCell"

    private let coverView  = UIImageView()
    private let titleLabel = UILabel()
    private let checkmark  = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        contentView.backgroundColor = .systemBackground

        coverView.contentMode     = .scaleAspectFill
        coverView.clipsToBounds   = true
        coverView.backgroundColor = .systemGray5
        coverView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font          = .systemFont(ofSize: 12)
        titleLabel.textColor     = .label
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        checkmark.tintColor          = .appPrimary
        checkmark.backgroundColor    = .white
        checkmark.layer.cornerRadius = 12
        checkmark.isHidden           = true
        checkmark.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(coverView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(checkmark)

        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 9.0 / 16.0),

            titleLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            checkmark.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            checkmark.widthAnchor.constraint(equalToConstant: 24),
            checkmark.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverView.kf.cancelDownloadTask()
        coverView.image = nil
        checkmark.isHidden = true
        contentView.layer.borderWidth = 0
    }

    func configure(with template: PPTTemplate, selected: Bool) {
        titleLabel.text = template.subject
        if let url = template.coverImageURL {
            coverView.kf.setImage(with: url, options: [.transition(.fade(0.2)), .cacheOriginalImage])
        }
        checkmark.isHidden = !selected
        contentView.layer.borderColor = UIColor.appPrimary.cgColor
        contentView.layer.borderWidth = selected ? 2 : 0
    }
}
