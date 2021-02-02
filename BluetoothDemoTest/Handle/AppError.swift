//
//  AppError.swift
//  BluetoothDemoTest
//
//  Created by RND on 2021/2/2.
//
import Foundation
import SwiftUI

enum AppError: Error, Identifiable {
    var id: String {
        localizedDescription
    }
    
    case deviceConnectFail
    case unknown
}


extension AppError: LocalizedError {
    var localizedDescription: LocalizedStringKey{
        switch self {
        case .deviceConnectFail: return "Device connect Fail"
        default: return "Unknown error"
        }
    }
}


