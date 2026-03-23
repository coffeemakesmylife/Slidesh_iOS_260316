//
//  ConvertJobViewController.swift
//  Slidesh
//
//  格式转换任务页：选文件 → 上传 → 预览结果
//

import UIKit
import UniformTypeIdentifiers
import QuickLook

final class ConvertJobViewController: UIViewController {

    // MARK: - 初始化参数

    private let tool:         ConvertToolItem
    private var outputFormat: String?    // 已选格式（有格式选项时由调用方传入）

    init(tool: ConvertToolItem, outputFormat: String? = nil) {
        self.tool         = tool
        self.outputFormat = outputFormat
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 状态

    private enum State {
        case idle
        case fileSelected(files: [URL])
        case converting
        case success(resultURLs: [URL])
        case error(message: String, lastFiles: [URL])
    }

    private var state: State = .idle {
        didSet { updateUI(for: state) }
    }

    // MARK: - UI 元素

    private let scrollView   = UIScrollView()
    private let contentView  = UIView()

    // 顶部图标区
    private let iconBg       = UIView()
    private let iconView     = UIImageView()

    // 标题/副标题
    private let titleLabel   = UILabel()
    private let subLabel     = UILabel()

    // 文件卡片（fileSelected 显示）
    private let fileCardView  = UIView()
    private let fileIconView  = UIImageView()
    private let fileNameLabel = UILabel()
    private let fileSizeLabel = UILabel()
    private let formatBadge   = UILabel()
    // 合并PDF文件列表
    private let fileListStack = UIStackView()

    // 进度区（converting 显示）
    private let progressContainer = UIView()
    private let progressBg        = UIView()
    private let progressFill      = GradientProgressView()
    private let progressLabel     = UILabel()

    // 状态图标（success/error）
    private let statusIconView = UIImageView()

    // 按钮区
    private let primaryBtn    = GradientButton()
    private let secondaryBtn  = UIButton(type: .system)

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = tool.title
        view.backgroundColor = .appBackgroundPrimary
        addMeshGradientBackground()
        setupUI()
        state = .idle
        if let files = pendingPrefillFiles {
            pendingPrefillFiles = nil
            state = .fileSelected(files: files)
        }
    }

    // MARK: - 预填文件（由调用方在 push 前调用）

    func prefillFiles(_ files: [URL]) {
        pendingPrefillFiles = files
    }
    private var pendingPrefillFiles: [URL]?

