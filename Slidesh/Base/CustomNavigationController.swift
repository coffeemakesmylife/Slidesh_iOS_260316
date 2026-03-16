//
//  CustomNavigationController.swift
//  Slidesh
//
//  Created by ted on 2026/3/16.
//

import UIKit

// 自定义导航控制器：隐藏返回按钮文字，统一标题样式，push 时自动隐藏 TabBar
class CustomNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // 返回按钮颜色
        navigationBar.tintColor = .appTextPrimary

        // 所有 BarButtonItem 的字体和颜色
        let barButtonAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.appTextPrimary
        ]
        UIBarButtonItem.appearance().setTitleTextAttributes(barButtonAttributes, for: .normal)

        // 隐藏返回按钮文字
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(
            UIOffset(horizontal: -1000, vertical: 0), for: .default
        )

        // 标题样式
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18.5, weight: .semibold),
            .foregroundColor: UIColor.appTextPrimary
        ]
        navigationBar.titleTextAttributes = titleAttributes
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        // 非根视图 push 时隐藏底部 TabBar
        viewController.hidesBottomBarWhenPushed = children.count >= 1
        super.pushViewController(viewController, animated: animated)
    }
}
