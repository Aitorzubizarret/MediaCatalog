//
//  FilesDB.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Foundation
import AppKit
import SQLite3

final class FilesDB {
    
    // MARK: - Properties
    
    static var shared = FilesDB() // Singleton.
    
    /// SQLite
    var db: OpaquePointer?
    let dbFileName: String = "MediaCatalogDB.sqlite"
    let thumbnailsFolderName = "MediaCatalogThumbnails"
    var selectedCatalogFolder: String = ""
    var dbFilePath: URL?
    
    public var selectedPath: URL? {
        didSet {
            guard let safePath = selectedPath else { return }
            
            // Clear files array.
            files = []
            
            RAWPhotos = 0
            HEICPhotos = 0
            JPEGPhotos = 0
            PNGPhotos = 0
            GIFPhotos = 0
            BMPPhotos = 0
            WEBPPhotos = 0
            
            let selectedFilesURLs: [URL] = contentsOf(folder: safePath)
            
            populateDB(filesURLs: selectedFilesURLs)
        }
    }
    public var getFilesInsideFolders: Bool = true
    
    public var files: [File] = []
    public var filteredFiles: [File] = []
    
    private var RAWPhotos: Int = 0
    private var HEICPhotos: Int = 0
    private var JPEGPhotos: Int = 0
    private var PNGPhotos: Int = 0
    private var GIFPhotos: Int = 0
    private var BMPPhotos: Int = 0
    private var WEBPPhotos: Int = 0
    
    // MARK: - Methods
    
    init() {}
    
    public func getFile(at: Int) -> File? {
        if files.count > at {
            return filteredFiles[at]
        } else {
            return nil
        }
    }
    
    public func eraseAll() {
        files = []
        filteredFiles = []
    }
    
    public func count(extensionType: File.ExtensionType) -> Int {
        switch extensionType {
        case .RAWPhoto:
            return RAWPhotos
        case .HEICPhoto:
            return HEICPhotos
        case .JPEGPhoto:
            return JPEGPhotos
        case .PNGPhoto:
            return PNGPhotos
        case .GIFPhoto:
            return GIFPhotos
        case .BMPPhoto:
            return BMPPhotos
        case .WEBPPhoto:
            return WEBPPhotos
        case .all:
            return files.count
        }
    }
    
    ///
    /// Creates a File element for every file URL and appends it to files array.
    ///
    private func populateDB(filesURLs: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async {
            for fileURL in filesURLs {
                
                // File name.
                var fileName: String = ""
                if let safeFileName = fileURL.pathComponents.last {
                    let nameComponents = safeFileName.components(separatedBy: ".")
                    let cleanNameComponents = nameComponents.dropLast()
                    for component in cleanNameComponents {
                        fileName += component
                    }
                }
                
                // File type/extension.
                let fileType: String = fileURL.pathExtension
                
                // Thumbnail image path (if created).
                var thumbnailPath: URL?
                
                // Check file extension.
                switch fileURL.pathExtension {
                case "arw", "ARW", "nef", "NEF", "cr2", "CR2":
                    self.RAWPhotos += 1
                    // Create the thumbnail image.
                    let fileThumbnailImage: NSImage = self.createThumbnail(fileURL: fileURL)
                    
                    // Save the Thumbnail image locally.
                    thumbnailPath = self.saveThumbnailLocally(name: fileName, image: fileThumbnailImage)
                case "heic", "HEIC":
                    self.HEICPhotos += 1
                    // FIXME: This still doesn't work :-(
                    //fileThumbnailImage = self.convertHEICToJPG(fileURL: fileURL)
                case "jpg", "JPG", "jpeg", "JPEG":
                    self.JPEGPhotos += 1
                    // Maybe later we are going to create thumbnails for the big JPG photos.
                case "png", "PNG":
                    self.PNGPhotos += 1
                    // Maybe later we are going to create thumbnails for the big PNG photos.
                case "gif", "GIF":
                    self.GIFPhotos += 1
                case "bmp", "BMP":
                    self.BMPPhotos += 1
                case "webp", "WEBP":
                    self.WEBPPhotos += 1
                default:
                    print("Other extension \(fileURL.pathExtension)")
                }
                
                // Create the File element.
                let file = File(name: fileName, type: fileType, originalPath: fileURL, thumbnailPath: thumbnailPath)
                
                // Append the new File to the files array of the PhotosDB.
                self.files.append(file)
                
                // Safe File object in SQLite DB.
                self.saveFileInDB(file: file)
            }
            
            self.filteredFiles = self.files
            
            NotificationCenter.default.post(name: Notification.Name("PhotosDB-Populated"), object: nil)
        }
    }
    
