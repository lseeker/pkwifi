//
//  Camera.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 3. 15..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation

class Camera {
    private static let instance = Camera()
    
    class var shared: Camera {
        get {
            return instance
        }
    }

    var props: CameraProperties?
    var photos: [PhotoPath]?
    private var _activeStorage: String?
    var activeStorage: String? {
        get {
            if let storage = _activeStorage {
                return storage
            }
            
            guard let props = props else {
                return nil
            }
            
            for storage in props.storages {
                if storage.active {
                    return storage.name
                }
            }
            
            return props.storages.first?.name
        }
        set {
            _activeStorage = newValue
        }
    }
    
    private init() { }
    
    private var task: URLSessionDataTask?
    
    func loadProperties(completion: ((_ props: CameraProperties?, _ error: Error?) -> Void)?) {
        task?.cancel()
        
        let sc = URLSessionConfiguration.ephemeral
        sc.timeoutIntervalForRequest = 3
        
        task = URLSession(configuration: sc).dataTask(with: URL(string:"http://192.168.0.1/v1/props")!) { (data, response, error) in
            if error != nil {
                completion?(nil, error)
                return
            }
            
            guard let result = try? JSONDecoder().decode(CameraProperties.self, from: data!) else {
                completion?(nil, CameraError.invalidResult)
                return
            }

            let fm = FileManager.default
            var asd = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            asd.appendPathComponent("CameraProperties.json")
            try? data?.write(to: asd)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? asd.setResourceValues(resourceValues)

            self.props = result
            self.task = nil
            completion?(result, nil)
        }
        task?.resume()
    }
    
    func loadList(completion: ((_ list: [PhotoPath]?, _ error: Error?) -> Void)?) {
        task?.cancel()

        let sc = URLSessionConfiguration.ephemeral
        sc.timeoutIntervalForRequest = 5

        var query = ""
        if let storage = activeStorage {
            query = "?storage=\(storage)"
        }

        task = URLSession(configuration: sc).dataTask(with: URL(string: "http://192.168.0.1/v1/photos\(query)")!) { (data, response, error) in
            if error != nil {
                completion?(nil, error)
                return
            }
            
            guard let result = try? JSONDecoder().decode(PhotoListResponse.self, from: data!) else {
                completion?(nil, CameraError.invalidResult)
                return
            }
            
            let fm = FileManager.default
            var asd = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            asd.appendPathComponent("PhotosList.json")
            try? data?.write(to: asd)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? asd.setResourceValues(resourceValues)

            self.photos = result.photos
            self.task = nil
            completion?(result.photos, nil)
        }
        task?.resume()
    }
    
    func loadFromFile(withPhotoList: Bool) throws {
        let fm = FileManager.default
        let decoder = JSONDecoder()

        let asd = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        props = try decoder.decode(CameraProperties.self, from: Data(contentsOf: asd.appendingPathComponent("CameraProperties.json")))
        
        if withPhotoList {
            photos = try decoder.decode(PhotoListResponse.self, from: Data(contentsOf: asd.appendingPathComponent("PhotosList.json"))).photos
        }
    }
}
