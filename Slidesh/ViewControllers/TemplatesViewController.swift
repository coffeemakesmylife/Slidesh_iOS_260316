//
//  TemplatesViewController.swift
//  Slidesh
//

import UIKit

// 模板页，背景为幻彩渐变（顶部暖白→薰衣草蓝→天空蓝→浅青→底部白）
class TemplatesViewController: UIViewController {

    // 渐变背景层
    private let gradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "模板"
        setupGradientBackground()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 跟随 view 尺寸更新（旋转/布局变化时保持正确）
        gradientLayer.frame = view.bounds
    }

    private func setupGradientBackground() {
        // 从上到下：暖白 → 薰衣草蓝 → 天空蓝 → 亮天蓝 → 浅青 → 近白
        gradientLayer.colors = [
            UIColor(red: 0.996, green: 0.992, blue: 0.965, alpha: 1.0).cgColor, // #FEFDF6 顶部暖白
            UIColor(red: 0.847, green: 0.863, blue: 0.980, alpha: 1.0).cgColor, // #D8DCFA 薰衣草蓝
            UIColor(red: 0.667, green: 0.800, blue: 0.973, alpha: 1.0).cgColor, // #AACCF8 天空蓝
            UIColor(red: 0.561, green: 0.831, blue: 0.961, alpha: 1.0).cgColor, // #8FD4F5 亮天蓝
            UIColor(red: 0.659, green: 0.894, blue: 0.973, alpha: 1.0).cgColor, // #A8E4F8 浅青
            UIColor(red: 0.816, green: 0.941, blue: 0.980, alpha: 1.0).cgColor, // #D0F0FA 淡青
            UIColor(red: 0.949, green: 0.984, blue: 1.000, alpha: 1.0).cgColor  // #F2FBFF 底部近白
        ]
        // 各色标位置，让中段天空蓝区域更宽
        gradientLayer.locations = [0.0, 0.15, 0.32, 0.50, 0.68, 0.84, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.frame = view.bounds

        view.layer.insertSublayer(gradientLayer, at: 0)
    }
}
