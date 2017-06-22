//
//  Functions.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/6/22.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import Foundation
import Dispatch

// @escaping 逃逸闭包，在方法返回后才会被调用
func afterDelay(_ seconds: Double, closure: @escaping () -> ()) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: closure)
}
