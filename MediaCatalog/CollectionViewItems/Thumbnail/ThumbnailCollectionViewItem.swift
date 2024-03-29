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
    
    public var fileId: Int? {
        didSet {
            guard let safeFileId = fileId,
                  let file = FilesDB.shared.getFile(id: safeFileId) else { return }
            
            // File thumbnail.
            switch file.getOriginalPath().pathExtension.lowercased() {
            case "arw", "nef", "cr2":
                if let thumbnailPath = file.getThumbnailImagePath() {
                    thumbnailImageView.loadFrom(localPath: thumbnailPath)
                } else {
                    thumbnailImageView.image = NSImage()
                }
            case "jpg", "jpeg":
                thumbnailImageView.loadFrom(localPath: file.getOriginalPath())
            case "png":
                thumbnailImageView.loadFrom(localPath: file.getOriginalPath())
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
