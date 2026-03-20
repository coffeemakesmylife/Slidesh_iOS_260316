//
//  SavedOutlineViewController.swift
//  Slidesh
//
//  只读展示已保存的大纲 Markdown
//

import UIKit

class SavedOutlineViewController: UIViewController {

    private let record: OutlineRecord

    private let textView = UITextView()

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
        setupTextView()
        renderContent()
    }

    private func setupTextView() {
        textView.isEditable   = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 24, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func renderContent() {
        textView.attributedText = buildAttributedString(from: record.markdown)
    }

    // 简单 markdown 渲染：# H1  ## H2  ### H3  - bullet  正文
    private func buildAttributedString(from md: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let source = md.replacingOccurrences(of: "[DONE]", with: "")

        for line in source.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }

            let (text, font, color, spacing): (String, UIFont, UIColor, CGFloat)
            if t.hasPrefix("#### ") {
                (text, font, color, spacing) = (String(t.dropFirst(5)),
                    .systemFont(ofSize: 14, weight: .semibold), .appTextPrimary, 6)
            } else if t.hasPrefix("### ") {
                (text, font, color, spacing) = (String(t.dropFirst(4)),
                    .systemFont(ofSize: 15, weight: .semibold), .appTextPrimary, 8)
            } else if t.hasPrefix("## ") {
                (text, font, color, spacing) = (String(t.dropFirst(3)),
                    .systemFont(ofSize: 17, weight: .bold), .appTextPrimary, 12)
            } else if t.hasPrefix("# ") {
                (text, font, color, spacing) = (String(t.dropFirst(2)),
                    .systemFont(ofSize: 20, weight: .bold), .appTextPrimary, 16)
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                (text, font, color, spacing) = ("• " + String(t.dropFirst(2)),
                    .systemFont(ofSize: 14), .appTextSecondary, 4)
            } else {
                (text, font, color, spacing) = (t,
                    .systemFont(ofSize: 14), .appTextSecondary, 4)
            }

            let para = NSMutableParagraphStyle()
            para.paragraphSpacingBefore = spacing
            para.lineSpacing   = 2

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: para
            ]
            result.append(NSAttributedString(string: text + "\n", attributes: attrs))
        }
        return result
    }
}
