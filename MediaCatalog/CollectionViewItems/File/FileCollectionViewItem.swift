//
//  FileCollectionViewItem.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Cocoa

protocol FileItemActions {
    func selectFile(indexPath: IndexPath?)
    func openFile(id: Int?)
}

class FileCollectionViewItem: NSCollectionViewItem {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var thumbnailImageView: NSImageView!
    @IBOutlet weak var nameLabel: NSTextField!
    
    // MARK: Properties
    
    public var delegate: FileItemActions?
    public var fileId: Int? {
        didSet {
            guard let safeFileId = fileId,
                  let file = FilesDB.shared.getFile(id: safeFileId) else { return }
            
            // File name.
            nameLabel.stringValue = file.getName()
            
            // File thumbnail.
            switch file.getOriginalPath().pathExtension.lowercased() {
            case "arw", "nef", "cr2":
                if let safePath = file.getThumbnailImagePath() {
                    thumbnailImageView.loadFrom(localPath: safePath)
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
    public var indexPath: IndexPath?
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.wantsLayer = true
    }
    
    override func mouseUp(with event: NSEvent) {
        switch event.clickCount {
        case 1:
            if let safeDelegate = delegate {
                safeDelegate.selectFile(indexPath: indexPath)
            }
        case 2:
            if let safeDelegate = delegate {
                safeDelegate.openFile(id: fileId)
            }
        default:
            print("Aitor mouseUp")
        }
    }
    
    override var isSelected: Bool {
        didSet {
            super.isSelected = isSelected
            
            view.layer?.backgroundColor = isSelected ? NSColor.MediaCatalog.grey?.cgColor : NSColor.MediaCatalog.lightGrey?.cgColor
        }
    }
    
}
