//
//  ViewerViewController.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 22/7/22.
//

import Cocoa

class ViewerViewController: NSViewController {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var leftSplitViewView: NSView!
    @IBOutlet weak var rightSplitViewView: NSView!
    
    @IBOutlet weak var importFolderButton: NSButtonCell!
    @IBAction func importFolderButtonTapped(_ sender: Any) {
        loadImages()
    }
    
    @IBOutlet weak var closePhotoButton: NSButton!
    @IBAction func closePhotoButtonTapped(_ sender: Any) {
        photoOnDisplay = false
    }
    
    @IBOutlet weak var importedFilesTypesLabel: NSTextField!
    
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var imageView: NSImageView!
    
    // MARK: - Properties
    
    var photoOnDisplay: Bool = false {
        didSet {
            if photoOnDisplay {
                closePhotoButton.isHidden = false
                imageView.isHidden = false
                collectionView.isHidden = true
            } else {
                closePhotoButton.isHidden = true
                imageView.isHidden = true
                collectionView.isHidden = false
            }
        }
    }
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupCollectionView()
    }
    
    ///
    /// Setup the view.
    ///
    private func setupView() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUI), name: NSNotification.Name("PhotosDB-Populated"), object: nil)
        
        // Labels.
        importedFilesTypesLabel.stringValue = ""
        
        photoOnDisplay = false
    }
    
    ///
    /// Setup the CollectionView.
    ///
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = true
        collectionView.allowsMultipleSelection = false
        
        // Design.
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0
        flowLayout.sectionInset = NSEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
        flowLayout.itemSize = NSSize(width: 160.0, height: 200.0)
        collectionView.collectionViewLayout = flowLayout
        
        // Register the Cells / Items for the CollectionView.
        let photoCellNib = NSNib(nibNamed: "FileCollectionViewItem", bundle: nil)
        collectionView.register(photoCellNib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PhotoItems"))
    }
    
    ///
    /// Load in the CollectionView the images that the user has selected.
    ///
    private func loadImages() {
        guard let window = self.view.window else { return }
        
        // Clear label.
        importedFilesTypesLabel.stringValue = "importing..."

        // File Manager.
        let fileManagerPanel = NSOpenPanel()
        fileManagerPanel.canChooseFiles = false
        fileManagerPanel.canChooseDirectories = true
        fileManagerPanel.allowsMultipleSelection = false
        
        fileManagerPanel.beginSheetModal(for: window) { result in
            if result == NSApplication.ModalResponse.OK {
                FilesDB.shared.selectedPath = fileManagerPanel.urls[0]
            }
        }
    }
    
    ///
    /// Reload the UI elements.
    ///
    @objc private func reloadUI() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            
            var finalText: String = ""
            finalText += "\(FilesDB.shared.count(extensionType: .RAWPhoto)) RAW, "
            finalText += "\(FilesDB.shared.count(extensionType: .JPEGPhoto)) JPG, "
            finalText += "\(FilesDB.shared.count(extensionType: .PNGPhoto)) PNG"
            
            self.importedFilesTypesLabel.stringValue = finalText
        }
    }
    
}

// MARK: - NSCollectionView Delegate

extension ViewerViewController: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let safeIndexPath = indexPaths.first else { return }
        
        displaySelectedPhoto(file: FilesDB.shared.getFile(at: safeIndexPath.item))
        collectionView.deselectAll(self)
    }
    
}

// MARK: - NSCollectionView Data Source

extension ViewerViewController: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return FilesDB.shared.files.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PhotoItems"), for: indexPath) as! FileCollectionViewItem
        item.file = FilesDB.shared.getFile(at: indexPath.item)
        return item
    }
}

// MARK: - ImageView

extension ViewerViewController {
    
    private func displaySelectedPhoto(file: File?) {
        guard let safeFile = file else { return }
        
        photoOnDisplay = true
        
        // File thumbnail.
        switch safeFile.getOriginalPath().pathExtension {
        case "arw", "ARW":
            imageView.image = safeFile.getThumbnailImage()
        case "jpg", "JPG", "jpeg", "JPEG":
            imageView.loadFrom(localPath: safeFile.getOriginalPath())
        case "png", "PNG":
            imageView.loadFrom(localPath: safeFile.getOriginalPath())
        default:
            imageView.image = NSImage(named: "unknownFileExtension")
        }
    }
    
}
