//
//  UIImage+Resize.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/6/30.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import UIKit

extension UIImage {
    func resizedImage(withBounds bounds: CGSize) -> UIImage {
        let horizontalRatio = bounds.width / size.width // 水平比率，imageView的宽度/原图宽度
        let verticalRatio = bounds.height / size.height // 垂直比率，imageView的高度/原图高度
        let ratio = min(horizontalRatio, verticalRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio) // 按照较小值压缩图片
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
        draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
