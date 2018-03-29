//
//  ImportInfo.swift
//  pkimport
//
//  Created by YUN YOUNG LEE on 2018. 3. 26..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation

enum ImportState: Int, Codable {
    case None
    case Selected
    case Importing
    case Imported
    case Error
}

class ImportInfo: Codable {
    let photo: PhotoPath
    var state = ImportState.None
    //var order = 0
    //var assetIdentifier: String?
    
    init(photo: PhotoPath) {
        self.photo = photo
    }
}
