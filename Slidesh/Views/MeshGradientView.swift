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
}
