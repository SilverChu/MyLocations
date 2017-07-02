//
//  MyTabBarController.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/7/2.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import UIKit

class MyTabBarController: UITabBarController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var childViewControllerForStatusBarStyle: UIViewController? {
        return nil
    }
}
