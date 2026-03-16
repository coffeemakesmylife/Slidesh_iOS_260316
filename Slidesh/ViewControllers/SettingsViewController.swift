//
//  SettingsViewController.swift
//  Slidesh
//

import UIKit

// 设置页
class SettingsViewController: UIViewController {

    // 深浅色切换按钮
    private lazy var themeToggleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(currentThemeTitle(), for: .normal)
        btn.setTitleColor(.appButtonPrimaryText, for: .normal)
        btn.backgroundColor = .appButtonPrimary
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        btn.layer.cornerRadius = 12
        btn.addTarget(self, action: #selector(toggleTheme), for: .touchUpInside)
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "设置"
        view.backgroundColor = .appBackgroundPrimary
        setupButton()
    }

    private func setupButton() {
        view.addSubview(themeToggleButton)
        themeToggleButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            themeToggleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            themeToggleButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            themeToggleButton.widthAnchor.constraint(equalToConstant: 200),
            themeToggleButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // 切换深/浅色主题
    @objc private func toggleTheme() {
        guard let window = view.window else { return }
        let current = window.overrideUserInterfaceStyle
        let next: UIUserInterfaceStyle = (current == .dark) ? .light : .dark
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.overrideUserInterfaceStyle = next
        }
        themeToggleButton.setTitle(currentThemeTitle(), for: .normal)
    }

    // 根据当前主题显示对应按钮文字
    private func currentThemeTitle() -> String {
        let style = view.window?.overrideUserInterfaceStyle ?? .unspecified
        switch style {
        case .dark:  return "切换到浅色模式"
        case .light: return "切换到深色模式"
        default:     return "切换深色模式"
        }
    }
}
