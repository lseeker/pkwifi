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
    
    private var cellDataArray = [PhotoCellData]()
    private var tasks = [Int: IndexPath]()
    private var filtered = [PhotoCellData]()
    
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
        sc.httpMaximumConnectionsPerHost = 2 // set to 2, but not works cause access by ip
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
            let alert = UIAlertController(title: NSLocalizedString("Photos access", comment: "Photo denied alert title"), message: NSLocalizedString("Photos access required for operation.", comment: "Photo denied alert message"), preferredStyle: .alert)
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
            bottomDescription.title = NSLocalizedString("Importing...", comment: "description title")
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
        let count = collectionView?.indexPathsForSelectedItems?.count ?? 0
        
        if count > 0 {
            importButton.title = NSLocalizedString("Import Selected", comment: "import button title")
            selectButton.title = NSLocalizedString("Deselect All", comment: "select button title")
            bottomDescription.title = "\(count) / \(filtered.count)"
        } else {
            importButton.title = NSLocalizedString("Import All", comment: "import button title")
            selectButton.title = NSLocalizedString("Select All", comment: "select button title")
            if filtered.isEmpty {
                bottomDescription.title = NSLocalizedString("No Photos", comment: "description title")
            } else {
                bottomDescription.title = "\(filtered.count)"
            }
        }
    }
    
    @IBAction func connectClosed(segue: UIStoryboardSegue) {
        tasks.removeAll()
        reloadPhotos()
        navigationItem.title = Camera.shared.props?.model
        appDelegate.state = .Select
        updateUI()
    }
    
    @IBAction func selectButtonPushed(_ sender: Any) {
        if collectionView?.indexPathsForSelectedItems?.isEmpty ?? true {
            for (idx, cellData) in filtered.enumerated() {
                if cellData.state != .Imported {
                    collectionView?.selectItem(at: IndexPath(item: idx, section: 0), animated: true, scrollPosition: [])
                }
            }
        } else {
            // clear selection
            collectionView?.selectItem(at: nil, animated: true, scrollPosition: [])
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
                    let alert = UIAlertController(title: NSLocalizedString("ERROR", comment: "alert title on import"), message: NSLocalizedString("Connetion to Camera lost.", comment: "alert message on import").appending("\n\(error.localizedDescription)"), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("Reconnect", comment: "alert button on import error"), style: .default) { (action) in
                        self.performSegue(withIdentifier: "ConnectCamera", sender: nil)
                    })
                    alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "alert button on import error"), style: .cancel) { (action) in
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
                        for (idx, photo) in self.filtered.enumerated() {
                            if photo.state != .Imported {
                                self.startDownload(photo, indexPath: IndexPath(item: idx, section: 0))
                            }
                        }
                    } else {
                        // import selected photos
                        for indexPath in selected!.sorted() {
                            self.startDownload(self.filtered[indexPath.item], indexPath: indexPath)
                        }
                        // clean up selection for futher states change
                        self.collectionView?.selectItem(at: nil, animated: false, scrollPosition: [])
                    }
                }
            })
            
        }
    }
    
    private func startDownload(_ photo: PhotoCellData, indexPath: IndexPath) {
        let task = backgroundSession!.downloadTask(with: photo.photoPath.downloadURL)
        task.priority = URLSessionTask.highPriority
        tasks[task.taskIdentifier] = indexPath
        photo.state = .Ready
        task.resume()
        
        if let cell = collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
            cell.update()
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
        
        applyFilter()
    }
    
    func reloadPhotos() {
        cellDataArray.removeAll()
        
        if let photoPaths = Camera.shared.photos {
            cellDataArray.reserveCapacity(photoPaths.count)
            
            for photoPath in photoPaths {
                cellDataArray.append(PhotoCellData(photoPath: photoPath))
            }
        }
        
        applyFilter()
    }
    
    func applyFilter() {
        switch filterType {
        case .ALL:
            filtered = cellDataArray
        case .RAW:
            filtered = cellDataArray.filter({ (cellData) -> Bool in
                return !cellData.photoPath.file.hasSuffix(".JPG")
            })
        case .JPG:
            filtered = cellDataArray.filter({ (cellData) -> Bool in
                return cellData.photoPath.file.hasSuffix(".JPG")
            })
        }
        
        collectionView?.reloadData()
        updateDescription()
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        let encoder = JSONEncoder()
        coder.encode(tasks, forKey: "Tasks")
        coder.encode(try? encoder.encode(cellDataArray), forKey: "CellDataArray")
        if let offset = collectionView?.contentOffset {
            coder.encode(offset, forKey: "Offset")
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        let decoder = JSONDecoder()
        tasks = coder.decodeObject(forKey: "Tasks") as! [Int : IndexPath]
        cellDataArray = try! decoder.decode([PhotoCellData].self, from: coder.decodeObject(forKey: "CellDataArray") as! Data)
        applyFilter()
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
            bottomDescription.title = NSLocalizedString("Connecting...", comment: "description title")
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filtered.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: photoCellreuseIdentifier, for: indexPath) as! PhotoCollectionViewCell
        
        // Configure the cell
        cell.cellData = filtered[indexPath.item]
        
        return cell
    }
    
    // MARK: - UICollectionViewDataSourcePrefetching
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.map { filtered[$0.item].photoPath.thumbnailURL }
        ImagePrefetcher(urls: urls).start()
    }
    
    // MARK: - UICollectionViewDelegate
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // update cell for unvisible state changes
        if let cell = cell as? PhotoCollectionViewCell {
            cell.update()
        }
    }
    
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
        
        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
            if cell.cellData?.state == .Imported {
                return false
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
            DispatchQueue.main.async {
                self.filtered[indexPath.item].state = .Importing
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                    cell.update()
                    cell.progressView.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, let indexPath = self.tasks[task.taskIdentifier] {
            debugPrint("url task fail with \(error)")
            DispatchQueue.main.async {
                self.filtered[indexPath.item].state = .Error
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                    cell.update()
                }
            }
        }
        
        tasks.removeValue(forKey: task.taskIdentifier)
        if tasks.isEmpty {
            DispatchQueue.main.async {
                self.appDelegate.state = .Select
                self.updateUI()
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
                        if let indexPath = self.tasks[downloadTask.taskIdentifier] {
                            let currentPhoto = self.filtered[indexPath.item]
                            // set identifier
                            currentPhoto.assetIdentifier = holder.localIdentifier
                            
                            let identifiers = self.cellDataArray.compactMap({ (cellData) -> String? in
                                return cellData.assetIdentifier
                            })
                            let pos = identifiers.index(of: holder.localIdentifier)!
                            let assets = PHAsset.fetchAssets(in: a, options: nil)
                            var insertPos = assets.count
                            if assets.count > 0 && !identifiers.isEmpty {
                                assets.enumerateObjects({ (asset, idx, stop) in
                                    if let p = identifiers.index(of: asset.localIdentifier) {
                                        if p < pos {
                                            insertPos = idx + 1
                                        } else {
                                            // p > pos
                                            insertPos = idx
                                            stop.pointee = true
                                        }
                                    }
                                })
                                PHAssetCollectionChangeRequest(for: a, assets: assets)?.insertAssets([holder] as NSArray, at: IndexSet(integer: insertPos))
                            } else {
                                PHAssetCollectionChangeRequest(for: a)?.addAssets([holder] as NSArray)
                            }
                        } else {
                            // no task indexpath?
                            PHAssetCollectionChangeRequest(for: a)?.addAssets([holder] as NSArray)
                        }
                    }
                }
            }
        } catch {
            debugPrint(error)
        }
        
        if let indexPath = self.tasks[downloadTask.taskIdentifier] {
            filtered[indexPath.item].state = .Imported
            DispatchQueue.main.async {
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                    cell.update()
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
        return filtered[idx.item].photoPath.identifier
    }
    
    func indexPathForElement(withModelIdentifier identifier: String, in view: UIView) -> IndexPath? {
        for (idx, cellData) in filtered.enumerated() {
            if cellData.photoPath.identifier == identifier {
                return IndexPath(item: idx, section: 0)
            }
        }
        
        return nil
    }
}
