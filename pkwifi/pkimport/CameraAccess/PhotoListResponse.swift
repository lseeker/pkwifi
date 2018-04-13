//
//  PhotoListResponse.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 3. 19..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation

struct PhotoListResponse: Decodable {
    let photos: [PhotoPath]
    
    struct Dirs: Decodable {
        let name: String
        let files: [String]
    }
    
    enum CodingKeys: String, CodingKey {
        case dirs
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let dirs = try values.decode([Dirs].self, forKey: .dirs)
        
        var count = 0
        var photos = [PhotoPath]()

        for dir in dirs {
            count += dir.files.count
        }
        photos.reserveCapacity(count)
        
        for dir in dirs {
            for file in dir.files {
                photos.append(PhotoPath(dir: dir.name, file: file))
            }
        }
        
        self.photos = photos
    }
}
