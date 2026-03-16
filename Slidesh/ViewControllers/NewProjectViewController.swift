//
//  NewProjectViewController.swift
//  Slidesh
//

import UIKit

// 新建项目页（点击中间 Tab 弹出）
class NewProjectViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "新建"
        view.backgroundColor = .appBackgroundPrimary

        // 关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
