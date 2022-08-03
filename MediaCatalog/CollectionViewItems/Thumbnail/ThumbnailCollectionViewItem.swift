//
//  ThumbnailCollectionViewItem.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 24/7/22.
//

import Cocoa

class ThumbnailCollectionViewItem: NSCollectionViewItem {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var thumbnailImageView: NSImageView!
    @IBOutlet weak var darkImageView: NSImageView!
    
    // MARK: Properties
    
    public var file: File? {
        didSet {
            guard let safeFile = file else { return }
            
            // File thumbnail.
            switch safeFile.getOriginalPath().pathExtension {
            case "arw", "ARW", "nef", "NEF", "cr2", "CR2":
                if let thumbnailPath = safeFile.getThumbnailImagePath() {
                    thumbnailImageView.loadFrom(localPath: thumbnailPath)
                } else {
                    thumbnailImageView.image = NSImage()
                }
            case "jpg", "JPG", "jpeg", "JPEG":
                thumbnailImageView.loadFrom(localPath: safeFile.getOriginalPath())
            case "png", "PNG":
                thumbnailImageView.loadFrom(localPath: safeFile.getOriginalPath())
            default:
                thumbnailImageView.image = NSImage(named: "unknownFileExtension")
            }
        }
    }
    
    public var photoSelected: Bool? {
        didSet {
            guard let safePhotoSelected = photoSelected else { return }
            
            if safePhotoSelected {
                darkImageView.alphaValue = 0
            } else {
                darkImageView.alphaValue = 0.6
            }
        }
    }
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        darkImageView.wantsLayer = true
        darkImageView.layer?.backgroundColor = NSColor.black.cgColor
    }
}
