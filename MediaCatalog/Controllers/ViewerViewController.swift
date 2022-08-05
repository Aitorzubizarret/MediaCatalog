//
//  ViewerViewController.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 22/7/22.
//

import Cocoa

class ViewerViewController: NSViewController {
    
    // MARK: - UI Elements
    
    /// Side menu
    
    @IBOutlet weak var sideMenuView: NSView!
    
    @IBOutlet weak var createDBButton: NSButton!
    @IBAction func createDBButtonTapped(_ sender: Any) {
        FilesDB.shared.createCatalogFile(window: self.view.window)
    }
    
    @IBOutlet weak var openDBButton: NSButton!
    @IBAction func openDBButtonTapped(_ sender: Any) {
        FilesDB.shared.openCatalogFile(window: self.view.window)
    }
    
    @IBOutlet weak var importFolderButton: NSButton!
    @IBAction func importFolderButtonTapped(_ sender: Any) {
        loadImages()
    }
    
    @IBOutlet weak var detectFacesButton: NSButton!
    @IBAction func detectFacesButtonTapped(_ sender: Any) {
        detectFaces()
    }
    
    @IBOutlet weak var showFileInFinderButton: NSButton!
    @IBAction func showFileInFinderButtonTapped(_ sender: Any) {
        showSelectedFileInFinder()
    }
    
    @IBOutlet weak var importedFilesTypesLabel: NSTextField!
    
    /// Top bar
    
    @IBOutlet weak var topBarView: NSView!
    
    @IBOutlet weak var displayAllFilesButton: NSButton!
    @IBAction func displayAllFilesButtonTapped(_ sender: Any) {
        filterBy(.all)
    }
    
    @IBOutlet weak var displayOnlyPhotosButton: NSButton!
    @IBAction func displayOnlyPhotosButtonTapped(_ sender: Any) {
        filterBy(.photos)
    }
    
    @IBOutlet weak var displayOnlyVideosButton: NSButton!
    @IBAction func displayOnlyVideosButtonTapped(_ sender: Any) {
        filterBy(.videos)
    }
    
    @IBOutlet weak var displayRestOfFilesButton: NSButton!
    @IBAction func displayRestOfFilesButtonTapped(_ sender: Any) {
        filterBy(.others)
    }
    
    /// Center gallery
    
    @IBOutlet weak var contentView: NSView!
    
    @IBOutlet weak var galleryCollectionViewScrollView: NSScrollView!
    @IBOutlet weak var galleryCollectionView: NSCollectionView!
    
    /// Center selected photo view
    
    @IBOutlet weak var selectedPhotoViewerView: NSView!
    @IBOutlet weak var closeSelectedPhotoViewerButton: NSButton!
    @IBAction func closeSelectedPhotoViewerButtonTapped(_ sender: Any) {
        photoOnDisplay = false
    }
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var thumbnailsCollectionViewScrollView: NSScrollView!
    @IBOutlet weak var thumbnailsCollectionView: NSCollectionView!
    
    // MARK: - Properties
    
    private var selectedPhotoIndex: IndexPath?
    
    private var photoOnDisplay: Bool = false {
        didSet {
            if photoOnDisplay {
                // Buttons.
                detectFacesButton.isHidden = false
                
                // ScrollViews
                galleryCollectionViewScrollView.isHidden = true
                
                // CollectionViews
                thumbnailsCollectionView.reloadData()
                galleryCollectionView.isHidden = true
                
                // Views.
                selectedPhotoViewerView.isHidden = false
                topBarView.isHidden = true
            } else {
                // Buttons.
                detectFacesButton.isHidden = true
                
                // ImageViews.
                imageView.image = NSImage(size: NSSize(width: 0, height: 0))
                
                // CAShapeLayers
                faceRectangleLayer.sublayers?.removeAll()
                
                // ScrollViews
                galleryCollectionViewScrollView.isHidden = false
                
                // CollectionViews
                galleryCollectionView.isHidden = false
                
                // Views.
                selectedPhotoViewerView.isHidden = true
                topBarView.isHidden = false
                
                if let safeSelectedPhotoIndex = selectedPhotoIndex {
                    galleryCollectionView.selectItems(at: [safeSelectedPhotoIndex], scrollPosition: .top)
                }
            }
        }
    }
    
    private var faceRectangleLayer: CAShapeLayer = {
        var layer = CAShapeLayer()
        return layer
    }()
    
