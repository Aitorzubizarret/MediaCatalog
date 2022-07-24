//
//  ViewerViewController.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 22/7/22.
//

import Cocoa

class ViewerViewController: NSViewController {
    
    // MARK: - UI Elements
    
    @IBOutlet weak var importFolderButton: NSButtonCell!
    @IBAction func importFolderButtonTapped(_ sender: Any) {
        loadImages()
    }
    
    @IBOutlet weak var closePhotoButton: NSButton!
    @IBAction func closePhotoButtonTapped(_ sender: Any) {
        photoOnDisplay = false
    }
    
    @IBOutlet weak var detectFacesButton: NSButton!
    @IBAction func detectFacesButtonTapped(_ sender: Any) {
        detectFaces()
    }
    
    @IBOutlet weak var importedFilesTypesLabel: NSTextField!
    
    @IBOutlet weak var collectionViewScrollView: NSScrollView!
    @IBOutlet weak var collectionView: NSCollectionView!
    
    @IBOutlet weak var imageView: NSImageView!
    
    // MARK: - Properties
    
    private var photoOnDisplay: Bool = false {
        didSet {
            if photoOnDisplay {
                closePhotoButton.isHidden = false
                detectFacesButton.isHidden = false
                imageView.isHidden = false
                collectionViewScrollView.isHidden = true
                collectionView.isHidden = true
            } else {
                closePhotoButton.isHidden = true
                detectFacesButton.isHidden = true
                imageView.isHidden = true
                imageView.image = NSImage()
                faceRectangleLayer.sublayers?.removeAll()
                collectionViewScrollView.isHidden = false
                collectionView.isHidden = false
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
        setupCollectionView()
    }
    
    ///
    /// Setup the view.
    ///
    private func setupView() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUI), name: NSNotification.Name("PhotosDB-Populated"), object: nil)
        
        // Labels.
        importedFilesTypesLabel.stringValue = ""
        
        // NSImageView.
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

        // File Manager.
        let fileManagerPanel = NSOpenPanel()
        fileManagerPanel.canChooseFiles = false
        fileManagerPanel.canChooseDirectories = true
        fileManagerPanel.allowsMultipleSelection = false
        
        fileManagerPanel.beginSheetModal(for: window) { result in
            self.photoOnDisplay = false
            self.importedFilesTypesLabel.stringValue = "importing..."
            
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
        
        faceRectangleLayer.frame = imageView.frame
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
        var y: CGFloat = (imageView.frame.height / 2) - (safeImage.size.height / 2)
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
