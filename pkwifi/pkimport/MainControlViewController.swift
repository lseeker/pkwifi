//
//  MainControlViewController.swift
//  pkimport
//
//  Created by YUN YOUNG LEE on 2018. 4. 12..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import UIKit
import Photos
import UserNotifications

class MainControlViewController: UIViewController {
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var storageButton: UIBarButtonItem!
    @IBOutlet var importButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    
    @IBOutlet weak var filterButton: UIBarButtonItem!
    @IBOutlet weak var filterDescButton: UIBarButtonItem!
    @IBOutlet weak var selectButton: UIBarButtonItem!
    @IBOutlet weak var bottomDescription: UIBarButtonItem!
    
    @IBOutlet weak var filterSegment: UISegmentedControl!
    @IBOutlet weak var sortOrderSegment: UISegmentedControl!
    @IBOutlet weak var filterView: UIVisualEffectView!
    @IBOutlet weak var filterViewHeight: NSLayoutConstraint!
    
    weak var collectionVC: MainCollectionViewController!
    var appDelegate: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        bottomDescription.setTitleTextAttributes([.foregroundColor : UIColor.lightText], for: .disabled)
        filterViewHeight.isActive = false
        
        let ud = UserDefaults.standard
        sortOrderSegment.selectedSegmentIndex = ud.integer(forKey: "SortOrder")
        filterSegment.selectedSegmentIndex = ud.integer(forKey: "FilterType")
        
        sortOrderChanged(sortOrderSegment)
        filterChanged(filterSegment)
        
        updateUI()
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func updateUI() {
        navigationItem.title = Camera.shared.props?.model ?? "PK Import"
        if Camera.shared.props?.storages.count ?? 0 <= 1 {
            storageButton.title = nil
        } else {
            storageButton.title = Camera.shared.activeStorage ?? "sd1"
        }
        
        if appDelegate.state == .Import {
            if filterViewHeight.isActive {
                filterButtonPushed(filterButton)
            }
            refreshButton.isEnabled = false
            storageButton.isEnabled = false
            navigationItem.rightBarButtonItem = cancelButton
            filterButton.isEnabled = false
            filterDescButton.isEnabled = false
            selectButton.isEnabled = false
            bottomDescription.title = NSLocalizedString("Importing...", comment: "description title")
        } else {
            refreshButton.isEnabled = true
            storageButton.isEnabled = Camera.shared.props?.storages.count ?? 0 > 1
            navigationItem.rightBarButtonItem = importButton
            filterButton.isEnabled = true
            filterDescButton.isEnabled = true
            selectButton.isEnabled = true
            
            updateDescription(count: collectionVC.selectedCount)
        }
    }
    
    func updateDescription(count: Int) {
        if collectionVC.selectedCount > 0 {
            importButton.title = NSLocalizedString("Import Selected", comment: "import button title")
            selectButton.title = NSLocalizedString("Deselect All", comment: "select button title")
            bottomDescription.title = "\(count) / \(collectionVC.totalCount)"
        } else {
            importButton.title = NSLocalizedString("Import All", comment: "import button title")
            selectButton.title = NSLocalizedString("Select All", comment: "select button title")
            if collectionVC.totalCount == 0 {
                bottomDescription.title = NSLocalizedString("No Photos", comment: "description title")
            } else {
                bottomDescription.title = "\(collectionVC.totalCount)"
            }
        }
    }
    
    // MARK: - Action
    
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
    
    @IBAction func selectButtonPushed(_ sender: Any) {
        if collectionVC.selectedCount > 0 {
            collectionVC.deselectAll()
        } else {
            collectionVC.selectAll()
        }
    }
    
    @IBAction func filterButtonPushed(_ sender: Any) {
        if filterViewHeight.isActive {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                var rect = self.filterView.frame
                rect.origin.y += rect.height
                rect.size.height = 0
                self.filterView.frame = rect
                self.collectionVC.collectionView?.contentInset = UIEdgeInsets.zero
            }) { (finished) in
                self.filterViewHeight.isActive = false
            }
        } else {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                let height = self.filterViewHeight.constant
                var rect = self.filterView.frame
                rect.origin.y -= height
                rect.size.height = height
                self.filterView.frame = rect
                self.collectionVC.collectionView?.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height, right: 0)
            }) { (finished) in
                self.filterViewHeight.isActive = true
            }
        }
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
    
    @IBAction func connectClosed(segue: UIStoryboardSegue) {
        appDelegate.state = .Select
        collectionVC.reload()
        updateUI()
    }
    
    @IBAction func importButtonPushed(_ sender: Any) {
        self.grantPhotoAcess(PHPhotoLibrary.authorizationStatus()) {
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
                
                // check notification available
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                    DispatchQueue.main.async {
                        self.collectionVC.beginImport()
                    }
                } // end of notification grant
            }) // end of load props
        } // end of grant photo
    }
    
    @IBAction func cancelButtonPushed(_ sender: Any) {
        PhotoImportManager.shared.cancel()
    }
    
    @IBAction func filterChanged(_ sender: UISegmentedControl) {
        let filterType = FilterType(rawValue: sender.selectedSegmentIndex) ?? .ALL
        collectionVC?.filterType = filterType
        filterDescButton.title = filterSegment.titleForSegment(at: sender.selectedSegmentIndex)
        
        let ud = UserDefaults.standard
        ud.set(filterType.rawValue, forKey: "FilterType")
        ud.synchronize()
    }
    
    @IBAction func sortOrderChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            collectionVC?.sortOrder = .Date
            filterButton.image = #imageLiteral(resourceName: "OrderAsc")
        } else {
            collectionVC?.sortOrder = .Recent
            filterButton.image = #imageLiteral(resourceName: "OrderDesc")
        }
        
        let ud = UserDefaults.standard
        ud.set(sender.selectedSegmentIndex, forKey: "SortOrder")
        ud.synchronize()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        if filterViewHeight.isActive && traitCollection.horizontalSizeClass != newCollection.horizontalSizeClass {
            coordinator.animate(alongsideTransition: { (context) in
                self.collectionVC.collectionView?.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: newCollection.horizontalSizeClass == .regular ? 44 : 81, right: 0)
            })
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if filterViewHeight.isActive {
            // adjust content inset
            self.collectionVC.collectionView?.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: traitCollection.horizontalSizeClass == .regular ? 44 : 81, right: 0)
        }
    }

    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Embed" {
            if let collectionVC = segue.destination as? MainCollectionViewController {
                self.collectionVC = collectionVC
                collectionVC.selectionChanged = updateDescription
            }
        } else if segue.identifier == "ConnectCamera" {
            appDelegate.state = .Connect
            bottomDescription.title = NSLocalizedString("Connecting...", comment: "description title")
        }
    }
    
    // MARK: - State preservation & restore
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(filterViewHeight.isActive, forKey: "filterViewVisible")
        
        let archiver = NSKeyedArchiver(forWritingWith: NSMutableData())
        collectionVC.encodeRestorableState(with: archiver)
        archiver.finishEncoding()
        
        coder.encode(archiver.encodedData, forKey: "CollectionVC")
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        let unachiver = NSKeyedUnarchiver(forReadingWith: coder.decodeObject(forKey: "CollectionVC") as! Data)
        collectionVC.decodeRestorableState(with: unachiver)
        unachiver.finishDecoding()
        
        if coder.decodeBool(forKey: "filterViewVisible") {
            filterViewHeight.isActive = true
        }
        
        super.decodeRestorableState(with: coder)
    }
    
}
