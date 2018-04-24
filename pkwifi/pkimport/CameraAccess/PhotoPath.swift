//
//  PhotoFile.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 3. 15..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation
import UIKit

class PhotoPath: Codable, Hashable
{
    let dir: String
    let file: String
    var assetIdentifier: String?
    
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
            var query = "size="
            if file.hasSuffix(".AVI") || file.hasSuffix(".MOV") {
                query += "view"
            } else {
                query += "thumb"
            }
            if let storage = Camera.shared.activeStorage {
                query += "&storage=\(storage)"
            }
            return URL(string: "http://\(Camera.IP)/v1/photos/\(dir)/\(file)?\(query)")!
        }
    }
    
    var downloadURL: URL {
        get {
            var query = ""
            if let storage = Camera.shared.activeStorage {
                query = "&storage=\(storage)"
            }
            return URL(string: "http://\(Camera.IP)/v1/photos/\(dir)/\(file)?size=full\(query)")!
        }
    }
    
    var hashValue: Int {
        get { return dir.hashValue ^ file.hashValue &* 16777619 }
    }
    
    static func == (lhs: PhotoPath, rhs: PhotoPath) -> Bool {
        if lhs.hashValue != rhs.hashValue {
            return false
        }
        
        return lhs.dir == rhs.dir && lhs.file == rhs.file
    }
}
