//
//  String+AddText.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/7/2.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import Foundation

extension String {
    mutating func add(text: String?, separatedBy separator: String = "") {
        if let text = text {
            if !isEmpty {
                self += separator
            }
            self += text
        }
    }
}
