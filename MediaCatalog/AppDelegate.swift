//
//  AppDelegate.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - UI Elements
    
    @IBOutlet var window: NSWindow!
    
    @IBOutlet weak var allMediaButton: NSButton!
    @IBAction func allMediaButtonTapped(_ sender: Any) {
        selectedFileImageView.isHidden = true
        collectionView.isHidden = false
    }
    
    @IBOutlet weak var selectedButton: NSButton!
    @IBAction func selectedButtonTapped(_ sender: Any) {
    }
    
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var selectedFileImageView: NSImageView!
    
    
    @IBOutlet weak var importFolderButton: NSButton!
    @IBAction func importFolderButtonPressed(_ sender: Any) {
        loadImages()
    }
    
    @IBOutlet weak var fileTypeCounterLabel: NSTextField!
    
    
    // MARK: - Properties
    
    // MARK: - Methods
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupView()
        setupCollectionView()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    ///
    /// Setup the view.
    ///
    private func setupView() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUI), name: NSNotification.Name("PhotosDB-Populated"), object: nil)
        
        // Labels.
        fileTypeCounterLabel.stringValue = ""
        
        // Buttons.
        selectedButton.isHidden = true
        
        // ImageViews.
        selectedFileImageView.isHidden = false
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
        
        // Register the Cells / Items for the CollectionView.
        let photoCellNib = NSNib(nibNamed: "FileCollectionViewItem", bundle: nil)
        collectionView.register(photoCellNib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PhotoItems"))
    }
    
    ///
    /// Load in the CollectionView the images that the user has selected.
    ///
    private func loadImages() {
        guard let window = window else { return }
        
        // Clear label.
        fileTypeCounterLabel.stringValue = "importing ..."
        
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
            
            let finalText: String = "\(FilesDB.shared.count(extensionType: .RAWPhoto)) RAW, \(FilesDB.shared.count(extensionType: .JPEGPhoto)) JPEG)"
            
            self.fileTypeCounterLabel.stringValue = finalText
        }
    }
    
}

// MARK: - NSCollectionView Delegate

extension AppDelegate: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let safeIndexPath = indexPaths.first else { return }
        
        displaySelectedPhoto(file: FilesDB.shared.getFile(at: safeIndexPath.item))
        
        collectionView.deselectAll(self)
    }
    
}

// MARK: - NSCollectionView Data Source

extension AppDelegate: NSCollectionViewDataSource {
    
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

extension AppDelegate {
    
    private func displaySelectedPhoto(file: File?) {
        guard let safeFile = file else { return }
        
        collectionView.isHidden = true
        
        selectedButton.isHidden = false
        selectedFileImageView.isHidden = false
        
        selectedFileImageView.image = safeFile.getThumbnailImage()
    }
    
}
