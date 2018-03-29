//
//  PhotoCollectionViewCell.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 3. 18..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import UIKit
import Kingfisher

class PhotoCollectionViewCell: UICollectionViewCell {
    var path: PhotoPath? {
        didSet {
            thumbnail.kf.cancelDownloadTask()
            name.text = path?.file
            thumbnail.image = nil
            updateUIComponents()
            thumbnail.kf.setImage(with: path?.thumbnailURL)
        }
    }
    
    var importInfo: ImportInfo? {
        didSet(old) {
            if old?.state == importInfo?.state {
                return
            }
        }
    }
    
    var importState = ImportState.None {
        didSet(lastState) {
            if lastState == importState {
                return
            }
            
            switch importState {
            case .None:
                progressView.progress = 0
                activityIndicator.stopAnimating()
                selectedImage.image = nil
            case .Selected:
                progressView.progress = 0
                activityIndicator.stopAnimating()
                selectedImage.image = #imageLiteral(resourceName: "BlueCheckUnselected")
            case .Importing:
                activityIndicator.isHidden = false
                activityIndicator.startAnimating()
                selectedImage.image = nil
            case .Imported:
                thumbnail.alpha = 1
                progressView.progress = 0
                activityIndicator.stopAnimating()
                selectedImage.image = #imageLiteral(resourceName: "GreenCheckSelected")
            case .Error:
                progressView.progress = 0
                activityIndicator.stopAnimating()
                selectedImage.image = #imageLiteral(resourceName: "ErrorCheck")
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            updateUIComponents()
        }
    }
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var selectedImage: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private func updateUIComponents() {
        if importState != .None {
            return
        }
        
        if isSelected {
            thumbnail.alpha = 0.7
            selectedImage.image = #imageLiteral(resourceName: "BlueCheckSelected")
        } else {
            thumbnail.alpha = 1.0
            selectedImage.image = nil
        }
    }
}
