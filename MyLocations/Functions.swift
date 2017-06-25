//
//  Functions.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/6/22.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import Foundation
import Dispatch

// 获取APP全路径地址
let applicationDocumentsDirectory: URL = {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    
    return paths[0]
}()

// @escaping 逃逸闭包，在方法返回后才会被调用
func afterDelay(_ seconds: Double, closure: @escaping () -> ()) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: closure)
}

// 处理Core Data错误
let MyManagedObjectContextSaveDidFailNotification = Notification.Name(rawValue: "MyManagedObjectContextSaveDidFailNotification")

func fatalCoreDataError(_ error: Error) {
    print("*** Fatal error: \(error)")
    
    NotificationCenter.default.post(name: MyManagedObjectContextSaveDidFailNotification, object: nil)
}
