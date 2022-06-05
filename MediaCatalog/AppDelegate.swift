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
    
    private var db: FilesDB? {
        didSet {
            collectionView.reloadData()
        }
    }
    private var selectedFolder: URL? {
        didSet {
            guard let safeSelectedFolder = selectedFolder else { return }
            
            selectedFilesURLs = contentsOf(folder: safeSelectedFolder)
        }
    }
    private var selectedFilesURLs: [URL] = [] {
        didSet {
            createFilesDB()
        }
    }
    
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
                self.selectedFolder = fileManagerPanel.urls[0]
            }
        }
    }
    
    ///
    /// Gets the content (files) inside the selected folder.
    ///
    private func contentsOf(folder: URL) -> [URL] {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: folder.path)
            
            let urls = contents.map { return folder.appendingPathComponent($0) }
            print("Files inside the selected folder. \(urls)")
            return urls
        } catch {
            return []
        }
    }
    
    ///
    ///
    ///
    private func createFilesDB() {
        // Create the DB with the selected files.
        db = FilesDB(filesURLs: selectedFilesURLs)
    }
    
    ///
    /// Reload the UI elements.
    ///
    @objc private func reloadUI() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            if let safeDB = self.db {
                let finalText: String = "\(safeDB.count(extensionType: .RAWPhoto)) RAW, \(safeDB.count(extensionType: .JPEGPhoto)) JPEG"
                self.fileTypeCounterLabel.stringValue = finalText
                
            }
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
        if let safeDB = db {
            return safeDB.count(extensionType: .all)
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PhotoItems"), for: indexPath) as! FileCollectionViewItem
        if let safeDB = db {
            item.file = safeDB.getFile(at: indexPath.item)
        }
        
        return item
    }
}
