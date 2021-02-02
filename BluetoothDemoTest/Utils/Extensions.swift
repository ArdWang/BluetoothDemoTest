//
//  Extensions.swift
//  BluetoothDemoTest
//
//  Created by RND on 2021/2/2.
//

import Foundation

extension Data {
    func toIntArray() -> [Int] {
        return self.map{ Int($0) }
    }
}
