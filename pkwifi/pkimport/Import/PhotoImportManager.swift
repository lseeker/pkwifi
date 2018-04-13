//
//  PhotoImportManager.swift
//  pkimport
//
//  Created by YUN YOUNG LEE on 2018. 4. 12..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import Foundation
import Photos
import UserNotifications

protocol PhotoImportManagerDelegate
{
    func importing(_ photoPath: PhotoPath, progress: Progress)
    func imported(_ photoPath: PhotoPath)
    func importCancelled(_ photoPath: PhotoPath)
    func importErrorOccurred(_ photoPath: PhotoPath, error: Error)
    func importFinished()
}

class PhotoImportManager: NSObject, URLSessionDownloadDelegate {
    private static let instance = PhotoImportManager()
    class var shared: PhotoImportManager {
        get {
            return instance
        }
    }
    
    private var backgroundSession: URLSession!
    private var tasks = [Int : PhotoPath]()
    var delegate: PhotoImportManagerDelegate? {
        didSet {
            // create urlsession here for delegation works on restored condition
            let sc = URLSessionConfiguration.background(withIdentifier: "kr.inode.pkimport")
            sc.httpMaximumConnectionsPerHost = 2 // set to 2, but not works cause access by ip
            sc.timeoutIntervalForRequest = 10
            sc.shouldUseExtendedBackgroundIdleMode = true
            backgroundSession = URLSession(configuration: sc, delegate: self, delegateQueue: nil)
        }
    }
    
    private override init() {
        super.init()
    }
    
    func beginImport(_ photoPath: PhotoPath) {
        let task = backgroundSession.downloadTask(with: photoPath.downloadURL)
        task.priority = URLSessionTask.highPriority
        tasks[task.taskIdentifier] = photoPath
        task.resume()
    }
    
    func cancel() {
        backgroundSession.getTasksWithCompletionHandler({ (dataTasks, updateTasks, downloadTasks) in
            for task in downloadTasks {
                task.cancel()
            }
        })
    }
    
    // MARK: - URLSessionDownloadDelegate
    // all delegate methods are run on serialized queue
    // photoimportdelegate should call on main thread
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let photoPath = tasks[downloadTask.taskIdentifier] {
            DispatchQueue.main.async {
                self.delegate?.importing(photoPath, progress: downloadTask.progress)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, let photoPath = tasks[task.taskIdentifier] {
            debugPrint("url task fail with \(error)")
            if let urlError = error as? URLError, urlError.code == URLError.cancelled {
                DispatchQueue.main.async {
                    self.delegate?.importCancelled(photoPath)
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.importErrorOccurred(photoPath, error: error)
                }
            }
        }
        
        tasks.removeValue(forKey: task.taskIdentifier)
        if tasks.isEmpty {
            DispatchQueue.main.async {
                self.delegate?.importFinished()
            }
        }
    }
    
    private func createAsset(_ location: URL, _ filename: String, photosChangeHandler: ((_ placeHolder: PHObjectPlaceholder?, _ error: Error?) -> Void)!) {
        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            defer {
                try? fm.removeItem(at: dest)
            }
            try fm.moveItem(at: location, to: dest)
            
            try PHPhotoLibrary.shared().performChangesAndWait {
                if dest.pathExtension == "AVI" || dest.pathExtension == "MOV" {
                    if let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: dest),
                        let placeHolder = request.placeholderForCreatedAsset {
                        photosChangeHandler(placeHolder, nil)
                    }
                } else {
                    if let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: dest),
                        let placeHolder = request.placeholderForCreatedAsset {
                        photosChangeHandler(placeHolder, nil)
                    }
                }
            }
        } catch {
            debugPrint("photo asset creation fail: \(error)")
            photosChangeHandler(nil, error)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // import to photo
        var album: PHAssetCollection? = nil
        if let albumID = UserDefaults.standard.string(forKey: "PHAssetCollectionKey") {
            album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject
        }
        
        guard let photoPath = tasks[downloadTask.taskIdentifier] else {
            // no photo path - should not occur
            createAsset(location, downloadTask.originalRequest!.url!.lastPathComponent) { (placeHolder, error) in
                guard let placeHolder = placeHolder else {
                    return
                }
                
                if let album = album {
                    PHAssetCollectionChangeRequest(for: album)?.addAssets([placeHolder] as NSArray)
                }
            }
            return
        }
        
        createAsset(location, photoPath.file) { (placeHolder, error) in
            guard let placeHolder = placeHolder else {
                DispatchQueue.main.async {
                    self.delegate?.importErrorOccurred(photoPath, error: error!)
                }
                return
            }
            
            // set identifier on current photo
            photoPath.assetIdentifier = placeHolder.localIdentifier
            
            defer {
                DispatchQueue.main.async {
                    self.delegate?.imported(photoPath)
                }
            }
            
            guard let album = album else {
                return
            }
            
            // find position on album
            let identifiers = Camera.shared.photos!.compactMap({ (photoPath) -> String? in
                return photoPath.assetIdentifier
            })
            let pos = identifiers.index(of: placeHolder.localIdentifier)!
            
            let assets = PHAsset.fetchAssets(in: album, options: nil)
            if assets.count == 0 {
                PHAssetCollectionChangeRequest(for: album)?.addAssets([placeHolder] as NSArray)
                return
            }
            var insertPos = assets.count
            assets.enumerateObjects(options: .reverse, using: { (asset, index, stop) in
                if let p = identifiers.index(of: asset.localIdentifier) {
                    if p > pos {
                        insertPos = index
                    } else {
                        // p < pos
                        insertPos = index + 1
                        stop.pointee = true
                    }
                }
            })
            PHAssetCollectionChangeRequest(for: album, assets: assets)?.insertAssets([placeHolder] as NSArray, at: IndexSet(integer: insertPos))
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.state = .Select
            
            if let completionHandler = appDelegate.backgroundCompletionHandler {
                completionHandler()
                appDelegate.backgroundCompletionHandler = nil
            }
            
            let notiCenter = UNUserNotificationCenter.current()
            notiCenter.getNotificationSettings(completionHandler: { (settings) in
                if settings.authorizationStatus == .authorized {
                    let content = UNMutableNotificationContent()
                    content.title = NSLocalizedString("Import finished", comment: "import finish notification")
                    content.sound = UNNotificationSound.default()
                    content.badge = 1
                    
                    notiCenter.add(UNNotificationRequest(identifier: "kr.inode.pkimport", content: content, trigger: nil))
                }
            })
        }
    }
    
}
