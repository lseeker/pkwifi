//
//  PhotoCellData.swift
//  pkimport
//
//  Created by YUN YOUNG LEE on 2018. 3. 26..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation

enum PhotoCellState: Int, Codable {
    case Select
    case Ready
    case Importing
    case Imported
    case Error
}

class PhotoCellData: Codable {
    let photoPath: PhotoPath
    var state = PhotoCellState.Select
    var assetIdentifier: String?

    init(photoPath: PhotoPath) {
        self.photoPath = photoPath
    }
}
