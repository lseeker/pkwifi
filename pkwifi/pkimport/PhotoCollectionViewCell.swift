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
    private var lastState = PhotoCellState.Select
    
    var cellData: PhotoCellData? {
        didSet(old) {
            if old?.photoPath != cellData?.photoPath {
                thumbnail.kf.cancelDownloadTask()
                name.text = cellData?.photoPath.file
                thumbnail.image = nil
                thumbnail.kf.setImage(with: cellData?.photoPath.thumbnailURL)
            }
            
            if old?.state != cellData?.state {
                update()
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            if cellData?.state == .Select || cellData?.state == .Error {
                updateOnSelect()
            }
        }
    }
    
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var selectedImage: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private func updateOnSelect() {
        if isSelected {
            thumbnail.alpha = 0.7
            selectedImage.image = #imageLiteral(resourceName: "BlueCheckSelected")
        } else {
            if cellData?.state == .Error {
                selectedImage.image = #imageLiteral(resourceName: "ErrorCheck")
            } else {
                thumbnail.alpha = 1
                selectedImage.image = nil
            }
        }
    }
    
    func update() {
        if lastState == cellData?.state {
            return
        }
        
        switch cellData!.state {
        case .Select:
            progressView.progress = 0
            activityIndicator.stopAnimating()
            updateOnSelect()
        case .Ready:
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
        
        lastState = cellData?.state ?? .Select
    }
}
