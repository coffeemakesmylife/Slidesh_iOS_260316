//
//  MeshGradientView.swift
//  Slidesh
//
//  用多个径向渐变色块叠加，模拟网格渐变/幻彩晕染效果
//

import UIKit

class MeshGradientView: UIView {

    // 单个色块定义
    struct Blob {
        let color: UIColor
        /// 归一化中心坐标 (0~1)
        let center: CGPoint
        /// 相对于视图最大边的半径比例
        let radiusRatio: CGFloat
        let alpha: CGFloat
    }

    var blobs: [Blob] = [] {
        didSet { setNeedsDisplay() }
    }

    /// 底色（建议接近白色）
    var baseColor: UIColor = UIColor(red: 0.992, green: 0.992, blue: 0.996, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = true
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 先填底色
        ctx.setFillColor(baseColor.cgColor)
        ctx.fill(rect)

        let w = rect.width
        let h = rect.height
        let maxDim = max(w, h)

        // 将每个色块绘制为径向渐变，从饱和色淡出到透明
        for blob in blobs {
            let cx = blob.center.x * w
            let cy = blob.center.y * h
            let radius = blob.radiusRatio * maxDim
            drawBlob(ctx: ctx, cx: cx, cy: cy, radius: radius, color: blob.color, alpha: blob.alpha)
        }
    }

    private func drawBlob(ctx: CGContext, cx: CGFloat, cy: CGFloat,
                          radius: CGFloat, color: UIColor, alpha: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)

        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(red: r, green: g, blue: b, alpha: alpha).cgColor,
            UIColor(red: r, green: g, blue: b, alpha: 0.0).cgColor
        ] as CFArray
        let locs: [CGFloat] = [0.0, 1.0]

        guard let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: locs) else { return }
        let center = CGPoint(x: cx, y: cy)

        ctx.saveGState()
        ctx.drawRadialGradient(gradient,
                               startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius,
                               options: [])
        ctx.restoreGState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    // MARK: - 默认幻彩配置

    /// 返回带默认幻彩色块的实例，可直接用于任意页面背景
    static func makeDefault() -> MeshGradientView {
        let view = MeshGradientView()
        view.baseColor = UIColor(red: 0.990, green: 0.990, blue: 0.995, alpha: 1.0)
        view.blobs = [
            .init(color: UIColor(red: 0.75, green: 0.93, blue: 0.91, alpha: 1),
                  center: CGPoint(x: 0.05, y: 0.08), radiusRatio: 0.62, alpha: 0.55),
            .init(color: UIColor(red: 0.86, green: 0.80, blue: 0.97, alpha: 1),
                  center: CGPoint(x: 0.92, y: 0.05), radiusRatio: 0.55, alpha: 0.50),
            .init(color: UIColor(red: 0.99, green: 0.78, blue: 0.84, alpha: 1),
                  center: CGPoint(x: 0.80, y: 0.42), radiusRatio: 0.50, alpha: 0.38),
            .init(color: UIColor(red: 0.99, green: 0.85, blue: 0.74, alpha: 1),
                  center: CGPoint(x: 0.95, y: 0.82), radiusRatio: 0.58, alpha: 0.42),
            .init(color: UIColor(red: 0.72, green: 0.87, blue: 0.99, alpha: 1),
                  center: CGPoint(x: 0.10, y: 0.88), radiusRatio: 0.52, alpha: 0.48),
            .init(color: UIColor(red: 0.88, green: 0.97, blue: 0.84, alpha: 1),
                  center: CGPoint(x: 0.38, y: 0.22), radiusRatio: 0.40, alpha: 0.30),
            .init(color: UIColor(red: 0.78, green: 0.83, blue: 0.99, alpha: 1),
                  center: CGPoint(x: 0.52, y: 0.70), radiusRatio: 0.45, alpha: 0.28),
        ]
        return view
    }
}
