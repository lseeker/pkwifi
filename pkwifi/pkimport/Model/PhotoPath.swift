//
//  PhotoFile.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 3. 15..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation
import UIKit

struct PhotoPath: Hashable, Codable
{
    let dir: String
    let file: String
    
    init(dir: String, file: String) {
        self.dir = dir
        self.file = file
    }
    
    init(identifier: String) {
        let splited = identifier.split(separator: "*")
        dir = String(splited[0])
        file = String(splited[1])
    }
    
    var identifier: String {
        get {
            return "\(dir)*\(file)"
        }
    }
    
    var thumbnailURL: URL {
        get {
            var query = ""
            if let storage = Camera.shared.activeStorage {
                query = "&storage=\(storage)"
            }
            return URL(string: "http://192.168.0.1/v1/photos/\(dir)/\(file)?size=thumb\(query)")!
        }
    }
    
    var downloadURL: URL {
        get {
            var query = ""
            if let storage = Camera.shared.activeStorage {
                query = "&storage=\(storage)"
            }
            return URL(string: "http://192.168.0.1/v1/photos/\(dir)/\(file)?size=full\(query)")!
        }
    }
}
