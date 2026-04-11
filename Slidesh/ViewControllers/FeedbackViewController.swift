//
//  FeedbackViewController.swift
//  Slidesh
//

import UIKit

// 反馈分类
private enum FeedbackCategory: Int, CaseIterable {
    case bug        = 0
    case suggestion = 1
    case other      = 2

    var displayName: String {
        switch self {
        case .bug:        return NSLocalizedString("Bug 报告", comment: "")
        case .suggestion: return NSLocalizedString("功能建议", comment: "")
        case .other:      return NSLocalizedString("其他", comment: "")
        }
    }

    // 服务端 type 字段
    var typeCode: String {
        switch self {
        case .bug:        return "3"
        case .suggestion: return "2"
        case .other:      return "4"
        }
    }
}

class FeedbackViewController: UIViewController {

    // MARK: - 属性

    private let maxLength = 500

    // MARK: - UI 组件

    private let categorySegment: UISegmentedControl = {
        let items = FeedbackCategory.allCases.map { $0.displayName }
        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentIndex = 0
        seg.selectedSegmentTintColor = .appGradientMid
        seg.setTitleTextAttributes([.foregroundColor: UIColor.appTextPrimary], for: .normal)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        seg.translatesAutoresizingMaskIntoConstraints = false
        return seg
    }()

    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let charCountLabel = UILabel()
    private let contactTextField = UITextField()
    private let sendButton = UIButton(type: .system)

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("反馈", comment: "")
        addMeshGradientBackground()
        setupUI()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI 搭建