    // MARK: - Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupGalleryCollectionView()
        setupThumbnailsCollectionView()
    }
    
    ///
    /// Setup the view.
    ///
    private func setupView() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUI), name: NSNotification.Name("PhotosDB-Populated"), object: nil)
        
        // Views.
        sideMenuView.wantsLayer = true
        sideMenuView.layer?.backgroundColor = NSColor.MediaCatalog.grey?.cgColor
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.MediaCatalog.lightGrey?.cgColor
        
        // Buttons.
        createDBButton.isHidden = false
        importFolderButton.isHidden = false
        
        closeSelectedPhotoViewerButton.wantsLayer = true
        closeSelectedPhotoViewerButton.layer?.backgroundColor = NSColor.MediaCatalog.darkGrey?.cgColor
        closeSelectedPhotoViewerButton.contentTintColor = NSColor.white
        closeSelectedPhotoViewerButton.layer?.cornerRadius = 6
        closeSelectedPhotoViewerButton.layer?.borderWidth = 1
        closeSelectedPhotoViewerButton.layer?.borderColor = NSColor.white.cgColor
        
        displayAllFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        displayOnlyVideosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        displayOnlyPhotosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        displayRestOfFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        
        showFileInFinderButton.isHidden = true
        
        // Labels.
        importedFilesTypesLabel.stringValue = ""
        
        // NSImageView.
        photoOnDisplay = false
    }
    
    ///
    /// Setup Gallery CollectionView.
    ///
    private func setupGalleryCollectionView() {
        galleryCollectionView.delegate = self
        galleryCollectionView.dataSource = self
        
        galleryCollectionView.isSelectable = true
        galleryCollectionView.allowsEmptySelection = true
        galleryCollectionView.allowsMultipleSelection = false
        
        // Design.
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 2
        flowLayout.sectionInset = NSEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)
        flowLayout.itemSize = NSSize(width: 160.0, height: 200.0)
        flowLayout.scrollDirection = .vertical
        galleryCollectionView.collectionViewLayout = flowLayout
        
        galleryCollectionView.wantsLayer = true
        galleryCollectionView.layer?.backgroundColor = NSColor.MediaCatalog.lightGrey?.cgColor
        
        // Register the Cells / Items for the CollectionView.
        let photoCellNib = NSNib(nibNamed: "FileCollectionViewItem", bundle: nil)
        galleryCollectionView.register(photoCellNib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PhotoItems"))
    }
    
    ///
    /// Setup Thumbnails CollectionView.
    ///
    private func setupThumbnailsCollectionView() {
        thumbnailsCollectionView.delegate = self
        thumbnailsCollectionView.dataSource = self
        
        thumbnailsCollectionView.isSelectable = true
        thumbnailsCollectionView.allowsEmptySelection = true
        thumbnailsCollectionView.allowsMultipleSelection = false
        
        // Design.
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0
        flowLayout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        flowLayout.itemSize = NSSize(width: 60, height: 60)
        flowLayout.scrollDirection = .horizontal
        thumbnailsCollectionView.collectionViewLayout = flowLayout
        
        thumbnailsCollectionViewScrollView.wantsLayer = true
        thumbnailsCollectionViewScrollView.layer?.backgroundColor = NSColor.red.cgColor
        
        thumbnailsCollectionView.wantsLayer = true
        thumbnailsCollectionView.layer?.backgroundColor = NSColor.white.cgColor
        
        // Register the Cells / Items for the CollectionView.
        let thumbnailCellNib = NSNib(nibNamed: "ThumbnailCollectionViewItem", bundle: nil)
        thumbnailsCollectionView.register(thumbnailCellNib, forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ThumbnailItems"))
    }
    
    ///
    /// Load in the CollectionView the images that the user has selected.
    ///
    private func loadImages() {
        FilesDB.shared.importFilesFromFolder(window: self.view.window)
    }
    
    ///
    /// Reload the UI elements.
    ///
    @objc private func reloadUI() {
        DispatchQueue.main.async {
            self.galleryCollectionView.reloadData()
            
            // If there are files, scroll to the top of the Collection View.
            if FilesDB.shared.filteredFiles.count > 0 {
                self.galleryCollectionView.scrollToItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: .top)
            }
            
            var finalText: String = ""
            finalText += "\(FilesDB.shared.count(extensionType: .RAWPhoto)) RAW"
            finalText += "\n"
            finalText += "\(FilesDB.shared.count(extensionType: .HEICPhoto)) HEIC"
            finalText += "\n"
            finalText += "\(FilesDB.shared.count(extensionType: .JPEGPhoto)) JPG"
            finalText += "\n"
            finalText += "\(FilesDB.shared.count(extensionType: .PNGPhoto)) PNG"
            finalText += "\n"
            finalText += "\(FilesDB.shared.count(extensionType: .GIFPhoto)) GIF"
            finalText += "\n"
            finalText += "\(FilesDB.shared.count(extensionType: .BMPPhoto)) BMP"
            finalText += "\n"
            finalText += "\(FilesDB.shared.count(extensionType: .WEBPPhoto)) WEBP"
            
            self.importedFilesTypesLabel.stringValue = finalText
            
            self.photoOnDisplay = false
            self.showFileInFinderButton.isHidden = false
            
            // Buttons.
            self.displayAllFilesButton.contentTintColor = NSColor.black
            self.displayOnlyVideosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            self.displayOnlyPhotosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            self.displayRestOfFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        }
    }
    
    ///
    /// Show selected file in Finder.
    ///
    private func showSelectedFileInFinder() {
        if let safeSelectedPhotoIndex = selectedPhotoIndex,
           let safeFile: File = FilesDB.shared.getFile(at: safeSelectedPhotoIndex.item) {
            
            NSWorkspace.shared.activateFileViewerSelecting([safeFile.getOriginalPath()])
        }
    }
    
    ///
    /// Filters the files by the group of file extension and updates  the colors of the buttons.
    ///
    private func filterBy(_ extensionGroup: FileExtensionGroup) {
        guard let _ = FilesDB.shared.selectedPath else { return }
        
        selectedPhotoIndex = nil
        
        switch extensionGroup {
        case .all:
            FilesDB.shared.filterFilesBy(.all)
            
            displayAllFilesButton.contentTintColor = NSColor.black
            displayOnlyVideosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayOnlyPhotosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayRestOfFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        case .photos:
            FilesDB.shared.filterFilesBy(.photos)
            
            displayAllFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayOnlyPhotosButton.contentTintColor = NSColor.black
            displayOnlyVideosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayRestOfFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        case .videos:
            FilesDB.shared.filterFilesBy(.videos)
            
            displayAllFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayOnlyPhotosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayOnlyVideosButton.contentTintColor = NSColor.black
            displayRestOfFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
        case .others:
            FilesDB.shared.filterFilesBy(.others)
            
            displayAllFilesButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayOnlyPhotosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayOnlyVideosButton.contentTintColor = NSColor.MediaCatalog.darkGrey
            displayRestOfFilesButton.contentTintColor = NSColor.black
        }
    }
    
}

