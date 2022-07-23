//
//  FileCollectionViewItem.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Cocoa

class FileCollectionViewItem: NSCollectionViewItem {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var thumbnailImageView: NSImageView!
    @IBOutlet weak var nameLabel: NSTextField!
    
    // MARK: Properties
    
    public var file: File? {
        didSet {
            guard let safeFile = file else { return }
            
            // File name.
            nameLabel.stringValue = safeFile.getName()
            
            // File thumbnail.
            switch safeFile.getOriginalPath().pathExtension {
            case "jpg", "JPG", "jpeg", "JPEG":
                thumbnailImageView.loadFrom(localPath: safeFile.getOriginalPath())
            case "arw", "ARW":
                thumbnailImageView.image = safeFile.getThumbnailImage()
            default:
                print("No thumbnail")
            }
        }
    }
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
