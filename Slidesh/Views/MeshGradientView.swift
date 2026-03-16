//
//  MeshGradientView.swift
//  Slidesh
//
//  用多个径向渐变色块叠加，模拟网格渐变/幻彩晕染效果
//  通过 traitCollectionDidChange 和 ThemeManager 通知响应深浅色切换
//

import UIKit

class MeshGradientView: UIView {

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

    var baseColor: UIColor = UIColor(red: 0.992, green: 0.992, blue: 0.996, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        observeTheme()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = true
        observeTheme()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 主题通知监听

    private func observeTheme() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    @objc private func themeChanged() {
        // ThemeManager 切换后重新应用配置并重绘
        applyDefaultConfig()
        setNeedsDisplay()
    }

    // MARK: - Trait 变化（跟随系统时生效）

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            applyDefaultConfig()
            setNeedsDisplay()
        }
    }

    // MARK: - 绘制

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setFillColor(baseColor.cgColor)
        ctx.fill(rect)

        let w = rect.width
        let h = rect.height
        let maxDim = max(w, h)

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

        guard let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0]) else { return }
        let center = CGPoint(x: cx, y: cy)
        ctx.saveGState()
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius, options: [])
        ctx.restoreGState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    // MARK: - 默认配置（深浅色各一套）

    /// 根据当前 traitCollection 应用对应色块配置
    func applyDefaultConfig() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        baseColor = isDark
            ? UIColor(red: 0.031, green: 0.059, blue: 0.118, alpha: 1.0)   // 深色底 #08101E
            : UIColor(red: 0.990, green: 0.990, blue: 0.995, alpha: 1.0)   // 浅色底

        blobs = isDark ? Self.darkBlobs : Self.lightBlobs
    }

    /// 返回自动适配深浅色的默认实例
    static func makeDefault() -> MeshGradientView {
        let view = MeshGradientView()
        view.applyDefaultConfig()
        return view
    }

    // MARK: - 浅色色块

    private static let lightBlobs: [Blob] = [
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

    // MARK: - 深色色块（更深沉、偏冷蓝紫调）

    private static let darkBlobs: [Blob] = [
        .init(color: UIColor(red: 0.10, green: 0.30, blue: 0.60, alpha: 1),
              center: CGPoint(x: 0.05, y: 0.08), radiusRatio: 0.62, alpha: 0.35),
        .init(color: UIColor(red: 0.20, green: 0.10, blue: 0.50, alpha: 1),
              center: CGPoint(x: 0.92, y: 0.05), radiusRatio: 0.55, alpha: 0.30),
        .init(color: UIColor(red: 0.40, green: 0.10, blue: 0.35, alpha: 1),
              center: CGPoint(x: 0.80, y: 0.42), radiusRatio: 0.50, alpha: 0.25),
        .init(color: UIColor(red: 0.30, green: 0.15, blue: 0.10, alpha: 1),
              center: CGPoint(x: 0.95, y: 0.82), radiusRatio: 0.58, alpha: 0.28),
        .init(color: UIColor(red: 0.05, green: 0.25, blue: 0.50, alpha: 1),
              center: CGPoint(x: 0.10, y: 0.88), radiusRatio: 0.52, alpha: 0.32),
        .init(color: UIColor(red: 0.10, green: 0.35, blue: 0.25, alpha: 1),
              center: CGPoint(x: 0.38, y: 0.22), radiusRatio: 0.40, alpha: 0.20),
        .init(color: UIColor(red: 0.15, green: 0.15, blue: 0.45, alpha: 1),
              center: CGPoint(x: 0.52, y: 0.70), radiusRatio: 0.45, alpha: 0.22),
    ]
}
