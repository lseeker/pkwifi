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
    var photoPath: PhotoPath? {
        didSet(old) {
            if old != photoPath {
                thumbnail.kf.cancelDownloadTask()
                name.text = photoPath?.file
                thumbnail.image = nil
                thumbnail.kf.setImage(with: photoPath?.thumbnailURL)
            }
        }
    }
    
    var state = PhotoImportState.None {
        didSet {
            switch state {
            case .None:
                progressView.progress = 0
                activityIndicator.stopAnimating()
                if isSelected {
                    thumbnail.alpha = 0.7
                    selectedImage.image = #imageLiteral(resourceName: "BlueCheckSelected")
                } else {
                    thumbnail.alpha = 1
                    selectedImage.image = nil
                }
            case .StandBy:
                thumbnail.alpha = 0.7
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
            if isSelected {
                thumbnail.alpha = 0.7
                selectedImage.image = #imageLiteral(resourceName: "BlueCheckSelected")
            } else {
                if state == .Error {
                    selectedImage.image = #imageLiteral(resourceName: "ErrorCheck")
                } else {
                    thumbnail.alpha = 1
                    selectedImage.image = nil
                }
            }
        }
    }
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var selectedImage: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
}
