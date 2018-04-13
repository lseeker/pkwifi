//
//  CameraProperties.swift
//  pkimport
//
//  Created by YUN YOUNG LEE on 2018. 3. 24..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation

struct CameraProperties: Decodable {
    let model: String
    let ssid: String
    let key: String
    let storages: [Storage]
    
    struct Storage: Decodable {
        let name: String
        let active: Bool
    }
}
