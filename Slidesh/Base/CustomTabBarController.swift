//
//  CustomTabBarController.swift
//  Slidesh
//
//  Created by ted on 2026/3/16.
//

import UIKit

// 自定义 TabBar 控制器：5个 Tab，中间 Tab 为特殊渐变按钮，点击弹出新建页面
class CustomTabBarController: UITabBarController, UITabBarControllerDelegate {

    // 极轻毛玻璃效果，避免遮盖背景渐变色
    private let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
    private lazy var blurEffectView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: blurEffect)
        view.alpha = 0.55
        view.frame = tabBar.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()

    // 中间渐变图标
    private var centerIconView: UIImageView?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        setupTabBar()
        setupTabBarItems()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 布局完成后再设置渐变图标，避免位置偏差
        DispatchQueue.main.async {
            self.setupGradientCenterIcon()
        }
    }

    // MARK: - Tab 配置

    private func setupTabBarItems() {
        // Tab 1: 模板
        let templatesVC = TemplatesViewController()
        templatesVC.tabBarItem = UITabBarItem(
            title: "",
            image: UIImage(systemName: "square.grid.2x2"),
            selectedImage: UIImage(systemName: "square.grid.2x2.fill")
        )

        // Tab 2: 格式转换
        let convertVC = ConvertViewController()
        convertVC.tabBarItem = UITabBarItem(
            title: "",
            image: UIImage(systemName: "arrow.left.arrow.right"),
            selectedImage: UIImage(systemName: "arrow.left.arrow.right.circle.fill")
        )

        // Tab 3: 新建（透明占位，实际显示渐变 + 按钮）
        let placeholderVC = UIViewController()
        placeholderVC.tabBarItem = UITabBarItem(title: "", image: UIImage(), selectedImage: UIImage())

        // Tab 4: 我的作品
        let myWorksVC = MyWorksViewController()
        myWorksVC.tabBarItem = UITabBarItem(
            title: "",
            image: UIImage(systemName: "folder"),
            selectedImage: UIImage(systemName: "folder.fill")
        )

        // Tab 5: 设置
        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(
            title: "",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        // 每个 VC 包装进自定义导航控制器
        viewControllers = [templatesVC, convertVC, placeholderVC, myWorksVC, settingsVC].map {
            CustomNavigationController(rootViewController: $0)
        }
    }

    // MARK: - 中间渐变图标

    private func setupGradientCenterIcon() {
        centerIconView?.removeFromSuperview()

        // 使用 SF Symbol "plus" 作为中间图标
        let config = UIImage.SymbolConfiguration(weight: .semibold)
        guard let iconImage = UIImage(systemName: "plus", withConfiguration: config) else { return }

        // 动态获取其他 TabBar 图标的位置和尺寸
        var iconSize: CGFloat = 26
        var iconY: CGFloat = 14
        let tabWidth = tabBar.bounds.width / 5
        let centerX = tabWidth * 2.5

        for subview in tabBar.subviews {
            let className = String(describing: type(of: subview))
            if className.contains("TabBarButton") {
                for itemSubview in subview.subviews {
                    if let imgView = itemSubview as? UIImageView, imgView.image != nil {
                        iconSize = max(itemSubview.frame.width, itemSubview.frame.height)
                        iconY = subview.frame.minY + itemSubview.frame.minY
                        break
                    }
                }
                break
            }
        }

        // 将图标渲染为主色系渐变
        let gradientImage = createGradientImage(from: iconImage, size: CGSize(width: iconSize, height: iconSize))

        let imageView = UIImageView(image: gradientImage)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(centerIconTapped))
        imageView.addGestureRecognizer(tap)

        imageView.frame = CGRect(
            x: centerX - iconSize / 2,
            y: iconY,
            width: iconSize,
            height: iconSize
        )

        tabBar.addSubview(imageView)
        centerIconView = imageView
    }

    // 将图标渲染为主色系渐变（亮蓝 → 深宝蓝 → 蓝紫）
    private func createGradientImage(from image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        let colors = [
            UIColor(red: 0.18, green: 0.60, blue: 1.00, alpha: 1.0).cgColor,  // #2E99FF 亮蓝
            UIColor(red: 0.024, green: 0.251, blue: 0.678, alpha: 1.0).cgColor, // #0640AD 主色
            UIColor(red: 0.22, green: 0.10, blue: 0.82, alpha: 1.0).cgColor   // #381AD1 蓝紫
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = [0.0, 0.5, 1.0]

        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: locations
        ) else {
            UIGraphicsEndImageContext()
            return nil
        }

        // 翻转坐标系并以图标形状为蒙版
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        if let cgImage = image.cgImage {
            context.clip(to: CGRect(origin: .zero, size: size), mask: cgImage)
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )

        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return gradientImage
    }

    // 中间按钮点击：弹出新建页面
    @objc private func centerIconTapped() {
        // 点击弹性动画
        UIView.animate(withDuration: 0.1, animations: {
            self.centerIconView?.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        }) { _ in
            UIView.animate(withDuration: 0.12) {
                self.centerIconView?.transform = .identity
            }
        }

        // 全屏弹出新建页面
        let newVC = NewProjectViewController()
        let navVC = CustomNavigationController(rootViewController: newVC)
        navVC.modalPresentationStyle = .fullScreen
        present(navVC, animated: true)
    }

    // MARK: - TabBar 外观

    private func setupTabBar() {
        // 透明背景 + 极轻毛玻璃，保留底部内容渐变穿透感
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.backgroundColor = .clear
        tabBar.insertSubview(blurEffectView, at: 0)

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()

        appearance.stackedLayoutAppearance.normal.iconColor = .appTabBarUnselected
        appearance.stackedLayoutAppearance.selected.iconColor = .appTabBarSelected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.appTabBarUnselected
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.appTabBarSelected
        ]

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }

        tabBar.tintColor = .appTabBarSelected
        tabBar.unselectedItemTintColor = .appTabBarUnselected
    }

    // MARK: - UITabBarControllerDelegate

    // 拦截中间 Tab 点击，不切换页面，改为弹出
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let index = viewControllers?.firstIndex(of: viewController) else { return true }
        if index == 2 {
            centerIconTapped()
            return false
        }
        return true
    }
}
