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
        // 从上到下：极淡暖白 → 淡薰衣草 → 淡天蓝 → 淡青蓝 → 近白
        // 整体大幅减淡，避免与上层组件撞色
        gradientLayer.colors = [
            UIColor(red: 0.998, green: 0.997, blue: 0.990, alpha: 1.0).cgColor, // #FEFEFE 顶部近白（微暖）
            UIColor(red: 0.941, green: 0.945, blue: 0.992, alpha: 1.0).cgColor, // #F0F1FD 极淡薰衣草
            UIColor(red: 0.882, green: 0.922, blue: 0.980, alpha: 1.0).cgColor, // #E1EBF9 淡天蓝
            UIColor(red: 0.839, green: 0.918, blue: 0.969, alpha: 1.0).cgColor, // #D6EAF7 天蓝
            UIColor(red: 0.859, green: 0.937, blue: 0.976, alpha: 1.0).cgColor, // #DBEFF9 淡青蓝
            UIColor(red: 0.918, green: 0.965, blue: 0.988, alpha: 1.0).cgColor, // #EAF6FC 极淡青
            UIColor(red: 0.976, green: 0.992, blue: 1.000, alpha: 1.0).cgColor  // #F9FCFF 底部近白
        ]
        // 各色标位置，让中段天空蓝区域更宽
        gradientLayer.locations = [0.0, 0.15, 0.32, 0.50, 0.68, 0.84, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.frame = view.bounds

        view.layer.insertSublayer(gradientLayer, at: 0)
    }
}