    ///
    /// Gets the content (files) inside the selected folder.
    ///
    private func contentsOf(folder: URL) -> [URL] {
        let fileManager = FileManager.default
        
        var urls: [URL] = []
        
        if getFilesInsideFolders {
            if let enumerator = fileManager.enumerator(at: folder,
                                                       includingPropertiesForKeys: [.isRegularFileKey],
                                                       options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let fileurl as URL in enumerator {
                    do {
                        let fileAttributes = try fileurl.resourceValues(forKeys: [.isRegularFileKey])
                        if fileAttributes.isRegularFile! {
                            urls.append(fileurl)
                        }
                    } catch {
                        print("Error \(error)")
                    }
                }
            }
        } else {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: folder.path)
                
                urls = contents.map { return folder.appendingPathComponent($0) }
                print("Files inside the selected folder. \(urls)")

                ///
                /// Filter urls and avoid :
                /// - Folders
                /// - .DS_Store file.
                ///
                urls = urls.filter { $0.lastPathComponent != ".DS_Store" && !$0.hasDirectoryPath }
            } catch {
                print("Error \(error)")
            }
        }
        
        return urls
    }
    
    ///
    /// Creates a thumbnail image of the received file.
    ///
    private func createThumbnail(fileURL: URL) -> NSImage {
        // File thumbnail image.
        var newThumbnailImage: NSImage = NSImage()
        
        // Open the RAW file.
        if let rawImageFilter = CIRAWFilter(imageURL: fileURL),
           let rawImage = rawImageFilter.outputImage {
            
            let rep = NSCIImageRep(ciImage: rawImage)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)
            
            // Check image size to avoid trying to scale a file that is not an image.
            if rep.size.width != 0 && rep.size.height != 0 {
                
                // Resize the image.
                let thumbnailSize = NSSize(width: 800, height: 600)
                var newSize: NSSize = NSSize(width: 0, height: 0)
                
                let widthRatio = thumbnailSize.width / rep.size.width
                let heightRatio = thumbnailSize.height / rep.size.height
                
                if widthRatio > heightRatio {
                    newSize = NSSize(width: floor(rep.size.width * widthRatio), height: floor(rep.size.height * widthRatio))
                } else {
                    newSize = NSSize(width: floor(rep.size.width * heightRatio), height: floor(rep.size.height * heightRatio))
                }
                
                let thumbnailFrame = NSMakeRect(0, 0, newSize.width, newSize.height)
                
                if let resizedImageRep = nsImage.bestRepresentation(for: thumbnailFrame, context: nil, hints: nil) {
                    let img = NSImage(size: newSize)
                    
                    // Set the drawing context and make sure to remove the focus before returning.
                    img.lockFocus()
                    defer { img.unlockFocus() }
                    
                    if resizedImageRep.draw(in: thumbnailFrame) {
                        newThumbnailImage = img
                    }
                }
            }
        }
        
        return newThumbnailImage
    }
    
    ///
    /// Save the thumbnail of an image locally.
    ///
    private func saveThumbnailLocally(name: String, image: NSImage) -> URL? {
        guard let url: URL = URL(string: "file://\(selectedCatalogFolder)/\(thumbnailsFolderName)/\(name).jpg") else { return nil }
        
        if let ci = image.cgImage(forProposedRect: nil, context: nil, hints: nil).map({ CIImage(cgImage: $0) }),
           let jpg = CIContext().jpegRepresentation(of: ci, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) {
            do {
                try jpg.write(to: url)
                return url
            } catch let error {
                print("Error saving image. \(error.localizedDescription)")
                return nil
            }
        } else {
            return nil
        }
    }
    
    // FIXME: This still doesn't work :-(
    ///
    /// Converts HEIC photos into JPG.
    ///
