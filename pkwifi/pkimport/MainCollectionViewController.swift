//
//  MainCollectionViewController.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 3. 18..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import UIKit
import Kingfisher

private let photoCellreuseIdentifier = "PhotoCell"

enum PhotoImportState: Int, Codable {
    case None
    case StandBy
    case Importing
    case Imported
    case Error
}

class MainCollectionViewController: UICollectionViewController, UICollectionViewDataSourcePrefetching, UICollectionViewDelegateFlowLayout, UIDataSourceModelAssociation, UIGestureRecognizerDelegate, PhotoImportManagerDelegate {
    
    private let importManager = PhotoImportManager.shared
    private var filtered = [PhotoPath]()
    private var states = [PhotoPath: PhotoImportState]()
    
    private var isSelectMode = true
    private var startIndexPath: IndexPath!
    private var lastIndexPath: IndexPath!
    private lazy var changedItems: IndexSet = IndexSet()
    
    var selectionChanged: ((Int) -> Void)?
    var filterType = FilterType.ALL {
        didSet(old) {
            if old != filterType {
                applyFilter()
            }
        }
    }
    var sortOrder = SortOrder.Date {
        didSet(old) {
            if old != sortOrder {
                filtered.reverse()
                collectionView?.reloadData()
            }
        }
    }
    
    var selectedCount: Int {
        get {
            return collectionView?.indexPathsForSelectedItems?.count ?? 0
        }
    }
    var totalCount: Int {
        get {
            return filtered.count
        }
    }
    
    private var lastWidth: CGFloat = 0
    private var lastSize = CGSize()
    private var appDelegate: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.prefetchDataSource = self
        collectionView?.allowsMultipleSelection = true
        
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        importManager.delegate = self
        collectionViewLayout.invalidateLayout()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        collectionViewLayout.invalidateLayout()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func indexPath(for photoPath: PhotoPath) -> IndexPath! {
        return IndexPath(item: filtered.index(of: photoPath)!, section: 0)
    }
    
    // MARK: - Actions
    
    func beginImport() {
        // compat states on import
        states = states.filter { (pair) -> Bool in
            return pair.value == .Imported
        }
        
        let selected = self.collectionView?.indexPathsForSelectedItems
        
        if selected?.isEmpty ?? true {
            DispatchQueue(label: "importing").async {
                for (idx, photo) in self.filtered.enumerated() {
                    if self.states[photo] != .Imported {
                        self.startDownload(photo, indexPath: IndexPath(item: idx, section: 0))
                    }
                }
            }
        } else {
            // import selected photos
            let indexPaths = selected!.sorted()
            // clean up selection for futher states change
            self.collectionView?.selectItem(at: nil, animated: false, scrollPosition: [])
            DispatchQueue(label: "importing").async {
                for indexPath in indexPaths {
                    self.startDownload(self.filtered[indexPath.item], indexPath: indexPath)
                }
            }
        }
    }
    