    // MARK: - UI 搭建

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        setupIconArea()
        setupTitleArea()
        setupFileCard()
        setupProgressArea()
        setupStatusIcon()
        setupButtons()
    }

    private func setupIconArea() {
        iconBg.layer.cornerRadius = 28
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconBg)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconBg.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 32),
            iconBg.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 80),
            iconBg.heightAnchor.constraint(equalToConstant: 80),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
        ])

        let color = resolveColor(tool.colorName)
        iconBg.backgroundColor = color.withAlphaComponent(0.15)
        iconView.image     = UIImage(systemName: tool.icon)
        iconView.tintColor = color
    }

    private func setupTitleArea() {
        titleLabel.font          = .systemFont(ofSize: 22, weight: .heavy)
        titleLabel.textColor     = .appTextPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subLabel.font          = .systemFont(ofSize: 14)
        subLabel.textColor     = .appTextSecondary
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 0
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        titleLabel.text = tool.title
    }

    private func setupFileCard() {
        fileCardView.backgroundColor    = .appCardBackground.withAlphaComponent(0.7)
        fileCardView.layer.cornerRadius = 20
        fileCardView.layer.borderWidth  = 1
        fileCardView.layer.borderColor  = UIColor.appCardBorder.cgColor
        fileCardView.isHidden = true
        fileCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fileCardView)

        fileIconView.image       = UIImage(systemName: "doc.fill")
        fileIconView.tintColor   = .appPrimary
        fileIconView.contentMode = .scaleAspectFit
        fileIconView.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileIconView)

        fileNameLabel.font      = .systemFont(ofSize: 15, weight: .semibold)
        fileNameLabel.textColor = .appTextPrimary
        fileNameLabel.numberOfLines = 2
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileNameLabel)

        fileSizeLabel.font      = .systemFont(ofSize: 12)
        fileSizeLabel.textColor = .appTextSecondary
        fileSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileSizeLabel)

        formatBadge.font            = .systemFont(ofSize: 12, weight: .bold)
        formatBadge.textColor       = .white
        formatBadge.backgroundColor = .appPrimary
        formatBadge.layer.cornerRadius = 8
        formatBadge.clipsToBounds   = true
        formatBadge.textAlignment   = .center
        formatBadge.isHidden        = true
        formatBadge.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(formatBadge)

        fileListStack.axis    = .vertical
        fileListStack.spacing = 8
        fileListStack.isHidden = true
        fileListStack.translatesAutoresizingMaskIntoConstraints = false
        fileCardView.addSubview(fileListStack)

        NSLayoutConstraint.activate([
            fileCardView.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 24),
            fileCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            fileCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            fileIconView.topAnchor.constraint(equalTo: fileCardView.topAnchor, constant: 16),
            fileIconView.leadingAnchor.constraint(equalTo: fileCardView.leadingAnchor, constant: 16),
            fileIconView.widthAnchor.constraint(equalToConstant: 36),
            fileIconView.heightAnchor.constraint(equalToConstant: 36),

            fileNameLabel.topAnchor.constraint(equalTo: fileCardView.topAnchor, constant: 16),
            fileNameLabel.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 12),
            fileNameLabel.trailingAnchor.constraint(equalTo: formatBadge.leadingAnchor, constant: -8),

            fileSizeLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 4),
            fileSizeLabel.leadingAnchor.constraint(equalTo: fileNameLabel.leadingAnchor),
            fileSizeLabel.bottomAnchor.constraint(lessThanOrEqualTo: fileCardView.bottomAnchor, constant: -16),

            formatBadge.centerYAnchor.constraint(equalTo: fileCardView.topAnchor, constant: 32),
            formatBadge.trailingAnchor.constraint(equalTo: fileCardView.trailingAnchor, constant: -16),
            formatBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            formatBadge.heightAnchor.constraint(equalToConstant: 24),

            fileListStack.topAnchor.constraint(equalTo: fileIconView.bottomAnchor, constant: 12),
            fileListStack.leadingAnchor.constraint(equalTo: fileCardView.leadingAnchor, constant: 16),
            fileListStack.trailingAnchor.constraint(equalTo: fileCardView.trailingAnchor, constant: -16),
            fileListStack.bottomAnchor.constraint(equalTo: fileCardView.bottomAnchor, constant: -16),
        ])
    }

    private func setupProgressArea() {
        progressContainer.isHidden = true
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressContainer)

        progressBg.backgroundColor    = .appCardBackground.withAlphaComponent(0.6)
        progressBg.layer.cornerRadius = 8
        progressBg.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressBg)

        progressFill.layer.cornerRadius = 8
        progressFill.clipsToBounds      = true
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBg.addSubview(progressFill)

        progressLabel.font          = .systemFont(ofSize: 14)
        progressLabel.textColor     = .appTextSecondary
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressLabel)

        NSLayoutConstraint.activate([
            progressContainer.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 32),
            progressContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            progressBg.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressBg.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBg.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressBg.heightAnchor.constraint(equalToConstant: 16),

            progressFill.topAnchor.constraint(equalTo: progressBg.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBg.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBg.bottomAnchor),

            progressLabel.topAnchor.constraint(equalTo: progressBg.bottomAnchor, constant: 12),
            progressLabel.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressLabel.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
        ])
    }

    private var progressFillWidth: NSLayoutConstraint?

    private func setupStatusIcon() {
        statusIconView.contentMode = .scaleAspectFit
        statusIconView.isHidden    = true
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusIconView)

        NSLayoutConstraint.activate([
            statusIconView.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 32),
            statusIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 64),
            statusIconView.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    private func setupButtons() {
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(primaryBtn)
        primaryBtn.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        secondaryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        secondaryBtn.setTitleColor(.appTextSecondary, for: .normal)
        secondaryBtn.backgroundColor    = .appCardBackground.withAlphaComponent(0.7)
        secondaryBtn.layer.cornerRadius = 16
        secondaryBtn.layer.borderWidth  = 1
        secondaryBtn.layer.borderColor  = UIColor.appCardBorder.cgColor
        secondaryBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(secondaryBtn)
        secondaryBtn.addTarget(self, action: #selector(didTapSecondary), for: .touchUpInside)

        NSLayoutConstraint.activate([
            primaryBtn.topAnchor.constraint(equalTo: statusIconView.bottomAnchor, constant: 32),
            primaryBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            primaryBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            primaryBtn.heightAnchor.constraint(equalToConstant: 54),

            secondaryBtn.topAnchor.constraint(equalTo: primaryBtn.bottomAnchor, constant: 12),
            secondaryBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            secondaryBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            secondaryBtn.heightAnchor.constraint(equalToConstant: 48),
            secondaryBtn.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - 状态更新

    private func updateUI(for state: State) {
        fileCardView.isHidden      = true
        progressContainer.isHidden = true
        statusIconView.isHidden    = true
        isModalInPresentation      = false

        switch state {
        case .idle:
            let hint = tool.allowsMultiple
                ? "请选择 2 个或更多 PDF 文件"
                : "支持：\(tool.acceptedExtensions.joined(separator: "、"))"
            subLabel.text = hint
            primaryBtn.setTitle(tool.allowsMultiple ? "选择多个文件（至少 2 个）" : "选择文件", for: .normal)
            primaryBtn.isEnabled = true
            secondaryBtn.isHidden = true

        case .fileSelected(let files):
            fileCardView.isHidden = false
            subLabel.text = nil
            if tool.allowsMultiple {
                fileIconView.isHidden  = true
                fileNameLabel.isHidden = true
                fileSizeLabel.isHidden = true
                fileListStack.isHidden = false
                rebuildFileList(files: files)
            } else {
                fileIconView.isHidden  = false
                fileNameLabel.isHidden = false
                fileSizeLabel.isHidden = false
                fileListStack.isHidden = true
                fileNameLabel.text = files[0].lastPathComponent
                fileSizeLabel.text = fileSizeString(url: files[0])
            }
            // 无论单文件还是多文件，outputFormat 存在时都显示格式 badge
            if let fmt = outputFormat {
                formatBadge.text    = "→ \(fmt)"
                formatBadge.isHidden = false
            } else {
                formatBadge.isHidden = true
            }
            primaryBtn.setTitle("开始转换", for: .normal)
            primaryBtn.isEnabled = !tool.allowsMultiple || files.count >= 2
            secondaryBtn.isHidden = false
            secondaryBtn.setTitle("重新选择", for: .normal)

        case .converting:
            progressContainer.isHidden = false
            isModalInPresentation      = true
            subLabel.text              = nil
            setUploadProgress(0)
            primaryBtn.setTitle("取消", for: .normal)
            primaryBtn.isEnabled = true
            secondaryBtn.isHidden = true

        case .success:
            statusIconView.isHidden  = false
            statusIconView.image     = UIImage(systemName: "checkmark.circle.fill")
            statusIconView.tintColor = .appSuccess
            subLabel.text = "转换完成！"
            primaryBtn.setTitle("预览结果", for: .normal)
            primaryBtn.isEnabled = true
            secondaryBtn.isHidden = false
            secondaryBtn.setTitle("再转一个", for: .normal)

        case .error(let message, _):
            statusIconView.isHidden  = false
            statusIconView.image     = UIImage(systemName: "exclamationmark.circle.fill")
            statusIconView.tintColor = .appError
            subLabel.text = message
            primaryBtn.setTitle("重试", for: .normal)
            primaryBtn.isEnabled = true
            secondaryBtn.isHidden = false
            secondaryBtn.setTitle("重新选择文件", for: .normal)
        }
    }

    private func setUploadProgress(_ value: Double) {
        progressFillWidth?.isActive = false
        if value >= 1.0 {
            progressLabel.text = "转换中..."
            progressFillWidth = progressFill.widthAnchor.constraint(
                equalTo: progressBg.widthAnchor, multiplier: 0.6)
            progressFillWidth?.isActive = true
            animateIndeterminateProgress()
        } else {
            progressFillWidth = progressFill.widthAnchor.constraint(
                equalTo: progressBg.widthAnchor, multiplier: max(0.05, value))
            progressFillWidth?.isActive = true
            progressLabel.text = "正在上传... \(Int(value * 100))%"
        }
    }

    private func animateIndeterminateProgress() {
        UIView.animate(withDuration: 0.8, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction]) {
            self.progressFill.alpha = 0.5
        }
    }

    // MARK: - 文件列表（合并PDF）

    private func rebuildFileList(files: [URL]) {
        fileListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, file) in files.enumerated() {
            fileListStack.addArrangedSubview(makeFileRow(file: file, index: i))
        }
        if case .fileSelected(let f) = state {
            primaryBtn.isEnabled = f.count >= 2
        }
    }

    private func makeFileRow(file: URL, index: Int) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "doc.fill"))
        icon.tintColor = .appPrimary
        icon.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(icon)

        let name = UILabel()
        name.text      = file.lastPathComponent
        name.font      = .systemFont(ofSize: 14)
        name.textColor = .appTextPrimary
        name.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(name)

        let del = UIButton(type: .system)
        del.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        del.tintColor = .appError.withAlphaComponent(0.7)
        del.tag = index
        del.addTarget(self, action: #selector(deleteFile(_:)), for: .touchUpInside)
        del.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(del)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),

            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            name.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            name.trailingAnchor.constraint(equalTo: del.leadingAnchor, constant: -8),

            del.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            del.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            del.widthAnchor.constraint(equalToConstant: 24),
        ])
        return row
    }

    @objc private func deleteFile(_ sender: UIButton) {
        guard case .fileSelected(var files) = state else { return }
        files.remove(at: sender.tag)
        state = .fileSelected(files: files)
    }

    // MARK: - 按钮动作

    private var lastConvertedFiles: [URL] = []

    @objc private func didTapPrimary() {
        switch state {
        case .idle:
            openFilePicker()
        case .fileSelected(let files):
            startConversion(files: files)
        case .converting:
            ConvertAPIService.shared.cancel()
            state = .fileSelected(files: lastConvertedFiles)
        case .success(let urls):
            showPreview(urls: urls)
        case .error(_, let files):
            startConversion(files: files)
        }
    }

    @objc private func didTapSecondary() {
        switch state {
        case .fileSelected:
            state = .idle
        case .success:
            state = .idle
        case .error:
            state = .idle
        default:
            break
        }
    }

    // MARK: - 文件选择

    private func openFilePicker() {
        let types = tool.acceptedExtensions.compactMap { UTType(filenameExtension: $0) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types.isEmpty ? [.item] : types)
        picker.allowsMultipleSelection = tool.allowsMultiple
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - 转换

    private func startConversion(files: [URL]) {
        lastConvertedFiles = files
        state = .converting
        ConvertAPIService.shared.convert(
            tool: tool.kind,
            files: files,
            outputFormat: outputFormat,
            onUploadProgress: { [weak self] progress in
                self?.setUploadProgress(progress)
            },
            completion: { [weak self] result in
                guard let self else { return }
                progressFill.layer.removeAllAnimations()
                progressFill.alpha = 1
                switch result {
                case .success(let urls):
                    state = .success(resultURLs: urls)
                case .failure(let error):
                    state = .error(message: error.localizedDescription, lastFiles: files)
                }
            }
        )
    }

    // MARK: - 预览

    private var previewURLs: [URL] = []

    private func showPreview(urls: [URL]) {
        previewURLs = urls
        let ql = QLPreviewController()
        ql.dataSource = self
        ql.currentPreviewItemIndex = 0
        present(ql, animated: true)
    }

    // MARK: - 辅助

    private func fileSizeString(url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    // 颜色名解析（ConvertViewController 的同名方法是 private，这里定义独立版本）
    private func resolveColor(_ name: String) -> UIColor {
        switch name {
        case "appPrimary":    return .appPrimary
        case "systemRed":     return .systemRed
        case "systemBlue":    return .systemBlue
        case "systemIndigo":  return .systemIndigo
        case "systemGreen":   return .systemGreen
        case "systemOrange":  return .systemOrange
        case "systemTeal":    return .systemTeal
        case "systemPurple":  return .systemPurple
        case "systemBrown":   return .systemBrown
        default:              return .appPrimary
        }
    }
}

// MARK: - UIDocumentPickerDelegate

extension ConvertJobViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // startAccessingSecurityScopedResource 对非安全作用域 URL 返回 false 是正常的，文件仍可访问
        urls.forEach { _ = $0.startAccessingSecurityScopedResource() }
        state = .fileSelected(files: urls)
    }
}

// MARK: - QLPreviewControllerDataSource

extension ConvertJobViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewURLs.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURLs[index] as NSURL
    }
}

// MARK: - GradientButton（渐变主按钮）

final class GradientButton: UIButton {
    private let gradLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradLayer.colors     = [UIColor.appGradientStart.cgColor,
                                UIColor.appGradientMid.cgColor,
                                UIColor.appGradientEnd.cgColor]
        gradLayer.locations  = [0.0, 0.55, 1.0]
        gradLayer.startPoint = CGPoint(x: 0, y: 0)
        gradLayer.endPoint   = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradLayer, at: 0)
        layer.cornerRadius = 16
        clipsToBounds = true
        setTitleColor(.white, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradLayer.frame = bounds
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1.0 : 0.5 }
    }
}

// MARK: - GradientProgressView（渐变进度条）

final class GradientProgressView: UIView {
    private let gradLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradLayer.colors     = [UIColor.appGradientStart.cgColor, UIColor.appGradientEnd.cgColor]
        gradLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradLayer, at: 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradLayer.frame = bounds
    }
}
