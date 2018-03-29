//
//  MainCollectionViewController.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 3. 18..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import UIKit
import Photos
import Kingfisher

private let photoCellreuseIdentifier = "PhotoCell"

private enum FilterType: String {
    case ALL = "ALL"
    case RAW = "RAW"
    case JPG = "JPG"
}

class MainCollectionViewController: UICollectionViewController, UICollectionViewDataSourcePrefetching, UICollectionViewDelegateFlowLayout, URLSessionDownloadDelegate, UIDataSourceModelAssociation {
    
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var storageButton: UIBarButtonItem!
    @IBOutlet var importButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet weak var filterButton: UIBarButtonItem!
    @IBOutlet weak var selectButton: UIBarButtonItem!
    @IBOutlet weak var bottomDescription: UIBarButtonItem!
    
    private var filterType = FilterType.ALL
    private var photos: [PhotoPath]?
    
    private var tasks = [Int: IndexPath]()
    private var importStates = [PhotoPath: ImportState]()
    //private var identifiers = [String]()
    
    private var lastWidth: CGFloat = 0
    private var lastSize = CGSize()
    
    var backgroundSession: URLSession?
    
    var appDelegate: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        filterType = FilterType(rawValue: UserDefaults.standard.string(forKey: "FilterType") ?? FilterType.ALL.rawValue) ?? FilterType.ALL
        filterButton.title = filterType.rawValue
        
        collectionView?.prefetchDataSource = self
        collectionView?.allowsMultipleSelection = true
        bottomDescription.setTitleTextAttributes([.foregroundColor : UIColor.lightText], for: .disabled)
        
        NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: .main) { (notification) in
            self.collectionView?.alpha = 0
        }
        
        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: .main) { (notification) in
            self.collectionView?.alpha = 1
            self.collectionViewLayout.invalidateLayout()
        }
        
        NotificationCenter.default.addObserver(forName: .UIDeviceOrientationDidChange, object: nil, queue: .current) { (notification) in
            self.collectionViewLayout.invalidateLayout()
        }
        
        let sc = URLSessionConfiguration.background(withIdentifier: "kr.inode.pkimport")
        sc.timeoutIntervalForRequest = 10
        backgroundSession = URLSession(configuration: sc, delegate: self, delegateQueue: nil)
        
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        collectionViewLayout.invalidateLayout()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        switch appDelegate.state {
        case .Launch:
            fallthrough
        case .Connect:
            fallthrough
        case .LoadList:
            let vc = storyboard?.instantiateViewController(withIdentifier: "Connect")
            present(vc!, animated: false, completion: nil)
        case .Select:
            break
        case .Import:
            break
        }
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        collectionViewLayout.invalidateLayout()
    }
    
    func grantPhotoAcess(_ status: PHAuthorizationStatus, _ successHandler: @escaping () -> Void) -> Void {
        switch status {
        case .denied:
            fallthrough
        case .restricted:
            // show denied photo
            let alert = UIAlertController(title: "Photos access", message: "Photos access required for operation.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open Settings App", style: .default, handler: { (action) in
                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!)
            }))
            DispatchQueue.main.async {
                self.present(alert, animated: true)
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status) in
                self.grantPhotoAcess(status, successHandler)
            })
        case .authorized:
            DispatchQueue.main.async {
                successHandler()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateUI() {
        storageButton.title = Camera.shared.activeStorage
        
        if appDelegate.state == .Import {
            refreshButton.isEnabled = false
            storageButton.isEnabled = false
            navigationItem.rightBarButtonItem = cancelButton
            filterButton.isEnabled = false
            selectButton.isEnabled = false
            bottomDescription.title = "Importing..."
        } else {
            refreshButton.isEnabled = true
            storageButton.isEnabled = Camera.shared.props?.storages.count ?? 0 > 1
            navigationItem.rightBarButtonItem = importButton
            filterButton.isEnabled = true
            selectButton.isEnabled = true
            
            updateDescription()
        }
    }
    
    func updateDescription() {
        if let list = photos {
            let count = collectionView?.indexPathsForSelectedItems?.count ?? 0
            
            if count > 0 {
                importButton.title = "Import Selected"
                selectButton.title = "Deselect All"
                bottomDescription.title = "\(count) / \(list.count)"
            } else {
                importButton.title = "Import All"
                selectButton.title = "Select All"
                if list.count == 0 {
                    bottomDescription.title = "No Photos"
                } else {
                    bottomDescription.title = "\(list.count)"
                }
            }
        }
    }
    
    @IBAction func connectClosed(segue: UIStoryboardSegue) {
        tasks.removeAll()
        importStates.removeAll()
        reloadPhotos()
        navigationItem.title = Camera.shared.props?.model
        appDelegate.state = .Select
        updateUI()
    }
    
    @IBAction func selectButtonPushed(_ sender: Any) {
        if collectionView?.indexPathsForSelectedItems?.count ?? 0 > 0 {
            // clear selection
            collectionView?.selectItem(at: nil, animated: true, scrollPosition: [])
        } else {
            for i in 0 ..< photos!.count {
                let indexPath = IndexPath(item: i, section: 0)
                if let state = importStates[photos![i]] {
                    if state == .Imported {
                        continue
                    }
                    
                    if state == .Error {
                        importStates[photos![i]] = nil
                        if let cell = collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                            cell.importState = .None
                        }
                    }
                }
                
                collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: [])
            }
        }
        
        updateDescription()
    }
    
    @IBAction func importButtonPushed(_ sender: Any) {
        tasks.removeAll()
        
        grantPhotoAcess(PHPhotoLibrary.authorizationStatus()) {
            let albumName = Camera.shared.props?.model ?? "PK Import"
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "localizedTitle=%@", albumName)
            var result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
            if result.count == 0 {
                // create album
                try? PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                }
                result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
            }
            
            if let collection = result.firstObject {
                let ud = UserDefaults.standard
                ud.set(collection.localIdentifier, forKey: "PHAssetCollectionKey")
                ud.synchronize()
            }
            
            self.appDelegate.state = .Import
            self.updateUI()
            
            Camera.shared.loadProperties(completion: { (props, error) in
                if let error = error {
                    let alert = UIAlertController(title: "ERROR", message: "Connetion to Camera lost.\n\(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Reconnect", style: .default) { (action) in
                        self.performSegue(withIdentifier: "ConnectCamera", sender: nil)
                    })
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                        self.appDelegate.state = .Select
                        self.updateUI()
                    })
                    
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    let selected = self.collectionView?.indexPathsForSelectedItems
                    if selected?.isEmpty ?? true {
                        // import all photos
                        for (idx, photo) in self.photos!.enumerated() {
                            if self.importStates[photo] != .Imported {
                                self.startDownload(photo, indexPath: IndexPath(item: idx, section: 0))
                            }
                        }
                    } else {
                        // import selected photos
                        for indexPath in selected!.sorted() {
                            self.startDownload(self.photos![indexPath.item], indexPath: indexPath)
                        }
                        self.collectionView?.selectItem(at: nil, animated: false, scrollPosition: [])
                    }
                }
            })
            
        }
    }
    
    private func startDownload(_ photo: PhotoPath, indexPath: IndexPath) {
        let task = backgroundSession!.downloadTask(with: photo.downloadURL)
        task.priority = 1.0 - Float(indexPath.item) / Float(photos!.count)
        tasks[task.taskIdentifier] = indexPath
        importStates[photo] = .Selected
        task.resume()
        
        if let cell = collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
            cell.importState = .Selected
        }
    }
    
    @IBAction func cancelButtonPushed(_ sender: Any) {
        backgroundSession?.getTasksWithCompletionHandler({ (dataTasks, updateTasks, downloadTasks) in
            for task in downloadTasks {
                task.cancel()
            }
        })
    }
    
    @IBAction func filterButtonPushed(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: FilterType.ALL.rawValue, style: .default, handler: { (action) in
            self.setFilterType(.ALL)
        }))
        actionSheet.addAction(UIAlertAction(title: FilterType.RAW.rawValue, style: .default, handler: { (action) in
            self.setFilterType(.RAW)
        }))
        actionSheet.addAction(UIAlertAction(title: FilterType.JPG.rawValue, style: .default, handler: { (action) in
            self.setFilterType(.JPG)
        }))
        
        actionSheet.modalPresentationStyle = .popover
        actionSheet.popoverPresentationController?.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        actionSheet.popoverPresentationController?.barButtonItem = filterButton
        actionSheet.view.tintColor = UIColor.orange
        
        present(actionSheet, animated: true)
    }
    
    @IBAction func storageButtonPushed(_ sender: Any) {
        guard let storages = Camera.shared.props?.storages else {
            storageButton.isEnabled = false
            return
        }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for storage in storages {
            actionSheet.addAction(UIAlertAction(title: storage.name, style: .default, handler: { (action) in
                Camera.shared.activeStorage = storage.name
                self.performSegue(withIdentifier: "ConnectCamera", sender: nil)
            }))
        }
        
        actionSheet.modalPresentationStyle = .popover
        actionSheet.popoverPresentationController?.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        actionSheet.popoverPresentationController?.barButtonItem = storageButton
        actionSheet.view.tintColor = UIColor.orange
        
        present(actionSheet, animated: true)
    }
    
    private func setFilterType(_ filterType: FilterType) {
        if self.filterType == filterType {
            // not changed
            return
        }
        
        self.filterType = filterType
        filterButton.title = filterType.rawValue
        
        let ud = UserDefaults.standard
        ud.set(filterType.rawValue, forKey: "FilterType")
        ud.synchronize()
        
        reloadPhotos()
    }
    
    func reloadPhotos() {
        if filterType == .ALL {
            photos = Camera.shared.photos
        } else {
            photos = Camera.shared.photos?.filter({ (photo) -> Bool in
                switch filterType {
                case .ALL:
                    return true
                case .RAW:
                    return !photo.file.hasSuffix(".JPG")
                case .JPG:
                    return photo.file.hasSuffix(".JPG")
                }
            })
        }
        collectionView?.reloadData()
        updateDescription()
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        let encoder = JSONEncoder()
        coder.encode(tasks, forKey: "Tasks")
        coder.encode(try? encoder.encode(importStates), forKey: "States")
        if let offset = collectionView?.contentOffset {
            coder.encode(offset, forKey: "Offset")
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        let decoder = JSONDecoder()
        tasks = coder.decodeObject(forKey: "Tasks") as! [Int : IndexPath]
        importStates = try! decoder.decode([PhotoPath: ImportState].self, from: coder.decodeObject(forKey: "States") as! Data)
        reloadPhotos()
        
        if let offset = coder.decodeObject(forKey: "Offset") as? String {
            collectionView?.contentOffset = CGPointFromString(offset)
        }
        
        super.decodeRestorableState(with: coder)
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ConnectCamera" {
            appDelegate.state = .Connect
            bottomDescription.title = "Connecting..."
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: photoCellreuseIdentifier, for: indexPath) as! PhotoCollectionViewCell
        
        // Configure the cell
        if let photo = photos?[indexPath.item] {
            cell.path = photo
            cell.importState = importStates[photo] ?? .None
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDataSourcePrefetching
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.flatMap { photos?[$0.item].thumbnailURL }
        ImagePrefetcher(urls: urls).start()
    }
    
    // MARK: - UICollectionViewDelegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        updateDescription()
    }
    
    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        updateDescription()
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if appDelegate.state != .Select {
            return false
        }
        
        if let state = importStates[photos![indexPath.item]] {
            if state == .Imported {
                return false
            }
            
            if state == .Error {
                importStates[photos![indexPath.item]] = nil
                if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                    cell.importState = .None
                }
            }
        }
        
        return true
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return appDelegate.state == .Select
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if view.frame.width == lastWidth {
            return lastSize
        }
        
        var count = ceil((view.frame.width - 16) / 160)
        if count < 3 {
            count = 3
        }
        let width = (view.frame.width - 16) / count - 8
        let height = 120 * width / 160
        
        lastWidth = view.frame.width
        lastSize = CGSize(width: width, height: height)
        
        return lastSize
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let indexPath = self.tasks[downloadTask.taskIdentifier] {
            self.importStates[self.photos![indexPath.item]] = .Importing
            DispatchQueue.main.async {
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                    cell.importState = .Importing
                    cell.progressView.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        session.getAllTasks { (tasks) in
            for task in tasks {
                if task.state != .completed {
                    return
                }
            }
            
            DispatchQueue.main.async {
                self.appDelegate.state = .Select
                self.updateUI()
            }
        }
        
        guard let error = error else {
            return
        }
        
        debugPrint("url task fail with \(error)")
        
        if let indexPath = self.tasks[task.taskIdentifier] {
            self.importStates[self.photos![indexPath.item]] = .Error
            DispatchQueue.main.async {
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                    cell.importState = .Error
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // import to photo
        var album: PHAssetCollection? = nil
        if let albumID = UserDefaults.standard.string(forKey: "PHAssetCollectionKey") {
            let albums = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil)
            album = albums.firstObject
        }
        
        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent(downloadTask.currentRequest!.url!.path.replacingOccurrences(of: "/", with: "_"))
        
        do {
            defer {
                try? fm.removeItem(at: dest)
            }
            try fm.moveItem(at: location, to: dest)
            
            try PHPhotoLibrary.shared().performChangesAndWait {
                if let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: dest) {
                    if let a = album, let holder = request.placeholderForCreatedAsset {
                        PHAssetCollectionChangeRequest(for: a)?.addAssets([holder] as NSArray)
                    }
                }
            }
        } catch {
            debugPrint(error)
        }
        
        if let indexPath = self.tasks[downloadTask.taskIdentifier] {
            self.importStates[self.photos![indexPath.item]] = .Imported
            DispatchQueue.main.async {
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                    cell.importState = .Imported
                }
            }
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        debugPrint("FINISHED")
        
        DispatchQueue.main.async {
            let appDelegate = self.appDelegate
            appDelegate.state = .Select
            
            if let completionHandler = appDelegate.backgroundCompletionHandler {
                completionHandler()
                appDelegate.backgroundCompletionHandler = nil
            }
        }
    }
    
    // MARK: - UIDataSourceModelAssociation
    
    func modelIdentifierForElement(at idx: IndexPath, in view: UIView) -> String? {
        return photos?[idx.item].identifier
    }
    
    func indexPathForElement(withModelIdentifier identifier: String, in view: UIView) -> IndexPath? {
        guard let idx = photos?.index(of: PhotoPath(identifier: identifier)) else {
            return nil
        }
        
        return IndexPath(item: idx, section: 0)
    }
    
}