    private func startDownload(_ photoPath: PhotoPath, indexPath: IndexPath) {
        importManager.beginImport(photoPath)
        states[photoPath] = .StandBy
        DispatchQueue.main.async {
            if let cell = self.collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                cell.state = .StandBy
            } else {
                self.collectionView?.reloadItems(at: [indexPath])
            }
        }
    }
    
    private func applyFilter() {
        if let photoPaths = Camera.shared.photos {
            switch filterType {
            case .ALL:
                filtered = photoPaths
            case .RAW:
                filtered = photoPaths.filter({ (photoPath) -> Bool in
                    return photoPath.file.hasSuffix(".DNG") || photoPath.file.hasSuffix(".PEF")
                })
            case .JPG:
                filtered = photoPaths.filter({ (photoPath) -> Bool in
                    return photoPath.file.hasSuffix(".JPG")
                })
            case .MOV:
                filtered = photoPaths.filter({ (photoPath) -> Bool in
                    // timelapse = avi
                    return photoPath.file.hasSuffix(".AVI") || photoPath.file.hasSuffix(".MOV")
                })
            }
            
            if sortOrder == .Recent {
                filtered.reverse()
            }
            
            collectionView?.reloadData()
        }
        
        selectionChanged?(0)
    }
    
    func reload() {
        states.removeAll()
        applyFilter()
    }
    
    func selectAll() {
        for (idx, photoPath) in filtered.enumerated() {
            if states[photoPath] != .Imported {
                collectionView?.selectItem(at: IndexPath(item: idx, section: 0), animated: true, scrollPosition: [])
            }
        }
        selectionChanged?(selectedCount)
    }
    
    func deselectAll() {
        collectionView?.selectItem(at: nil, animated: true, scrollPosition: [])
        selectionChanged?(0)
    }
    
    // MARK: - State restoration
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(try! JSONEncoder().encode(states), forKey: "States")
        if let offset = collectionView?.contentOffset {
            coder.encode(offset, forKey: "Offset")
        }
        if let selections = collectionView?.indexPathsForSelectedItems {
            coder.encode(selections, forKey: "Selections")
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        states = try! JSONDecoder().decode([PhotoPath : PhotoImportState].self, from: coder.decodeObject(forKey: "States") as! Data)
        applyFilter()
        if let selections = coder.decodeObject(forKey: "Selections") as? [IndexPath] {
            selections.forEach { (indexPath) in
                collectionView?.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
        }
        
        if let offset = coder.decodeObject(forKey: "Offset") as? String {
            collectionView?.contentOffset = CGPointFromString(offset)
        }
        
        super.decodeRestorableState(with: coder)
        
        if let parent = parent as? MainControlViewController {
            parent.updateUI()
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
        cell.photoPath = filtered[indexPath.item]
        cell.state = states[cell.photoPath!] ?? .None
        
        return cell
    }
    
    // MARK: - UICollectionViewDataSourcePrefetching
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.map { filtered[$0.item].thumbnailURL }
        ImagePrefetcher(urls: urls).start()
    }
    
    // MARK: - UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let state = states[filtered[indexPath.item]],
            let cell = cell as? PhotoCollectionViewCell {
            cell.state = state
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectionChanged?(selectedCount)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        selectionChanged?(selectedCount)
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if appDelegate.state != .Select {
            return false
        }
        
        return states[filtered[indexPath.item]] != .Imported
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return appDelegate.state == .Select
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if view.frame.width == lastWidth {
            return lastSize
        }
        
        var count = ceil((view.frame.width - 8) / 160)
        if count < 3 {
            count = 3
        }
        let width = (view.frame.width - 8) / count - 8
        let height = 120 * width / 160
        
        lastWidth = view.frame.width
        lastSize = CGSize(width: width, height: height)
        
        return lastSize
    }
    
    // MARK: - UIDataSourceModelAssociation
    
    func modelIdentifierForElement(at idx: IndexPath, in view: UIView) -> String? {
        return filtered[idx.item].identifier
    }
    
    func indexPathForElement(withModelIdentifier identifier: String, in view: UIView) -> IndexPath? {
        for (idx, photoPath) in filtered.enumerated() {
            if photoPath.identifier == identifier {
                return IndexPath(item: idx, section: 0)
            }
        }
        
        return nil
    }
    
    // MARK: - Gesture Recognizer
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return appDelegate.state == .Select
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    private func selectItem(at indexPath: IndexPath, isSelect: Bool) {
        if isSelect {
            collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: [])
        } else {
            collectionView?.deselectItem(at: indexPath, animated: true)
        }
    }
    
    @IBAction func beginPanningSelection(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            if let indexPath = collectionView?.indexPathForItem(at: sender.location(in: collectionView)) {
                collectionView?.isScrollEnabled = false
                startIndexPath = indexPath
                lastIndexPath = indexPath
                
                if let cell = collectionView?.cellForItem(at: indexPath) {
                    isSelectMode = !cell.isSelected
                    selectItem(at: indexPath, isSelect: isSelectMode)
                }
            }
        } else if sender.state == .changed {
            // select or deselect
            if let indexPath = collectionView?.indexPathForItem(at: sender.location(in: collectionView)) {
                if indexPath == lastIndexPath {
                    // not changed
                    return
                }

                // make range for target
                var range: CountableClosedRange<Int>!
                if indexPath < startIndexPath {
                    range = indexPath.item ... startIndexPath.item
                } else {
                    range = startIndexPath.item ... indexPath.item
                }
                
                // restore not in range
                let restoreTargets = changedItems.subtracting(IndexSet(integersIn: range))
                for i in restoreTargets {
                    selectItem(at: IndexPath(item: i, section: 0), isSelect: !isSelectMode)
                    changedItems.remove(i)
                }

                // select/deselect
                let selected = collectionView?.indexPathsForSelectedItems
                for i in range {
                    let targetIndexPath = IndexPath(item: i, section: 0)
                    let isSelected = selected?.contains(targetIndexPath) == true
                    if isSelectMode {
                        if !isSelected {
                            selectItem(at: targetIndexPath, isSelect: true)
                            changedItems.insert(i)
                        }
                    } else {
                        if isSelected {
                            selectItem(at: targetIndexPath, isSelect: false)
                            changedItems.insert(i)
                        }
                    }
                }
                
                // update last path
                lastIndexPath = indexPath
            }
        } else if sender.state == .ended {
            collectionView?.isScrollEnabled = true
            startIndexPath = nil
            lastIndexPath = nil
            changedItems.removeAll()
            selectionChanged?(selectedCount)
        }
    }
    
    // MARK: - PhotoImportManagerDelegate
    
    func importing(_ photoPath: PhotoPath, progress: Progress) {
        let cell = updateState(photoPath, state: .Importing)
        cell?.progressView.progress = Float(progress.fractionCompleted)
    }
    
    func imported(_ photoPath: PhotoPath) {
        updateState(photoPath, state: .Imported)
    }
    
    func importCancelled(_ photoPath: PhotoPath) {
        updateState(photoPath, state: .None)
        if let indexPath = indexPath(for: photoPath) {
            collectionView?.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }
    
    func importErrorOccurred(_ photoPath: PhotoPath, error: Error) {
        updateState(photoPath, state: .Error)
    }
    
    func importFinished() {
        // if state contains none, will cancelled
        let alert = states.values.contains(.None) ? UIAlertController(title: NSLocalizedString("Cancelled", comment: "cancelled alert title"), message: NSLocalizedString("Import cancelled", comment: "cancelled alert message"), preferredStyle: .alert)
            : UIAlertController(title: NSLocalizedString("Completed", comment: "complete alert title"), message: NSLocalizedString("Import completed", comment: "complete alert message"), preferredStyle: .alert)

        self.appDelegate.state = .Select
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "alert ok button"), style: .default) { (action) in
            if let parent = self.parent as? MainControlViewController {
                parent.updateUI()
            }
        })
        
        self.present(alert, animated: true)
    }
    
    @discardableResult
    func updateState(_ photoPath: PhotoPath, state: PhotoImportState) -> PhotoCollectionViewCell? {
        states[photoPath] = state
        
        if let indexPath = indexPath(for: photoPath),
            let cell = collectionView?.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
            cell.state = state
            return cell
        }
        
        return nil
    }
}
