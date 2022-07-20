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
    
    @IBOutlet weak var collectionView: NSCollectionView!
    
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
    }
    
    ///
    /// Setup the CollectionView.
    ///
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
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

extension AppDelegate: NSCollectionViewDelegate {}

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