    private func setupUI() {
        // 分类标签
        let categoryLabel = makeLabel(NSLocalizedString("反馈类型", comment: ""))
        // 内容标签
        let contentLabel = makeLabel(NSLocalizedString("反馈内容", comment: ""))
        // 联系方式标签
        let contactLabel = makeLabel(NSLocalizedString("联系方式（选填）", comment: ""))

        // 反馈内容卡片
        let textCard = makeCard()
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .appTextPrimary
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.text = NSLocalizedString("请描述您遇到的问题或建议…", comment: "")
        placeholderLabel.font = .systemFont(ofSize: 15)
        placeholderLabel.textColor = .appInputPlaceholder
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        charCountLabel.text = "0 / \(maxLength)"
        charCountLabel.font = .systemFont(ofSize: 12)
        charCountLabel.textColor = .appTextTertiary
        charCountLabel.translatesAutoresizingMaskIntoConstraints = false

        textCard.addSubview(textView)
        textCard.addSubview(placeholderLabel)
        textCard.addSubview(charCountLabel)

        // 联系方式卡片
        let contactCard = makeCard()
        contactTextField.placeholder = NSLocalizedString("邮箱或手机号", comment: "")
        contactTextField.font = .systemFont(ofSize: 15)
        contactTextField.textColor = .appTextPrimary
        contactTextField.backgroundColor = .clear
        contactTextField.keyboardType = .emailAddress
        contactTextField.autocapitalizationType = .none
        contactTextField.returnKeyType = .done
        contactTextField.delegate = self
        contactTextField.translatesAutoresizingMaskIntoConstraints = false
        contactCard.addSubview(contactTextField)

        // 发送按钮
        sendButton.setTitle(NSLocalizedString("提交反馈", comment: ""), for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendButton.backgroundColor = .appButtonPrimary
        sendButton.layer.cornerRadius = 16
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        [categoryLabel, categorySegment, contentLabel, textCard,
         contactLabel, contactCard, sendButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            // 分类标签
            categoryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            categoryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            // 分类选择器
            categorySegment.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 8),
            categorySegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categorySegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            categorySegment.heightAnchor.constraint(equalToConstant: 36),

            // 内容标签
            contentLabel.topAnchor.constraint(equalTo: categorySegment.bottomAnchor, constant: 20),
            contentLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            // 内容卡片
            textCard.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 8),
            textCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textCard.heightAnchor.constraint(equalToConstant: 180),

            placeholderLabel.topAnchor.constraint(equalTo: textCard.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: textCard.leadingAnchor, constant: 14),
            placeholderLabel.trailingAnchor.constraint(equalTo: textCard.trailingAnchor, constant: -14),

            textView.topAnchor.constraint(equalTo: textCard.topAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: textCard.leadingAnchor, constant: 10),
            textView.trailingAnchor.constraint(equalTo: textCard.trailingAnchor, constant: -10),
            textView.bottomAnchor.constraint(equalTo: charCountLabel.topAnchor, constant: -4),

            charCountLabel.bottomAnchor.constraint(equalTo: textCard.bottomAnchor, constant: -10),
            charCountLabel.trailingAnchor.constraint(equalTo: textCard.trailingAnchor, constant: -14),

            // 联系标签
            contactLabel.topAnchor.constraint(equalTo: textCard.bottomAnchor, constant: 20),
            contactLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            // 联系卡片
            contactCard.topAnchor.constraint(equalTo: contactLabel.bottomAnchor, constant: 8),
            contactCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contactCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contactCard.heightAnchor.constraint(equalToConstant: 50),

            contactTextField.topAnchor.constraint(equalTo: contactCard.topAnchor),
            contactTextField.bottomAnchor.constraint(equalTo: contactCard.bottomAnchor),
            contactTextField.leadingAnchor.constraint(equalTo: contactCard.leadingAnchor, constant: 14),
            contactTextField.trailingAnchor.constraint(equalTo: contactCard.trailingAnchor, constant: -14),

            // 提交按钮
            sendButton.topAnchor.constraint(equalTo: contactCard.bottomAnchor, constant: 28),
            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sendButton.heightAnchor.constraint(equalToConstant: 52),
        ])

        // 点击空白收键盘
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = .appCardBackground.withAlphaComponent(0.65)
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .appTextSecondary
        return l
    }

    // MARK: - 动作

    @objc private func sendTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            shake(sendButton)
            return
        }

        let category = FeedbackCategory(rawValue: categorySegment.selectedSegmentIndex) ?? .suggestion
        submitFeedbackToServer(content: text, typeCode: category.typeCode,
                               contact: contactTextField.text ?? "")
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

    // MARK: - API 提交

    private func submitFeedbackToServer(content: String, typeCode: String, contact: String) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        // 内容前缀注入版本信息
        let contentWithInfo = "[Version: \(version)]\n\(content)"

        // 联系方式中附加 userId
        var finalContact = contact
        if let userId = AppDelegate.getCurrentUserId() {
            finalContact = contact.isEmpty ? "ID: \(userId)" : "\(contact) (ID: \(userId))"
        }

        var parameters: [String: String] = [
            "content": contentWithInfo,
            "type":    typeCode,
            "appId":   AppConfig.appId,
        ]
        if !finalContact.isEmpty {
            parameters["contact"] = finalContact
        }

        let urlString = "\(AppConfig.configBaseURL)/v1/api/ai/chat/feedback"
        guard let url = URL(string: urlString) else {
            showAlert(title: NSLocalizedString("错误", comment: ""), message: NSLocalizedString("无效的请求地址", comment: ""))
            return
        }

        // 禁用按钮防止重复提交
        sendButton.isEnabled = false
        sendButton.alpha = 0.5

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.sendButton.isEnabled = true
                self?.sendButton.alpha = 1.0

                if let error = error {
                    print("❌ 反馈提交失败: \(error)")
                    self?.showAlert(title: NSLocalizedString("提交失败", comment: ""), message: NSLocalizedString("网络连接失败，请检查网络后重试", comment: ""))
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self?.showAlert(title: NSLocalizedString("提交失败", comment: ""), message: NSLocalizedString("响应解析失败，请稍后重试", comment: ""))
                    return
                }

                if let code = json["code"] as? Int, code == 200 {
                    print("✅ 反馈提交成功")
                    self?.showSuccessAndPop()
                } else {
                    let msg = json["msg"] as? String ?? NSLocalizedString("提交失败，请稍后重试", comment: "")
                    self?.showAlert(title: NSLocalizedString("提交失败", comment: ""), message: msg)
                }
            }
        }.resume()
    }

    private func showSuccessAndPop() {
        let alert = UIAlertController(title: NSLocalizedString("感谢反馈 🎉", comment: ""),
                                      message: NSLocalizedString("我们会认真阅读您的反馈！", comment: ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        present(alert, animated: true)
    }

    private func shake(_ v: UIView) {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [-8, 8, -6, 6, -4, 4, 0]
        anim.duration = 0.35
        v.layer.add(anim, forKey: nil)
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

// MARK: - UITextFieldDelegate

extension FeedbackViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