// MARK: - NSCollectionView Delegate

extension ViewerViewController: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let safeIndexPath = indexPaths.first else { return }
        
        selectedPhotoIndex = safeIndexPath
        
        if collectionView == thumbnailsCollectionView {
            updateThumbnailsCollectionViewPhoto(file: FilesDB.shared.getFile(at: safeIndexPath.item))
        }
    }
    
}

// MARK: - NSCollectionView Data Source

extension ViewerViewController: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return FilesDB.shared.filteredFiles.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if collectionView == galleryCollectionView {
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PhotoItems"), for: indexPath) as! FileCollectionViewItem
            item.delegate = self
            if let safeSelectedPhotoIndex = selectedPhotoIndex {
                if safeSelectedPhotoIndex.item == indexPath.item {
                    item.isSelected = true
                } else {
                    item.isSelected = false
                }
            }
            item.fileIndexPath = indexPath
            return item
        } else {
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ThumbnailItems"), for: indexPath) as! ThumbnailCollectionViewItem
            item.file = FilesDB.shared.getFile(at: indexPath.item)
            if let safeSelectedPhotoIndex = selectedPhotoIndex {
                if safeSelectedPhotoIndex.item == indexPath.item {
                    item.photoSelected = true
                } else {
                    item.photoSelected = false
                }
            }
            return item
        }
        
    }
}

// MARK: - ImageView

extension ViewerViewController {
    
    private func displaySelectedPhoto(file: File?) {
        guard let safeFile = file,
              let safeSelectedPhotoIndex = selectedPhotoIndex else { return }
        
        photoOnDisplay = true
        
        // File thumbnail.
        switch safeFile.getOriginalPath().pathExtension.lowercased() {
        case "arw", "nef", "cr2":
            if let safePath = safeFile.getThumbnailImagePath() {
                imageView.loadFrom(localPath: safePath)
            } else {
                imageView.image = NSImage()
            }
        case "jpg", "jpeg":
            imageView.loadFrom(localPath: safeFile.getOriginalPath())
        case "png":
            imageView.loadFrom(localPath: safeFile.getOriginalPath())
        default:
            imageView.image = NSImage(named: "unknownFileExtension")
        }
        
        faceRectangleLayer.frame = imageView.frame
        
        thumbnailsCollectionView.selectItems(at: [safeSelectedPhotoIndex], scrollPosition: .centeredHorizontally)
    }
    
