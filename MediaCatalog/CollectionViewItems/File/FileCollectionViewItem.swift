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
            
            nameLabel.stringValue = safeFile.getName()
            thumbnailImageView.image = safeFile.getThumbnailImage()
        }
    }
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