//    private func convertHEICToJPG(fileURL: URL) -> NSImage {
//        // NSImage.
//        var imageConverted: NSImage = NSImage()
//
//        do {
//            // Data as CFData
//            let data: CFData = try Data(contentsOf: fileURL) as CFData
//
//            // CGImageSource
//            if let imageSource = CGImageSourceCreateWithData(data, nil) {
//
//                // CGImage
//                if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
//                    imageConverted = NSImage(cgImage: cgImage, size: .init(width: cgImage.width, height: cgImage.height))
//                }
//            }
//        } catch let error {
//            print("Error \(error)")
//        }
//
//        return imageConverted
//    }
    
    ///
    /// Filters the files by an extension group.
    ///
    public func filterFilesBy(_ group: FileExtensionGroup) {
        filteredFiles = []
        
        switch group {
        case .all:
            filteredFiles = files
        case .photos:
            filteredFiles = files.filter( {
                $0.getName().contains("arw") ||
                $0.getName().contains("ARW") ||
                $0.getName().contains("nef") ||
                $0.getName().contains("NEF") ||
                $0.getName().contains("cr2") ||
                $0.getName().contains("CR2") ||
                $0.getName().contains("heic") ||
                $0.getName().contains("HEIC") ||
                $0.getName().contains("jpg") ||
                $0.getName().contains("JPG") ||
                $0.getName().contains("jpeg") ||
                $0.getName().contains("JPEG") ||
                $0.getName().contains("png") ||
                $0.getName().contains("PNG") ||
                $0.getName().contains("bmp") ||
                $0.getName().contains("BMP") ||
                $0.getName().contains("webp") ||
                $0.getName().contains("WEBP")
            } )
        case .videos:
            filteredFiles = files.filter( {
                $0.getName().contains("mp4") ||
                $0.getName().contains("MP4") ||
                $0.getName().contains("mov") ||
                $0.getName().contains("MOV") ||
                $0.getName().contains("gif") ||
                $0.getName().contains("GIF")
            } )
        case .others:
            filteredFiles = files.filter( {
                !$0.getName().contains("arw") &&
                !$0.getName().contains("ARW") &&
                !$0.getName().contains("nef") &&
                !$0.getName().contains("NEF") &&
                !$0.getName().contains("cr2") &&
                !$0.getName().contains("CR2") &&
                !$0.getName().contains("heic") &&
                !$0.getName().contains("HEIC") &&
                !$0.getName().contains("jpg") &&
                !$0.getName().contains("JPG") &&
                !$0.getName().contains("jpeg") &&
                !$0.getName().contains("JPEG") &&
                !$0.getName().contains("png") &&
                !$0.getName().contains("PNG") &&
                !$0.getName().contains("bmp") &&
                !$0.getName().contains("BMP") &&
                !$0.getName().contains("webp") &&
                !$0.getName().contains("WEBP") &&
                !$0.getName().contains("mp4") &&
                !$0.getName().contains("MP4") &&
                !$0.getName().contains("mov") &&
                !$0.getName().contains("MOV") &&
                !$0.getName().contains("gif") &&
                !$0.getName().contains("GIF")
            } )
        }
        
        NotificationCenter.default.post(name: Notification.Name("PhotosDB-Populated"), object: nil)
    }
    
}

// MARK: - SQLite

extension FilesDB {
    
