//
//  UIViewController+MeshBackground.swift
//  Slidesh
//

import UIKit

extension UIViewController {

    /// 为当前 VC 添加默认幻彩渐变背景，插入到所有子视图下方
    func addMeshGradientBackground() {
        let mesh = MeshGradientView.makeDefault()
        mesh.frame = view.bounds
        mesh.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(mesh, at: 0)
    }
}
