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

    // 中间圆角矩形按钮容器
    private var centerIconView: UIView?

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

    // MARK: - 中间圆角矩形渐变按钮

    private func setupGradientCenterIcon() {
        centerIconView?.removeFromSuperview()

        let buttonW: CGFloat = 54
        let buttonH: CGFloat = 36
        let cornerRadius: CGFloat = 12

        let tabWidth = tabBar.bounds.width / 5
        let centerX = tabWidth * 2.5

        // 对齐其他图标的垂直中心
        var iconCenterY: CGFloat = tabBar.bounds.height * 0.38
        for subview in tabBar.subviews {
            let className = String(describing: type(of: subview))
            if className.contains("TabBarButton") {
                for itemSubview in subview.subviews {
                    if let imgView = itemSubview as? UIImageView, imgView.image != nil {
                        let itemMidY = subview.frame.minY + itemSubview.frame.midY
                        iconCenterY = itemMidY
                        break
                    }
                }
                break
            }
        }

        // 圆角矩形容器
        let container = UIView(frame: CGRect(
            x: centerX - buttonW / 2,
            y: iconCenterY - buttonH / 2,
            width: buttonW,
            height: buttonH
        ))
        container.layer.cornerRadius = cornerRadius
        container.clipsToBounds = true
        container.isUserInteractionEnabled = true

        // VIP 卡片同款渐变（深蓝 → 中蓝 → 浅蓝）
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.039, green: 0.094, blue: 0.260, alpha: 1).cgColor,
            UIColor(red: 0.180, green: 0.380, blue: 0.720, alpha: 1).cgColor,
            UIColor(red: 0.471, green: 0.710, blue: 0.953, alpha: 1).cgColor,
        ]
        gradientLayer.locations = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.frame      = CGRect(origin: .zero, size: CGSize(width: buttonW, height: buttonH))
        container.layer.insertSublayer(gradientLayer, at: 0)

        // 白色加号图标居中
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let plusImage = UIImage(systemName: "plus", withConfiguration: symbolConfig)
        let plusView = UIImageView(image: plusImage)
        plusView.tintColor = .white
        plusView.contentMode = .scaleAspectFit
        plusView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(plusView)
        NSLayoutConstraint.activate([
            plusView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            plusView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(centerIconTapped))
        container.addGestureRecognizer(tap)

        tabBar.addSubview(container)
        centerIconView = container
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