    ///
    /// Creates a Catalog (SQLite) file.
    ///
    func createCatalogFile(window: NSWindow?) {
        guard let safeWindow = window else { return }
        
        // NS Open Panel.
        let openPanel = NSOpenPanel()
        openPanel.title = "Select the folder where you want to save the Catalog file."
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        
        // File Manager.
        let fileManager = FileManager.default
        
        openPanel.beginSheetModal(for: safeWindow) { result in
            if result == NSApplication.ModalResponse.OK {
                if let safePath: URL = openPanel.urls.first {
                    let filePath: String = safePath.path + "/" + "\(self.dbFileName)"
                    
                    // Check SQLite file exists before creating one.
                    if fileManager.fileExists(atPath: filePath) {
                        // FIXME: - Show a message to the user.
                        print("Error: There is already a Catalog file in the selected folder.")
                    } else {
                        // SQLite file.
                        fileManager.createFile(atPath: safePath.path, contents: nil)
                        self.createCatalogStructure(filePath: filePath)
                    }
                    
                    // Check Thumbnails folder exists before creating one.
                    let folderPath: String = safePath.path + "/" + self.thumbnailsFolderName
                    do {
                        try fileManager.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
                    } catch let error {
                        print("Error creating folder \(error)")
                    }
                }
            }
        }
    }
    
    ///
    /// Open an existing Catalog (SQLite) file.
    ///
    func openCatalogFile(window: NSWindow?) {
        guard let safeWindow = window else { return }
        
        // NS Open Panel.
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        
        // File Manager.
        let fileManager = FileManager.default
        
        openPanel.beginSheetModal(for: safeWindow) { result in
            if result == NSApplication.ModalResponse.OK {
                if let safePath: URL = openPanel.urls.first {
                    self.selectedCatalogFolder = safePath.path
                    let filePath: String = safePath.path + "/" + "\(self.dbFileName)"
                    
                    // Check SQLite file.
                    if !fileManager.fileExists(atPath: filePath) {
                        // FIXME: - Show a message to the user.
                        print("Error: There is NO Catalog file in the selected folder.")
                    } else {
                        print("Success: Catalog file found.")
                        if sqlite3_open(filePath, &self.db) == SQLITE_OK {
                            print("Successfully opened connection to database")
                        } else {
                            print("Unable to open database.")
                        }
                    }
                }
            }
        }
    }
    
    ///
    /// Create the Catalog SQLite DB Structure.
    ///
    func createCatalogStructure(filePath: String) {
        if sqlite3_open(filePath, &db) == SQLITE_OK {
            print("Catalog SQLITE open")
        } else {
            print("Error opening the file")
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error creating table: \(errmsg)")
            return
        }
        
        let createFilesTableQuery = """
        CREATE TABLE IF NOT EXISTS Files (
            Id INTEGER PRIMARY KEY AUTOINCREMENT,
            Name TEXT,
            Type TEXT,
            OriginalPath TEXT,
            ThumbnailPath TEXT
        )
        """
        
        if sqlite3_exec(db, createFilesTableQuery, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error creating table: \(errmsg)")
        }
    }
    
    ///
    ///
    ///
    private func saveFileInDB(file: File) {
        guard let safeDB = db else { return }

        var insertStatement: OpaquePointer?
        let insertStatementString = "INSERT INTO Files(Name, Type, OriginalPath, ThumbnailPath) VALUES (?, ?, ?, ?);"

        if sqlite3_prepare_v2(self.db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            // Get values.
            let name: NSString = file.getName() as NSString
            let type: NSString = file.getType() as NSString
            let originalPath: NSString = file.getOriginalPath().path as NSString
            var thumbnailPath: NSString = ""
            if let safeThumbnailPathURL: URL = file.getThumbnailImagePath() {
                thumbnailPath = safeThumbnailPathURL.path as NSString
            }
            
            sqlite3_bind_text(insertStatement, 1, name.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, type.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, originalPath.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, thumbnailPath.utf8String, -1, nil)

            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Successfully inserted")
            } else {
                print("Error inserting")
            }
        } else {
            print("InsertStatement is not prepared")
        }

        sqlite3_finalize(insertStatement)
    }
    
}