    private func updateThumbnailsCollectionViewPhoto(file: File?) {
        guard let safeFile = file,
              let safeSelectedPhotoIndex = selectedPhotoIndex else { return }
        
        // CAShapeLayers
        faceRectangleLayer.sublayers?.removeAll()
        
        // File thumbnail.
        switch safeFile.getOriginalPath().pathExtension.lowercased() {
        case "arw", "nef", "cr2":
            if let safePath = safeFile.getThumbnailImagePath() {
                imageView.loadFrom(localPath: safePath)
            } else {
                imageView.image = NSImage()
            }
        case "jpg", "jpeg":
            imageView.loadFrom(localPath: safeFile.getOriginalPath())
        case "png":
            imageView.loadFrom(localPath: safeFile.getOriginalPath())
        default:
            imageView.image = NSImage(named: "unknownFileExtension")
        }
        
        //thumbnailsCollectionView.reloadItems(at: [safePreviouslySelectedPhotoIndex, safeSelectedPhotoIndex])
    }
    
}

// MARK: - File Item Actions Delegate

extension ViewerViewController: FileItemActions {
    
    func selectFile(fileIndexPath: IndexPath?) {
        guard let safeFileIndexPath = fileIndexPath else { return }
        
        if let safeSelectedPhotoIndex = selectedPhotoIndex {
            if safeSelectedPhotoIndex == safeFileIndexPath {
                galleryCollectionView.deselectItems(at: [safeFileIndexPath])
                selectedPhotoIndex = nil
            } else {
                galleryCollectionView.deselectItems(at: [safeSelectedPhotoIndex])
                galleryCollectionView.selectItems(at: [safeFileIndexPath], scrollPosition: .init())
                selectedPhotoIndex = safeFileIndexPath
            }
        } else {
            selectedPhotoIndex = safeFileIndexPath
            galleryCollectionView.selectItems(at: [safeFileIndexPath], scrollPosition: .init())
        }
    }
    
    func openFile(fileIndexPath: IndexPath?) {
        guard let safeFileIndexPath = fileIndexPath else { return }
        
        displaySelectedPhoto(file: FilesDB.shared.getFile(at: safeFileIndexPath.item))
    }
    
}

// MARK: - Face Detection

extension ViewerViewController {
    
    ///
    /// Detects Faces in an Image.
    ///
    private func detectFaces() {
        if let inputImage = imageView.image {
            let width: CGFloat = inputImage.size.width
            let height: CGFloat = inputImage.size.height
            let x: CGFloat = ((imageView.layer?.bounds.width)! / 2) - (width / 2)
            let y: CGFloat = ((imageView.layer?.bounds.height)! / 2) - (height / 2)
            var r: NSRect = NSRect(x: x, y: y, width: width, height: height)
            
            let ciImage = CIImage(cgImage: inputImage.cgImage(forProposedRect: &r, context: nil, hints: nil)!)
            
            let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)
            
            guard let faces = faceDetector?.features(in: ciImage) else { return }
            
            for face in faces {
                print("Face detected in \(face.bounds)")
                drawRectangleOnFace(position: face.bounds)
            }
        }
    }
    
    ///
    /// Draws a rectangle in the received position.
    ///
    private func drawRectangleOnFace(position: CGRect) {
        guard let safeImage = imageView.image else { return }
        
//        let widthScale = imageView.frame.width / (imageView.image?.size.width)!
//        let heightScale = imageView.frame.height / (imageView.image?.size.height)!
        
//        var newPosition: CGRect = position
//        newPosition.origin.x = newPosition.origin.x// * widthScale
//        newPosition.origin.y = newPosition.origin.y// * heightScale
//        newPosition.size.width = newPosition.size.width * widthScale
//        newPosition.size.height = newPosition.size.height * heightScale
        
        var x: CGFloat = (imageView.frame.width / 2) - (safeImage.size.width / 2)
        var y: CGFloat = (imageView.frame.height / 2) - (safeImage.size.height / 2) - 60
        let width: CGFloat = position.width
        let height: CGFloat = position.height
        
        x = x + position.origin.x
        y = y + position.origin.y
        
        let newPosition2: CGRect = CGRect(x: x, y: y, width: width, height: height)
        
        // Create the Shape layer.
        let faceBoundingBoxShape = CAShapeLayer()
        faceBoundingBoxShape.path = CGPath(rect: newPosition2, transform: nil)
        faceBoundingBoxShape.fillColor = NSColor.clear.cgColor
        faceBoundingBoxShape.strokeColor = NSColor.green.cgColor
        faceBoundingBoxShape.lineWidth = 2.0
        
        faceRectangleLayer.addSublayer(faceBoundingBoxShape)
        
        imageView.layer?.addSublayer(faceRectangleLayer)
    }
    
}
