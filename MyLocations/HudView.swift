//
//  HudView.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/6/22.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import UIKit

class HudView: UIView {

    var text = ""
    
    class func hud(inView view: UIView, animated: Bool) -> HudView {
        let hudView = HudView(frame: view.bounds) // 初始化一个占据整个屏幕的HUD
        
        hudView.isOpaque = false
        
        view.addSubview(hudView)
        view.isUserInteractionEnabled = false // 出现HUD时，禁止交互行为
        
        // hudView.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        hudView.show(animated: animated)
        return hudView
    }
    
    override func draw(_ rect: CGRect) {
        let boxWidth: CGFloat = 96
        let boxHeight: CGFloat = 96
        
        let boxRect = CGRect(x: round((bounds.size.width - boxWidth) / 2), y: round((bounds.size.height - boxHeight) / 2), width: boxWidth, height: boxHeight) // 在屏幕的正中心构造一个正方形HUD
        print("\(bounds.size.width - boxWidth) - \(bounds.size.height - boxHeight)")
        let roundedRect = UIBezierPath(roundedRect: boxRect, cornerRadius: 10) // 圆角半径为10的正方形
        UIColor(white: 0.3, alpha: 0.8).setFill() // 填充80%不透明度的暗灰色
        roundedRect.fill()
        
        // 放置图片到HUD上
        if let image = UIImage(named: "Checkmark") {
            let imagePoint = CGPoint(x: center.x - round(image.size.width / 2), y: center.y - round(image.size.height / 2) - boxHeight / 8)
            print("\(center.x) - \(center.y)")
            image.draw(at: imagePoint)
        }
        
        // 放置文字到HUD上
        let attribs = [NSFontAttributeName: UIFont.systemFont(ofSize: 16), NSForegroundColorAttributeName: UIColor.white] // 设置字号、前景色
        let textSize = text.size(attributes: attribs)
        let textPoint = CGPoint(x: center.x - round(textSize.width / 2), y: center.y - round(textSize.height / 2) + boxHeight / 4)
        
        text.draw(at: textPoint, withAttributes: attribs)
    }
    
    func show(animated: Bool) {
        if animated {
            alpha = 0
            transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            
            /*
            // 动画从1.3倍HUD尺寸逐渐缩小至原始尺寸，并从全透明逐渐到完全不透明
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 1
                self.transform = CGAffineTransform.identity
            })
            */
            
            // Spring animation
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                self.alpha = 1
                self.transform = CGAffineTransform.identity
            }, completion: nil)
        }
    }
    
}
