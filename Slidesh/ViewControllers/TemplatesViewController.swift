//
//  TemplatesViewController.swift
//  Slidesh
//

import UIKit

// 模板页，背景为多色块晕染的幻彩网格渐变效果
class TemplatesViewController: UIViewController {

    private let meshView = MeshGradientView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "模板"
        setupMeshBackground()
    }

    private func setupMeshBackground() {
        // 底色：极淡暖白
        meshView.baseColor = UIColor(red: 0.990, green: 0.990, blue: 0.995, alpha: 1.0)

        // 各色块：位置、半径、颜色不规则分布，制造晕染感
        // 颜色极淡，alpha 控制浓淡
        meshView.blobs = [
            // 左上：薄荷青
            .init(color: UIColor(red: 0.75, green: 0.93, blue: 0.91, alpha: 1),
                  center: CGPoint(x: 0.05, y: 0.08), radiusRatio: 0.62, alpha: 0.55),

            // 右上：淡薰衣草紫
            .init(color: UIColor(red: 0.86, green: 0.80, blue: 0.97, alpha: 1),
                  center: CGPoint(x: 0.92, y: 0.05), radiusRatio: 0.55, alpha: 0.50),

            // 中偏右：玫瑰粉
            .init(color: UIColor(red: 0.99, green: 0.78, blue: 0.84, alpha: 1),
                  center: CGPoint(x: 0.80, y: 0.42), radiusRatio: 0.50, alpha: 0.38),

            // 右下：暖桃橙
            .init(color: UIColor(red: 0.99, green: 0.85, blue: 0.74, alpha: 1),
                  center: CGPoint(x: 0.95, y: 0.82), radiusRatio: 0.58, alpha: 0.42),

            // 左下：天蓝
            .init(color: UIColor(red: 0.72, green: 0.87, blue: 0.99, alpha: 1),
                  center: CGPoint(x: 0.10, y: 0.88), radiusRatio: 0.52, alpha: 0.48),

            // 中上偏左：淡黄绿（提亮中间区域）
            .init(color: UIColor(red: 0.88, green: 0.97, blue: 0.84, alpha: 1),
                  center: CGPoint(x: 0.38, y: 0.22), radiusRatio: 0.40, alpha: 0.30),

            // 中下：淡紫蓝（填补中部空白）
            .init(color: UIColor(red: 0.78, green: 0.83, blue: 0.99, alpha: 1),
                  center: CGPoint(x: 0.52, y: 0.70), radiusRatio: 0.45, alpha: 0.28),
        ]

        meshView.frame = view.bounds
        meshView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(meshView, at: 0)
    }
}
