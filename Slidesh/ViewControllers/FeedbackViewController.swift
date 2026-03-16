//
//  FeedbackViewController.swift
//  Slidesh
//

import UIKit
import MessageUI

class FeedbackViewController: UIViewController {

    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private let charCountLabel = UILabel()

    private let maxLength = 500

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "反馈"
        addMeshGradientBackground()
        setupUI()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI

    private func setupUI() {
        let card = UIView()
        card.backgroundColor = .appCardBackground.withAlphaComponent(0.65)
        card.layer.cornerRadius = 26
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        // 文本视图
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .appTextPrimary
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.returnKeyType = .default
        textView.translatesAutoresizingMaskIntoConstraints = false

        // 占位符
        placeholderLabel.text = "请描述您遇到的问题或建议…"
        placeholderLabel.font = .systemFont(ofSize: 15)
        placeholderLabel.textColor = .appInputPlaceholder
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        // 字数统计
        charCountLabel.text = "0 / \(maxLength)"
        charCountLabel.font = .systemFont(ofSize: 12)
        charCountLabel.textColor = .appTextTertiary
        charCountLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(textView)
        card.addSubview(placeholderLabel)
        card.addSubview(charCountLabel)

        // 发送按钮
        sendButton.setTitle("发送反馈", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendButton.backgroundColor = .appButtonPrimary
        sendButton.layer.cornerRadius = 16
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sendButton)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            card.heightAnchor.constraint(equalToConstant: 220),

            placeholderLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            placeholderLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            textView.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            textView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            textView.bottomAnchor.constraint(equalTo: charCountLabel.topAnchor, constant: -4),

            charCountLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            charCountLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            sendButton.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 20),
            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sendButton.heightAnchor.constraint(equalToConstant: 52),
        ])

        // 点击空白收键盘
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    // MARK: - 动作

    @objc private func sendTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            shake(sendButton)
            return
        }

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["feedback@slidesh.app"])
            mail.setSubject("Slidesh 用户反馈")
            mail.setMessageBody(text, isHTML: false)
            present(mail, animated: true)
        } else {
            // 无邮件客户端时，复制内容到剪贴板
            UIPasteboard.general.string = text
            let alert = UIAlertController(title: "已复制到剪贴板",
                                          message: "您的设备未配置邮件，反馈内容已复制，请手动发送至 feedback@slidesh.app",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        let bottom = max(0, view.bounds.height - frame.origin.y)
        UIView.animate(withDuration: duration) {
            self.sendButton.transform = CGAffineTransform(translationX: 0, y: -bottom)
        }
    }

    private func shake(_ view: UIView) {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [-8, 8, -6, 6, -4, 4, 0]
        anim.duration = 0.35
        view.layer.add(anim, forKey: nil)
    }
}

// MARK: - UITextViewDelegate

extension FeedbackViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        let count = textView.text.count
        charCountLabel.text = "\(count) / \(maxLength)"
        charCountLabel.textColor = count > maxLength ? .appError : .appTextTertiary
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let newLength = textView.text.count + text.count - range.length
        return newLength <= maxLength
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension FeedbackViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
        if result == .sent {
            let alert = UIAlertController(title: "感谢反馈 🎉", message: "我们会认真阅读您的反馈！", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
            present(alert, animated: true)
        }
    }
}
