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
    
    /// Data
    var filesId: [Int] = []
    
    /// SQLite
    var db: OpaquePointer?
    let dbFileName: String = "MediaCatalogDB.sqlite"
    let thumbnailsFolderName = "MediaCatalogThumbnails"
    var selectedCatalogFolder: String = ""
    var dbFilePath: URL?
    
    /// SQL queries.
    struct SQL_QUERY {
        let FILES_COUNT = "SELECT COUNT (*) FROM Files;"
        let FILES_SELECT_WHERE_ID = "SELECT * FROM Files WHERE Id = "
        let FILES_SELECT_WHERE_TYPE_ALL = "SELECT * FROM Files"
        let FILES_SELECT_WHERE_TYPE_PHOTO = """
        SELECT * FROM Files WHERE
        Type = 'arw' OR
        Type = 'nef' OR
        Type = 'cr2' OR
        Type = 'heic' OR
        Type = 'jpg' OR
        Type = 'jpeg' OR
        Type = 'png' OR
        Type = 'bmp' OR
        Type = 'webp';
        """
        let FILES_SELECT_WHERE_TYPE_VIDEO = """
        SELECT * FROM Files WHERE
        Type = 'mp4' OR
        Type = 'mov' OR
        Type = 'gif';
        """
        let FILES_SELECT_WHERE_TYPE_OTHERS = """
        SELECT * FROM Files WHERE
        Type != 'arw' AND
        Type != 'nef' AND
        Type != 'cr2' AND
        Type != 'heic' AND
        Type != 'jpg' AND
        Type != 'jpeg' AND
        Type != 'png' AND
        Type != 'bmp' AND
        Type != 'webp' AND
        Type != 'mp4' AND
        Type != 'mov' AND
        Type != 'gif';
        """
        let FILES_INSERT_INTO = "INSERT INTO Files(Name, Type, OriginalPath, ThumbnailPath) VALUES (?, ?, ?, ?);"
    }
    
    public var getFilesInsideFolders: Bool = true
    
    private var RAWPhotos: Int = 0
    private var HEICPhotos: Int = 0
    private var JPEGPhotos: Int = 0
    private var PNGPhotos: Int = 0
    private var GIFPhotos: Int = 0
    private var BMPPhotos: Int = 0
    private var WEBPPhotos: Int = 0
    
    // MARK: - Methods
    
    init() {}
    
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
            return 0 //files.count
        }
    }
    
    ///
    /// Creates a File element for every file URL and appends it to files array.
    ///
    private func populateDB(filesURLs: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async {
            for fileURL in filesURLs {
                // File id.
                let fileId: Int = 0
                
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
                let fileType: String = fileURL.pathExtension.lowercased()
                
                // Thumbnail image path (if created).
                var thumbnailPath: URL?
                
                // Check file extension.
                switch fileURL.pathExtension.lowercased() {
                case "arw", "nef", "cr2":
                    self.RAWPhotos += 1
                    // Create the thumbnail image.
                    let fileThumbnailImage: NSImage = self.createThumbnail(fileURL: fileURL)
                    
                    // Save the Thumbnail image locally.
                    thumbnailPath = self.saveThumbnailLocally(name: fileName, image: fileThumbnailImage)
                case "heic":
                    self.HEICPhotos += 1
                    // FIXME: This still doesn't work :-(
                    //fileThumbnailImage = self.convertHEICToJPG(fileURL: fileURL)
                case "jpg", "jpeg":
                    self.JPEGPhotos += 1
                    // Maybe later we are going to create thumbnails for the big JPG photos.
                case "png":
                    self.PNGPhotos += 1
                    // Maybe later we are going to create thumbnails for the big PNG photos.
                case "gif":
                    self.GIFPhotos += 1
                case "bmp":
                    self.BMPPhotos += 1
                case "webp":
                    self.WEBPPhotos += 1
                default:
                    print("Other extension \(fileURL.pathExtension)")
                }
                
                // Create the File element.
                let file = File(id: fileId, name: fileName, type: fileType, originalPath: fileURL, thumbnailPath: thumbnailPath)
                
                // Safe File object in SQLite DB.
                self.saveFileInDB(file: file)
            }
            
            self.getFilesIdWhere(sql_query: SQL_QUERY().FILES_SELECT_WHERE_TYPE_ALL)
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
//    public func filterFilesBy(_ group: FileExtensionGroup) {
//        filteredFiles = []
//        
//        switch group {
//        case .all:
//            filteredFiles = files
//        case .photos:
//            filteredFiles = files.filter( {
//                $0.getType().contains("arw") ||
//                $0.getType().contains("nef") ||
//                $0.getType().contains("cr2") ||
//                $0.getType().contains("heic") ||
//                $0.getType().contains("jpg") ||
//                $0.getType().contains("jpeg") ||
//                $0.getType().contains("png") ||
//                $0.getType().contains("bmp") ||
//                $0.getType().contains("webp")
//            } )
//        case .videos:
//            filteredFiles = files.filter( {
//                $0.getType().contains("mp4") ||
//                $0.getType().contains("mov") ||
//                $0.getType().contains("gif")
//            } )
//        case .others:
//            filteredFiles = files.filter( {
//                !$0.getType().contains("arw") &&
//                !$0.getType().contains("nef") &&
//                !$0.getType().contains("cr2") &&
//                !$0.getType().contains("heic") &&
//                !$0.getType().contains("jpg") &&
//                !$0.getType().contains("jpeg") &&
//                !$0.getType().contains("png") &&
//                !$0.getType().contains("bmp") &&
//                !$0.getType().contains("webp") &&
//                !$0.getType().contains("mp4") &&
//                !$0.getType().contains("mov") &&
//                !$0.getType().contains("gif")
//            } )
//        }
//        
//        NotificationCenter.default.post(name: Notification.Name("PhotosDB-Populated"), object: nil)
//    }
    
}

// MARK: - NSOpenPanel

extension FilesDB {
    
    ///
    /// Import files from the folder selected by the user.
    ///
    func importFilesFromFolder(window: NSWindow?) {
        guard let window = window else { return }
        
        // File Manager.
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        openPanel.beginSheetModal(for: window) { result in
            if result == NSApplication.ModalResponse.OK {
                if let safeUrl = openPanel.urls.first {
                    self.saveURLFromOpenPanel(url: safeUrl)
                    
                    self.RAWPhotos = 0
                    self.HEICPhotos = 0
                    self.JPEGPhotos = 0
                    self.PNGPhotos = 0
                    self.GIFPhotos = 0
                    self.BMPPhotos = 0
                    self.WEBPPhotos = 0
                    
                    let selectedFilesURLs: [URL] = self.contentsOf(folder: safeUrl)
                    
                    self.populateDB(filesURLs: selectedFilesURLs)
                }
            }
        }
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
                    // Save
                    //self.saveURLFromOpenPanel(url: safePath)
                    
                    
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
                            
                            self.getURLFromOpenPanel()
                            
                            self.getFilesIdWhere(sql_query: SQL_QUERY().FILES_SELECT_WHERE_TYPE_ALL)
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
        let insertStatementString: String = SQL_QUERY().FILES_INSERT_INTO

        if sqlite3_prepare_v2(safeDB, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
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
    
    ///
    /// Gets the file with the id
    ///
    func getFile(id: Int) -> File? {
        var responseFile: File?
        
        var queryStatement: OpaquePointer?
        let queryStatementString = SQL_QUERY().FILES_SELECT_WHERE_ID + "\(id) ;"
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                // Id.
                let id: Int32 = sqlite3_column_int(queryStatement, 0)
                
                // Name.
                var name: String = ""
                if let nameUnsafe = sqlite3_column_text(queryStatement, 1) {
                    name = String(cString: nameUnsafe)
                }
                
                // Type.
                var type: String = ""
                if let typeUnsafe = sqlite3_column_text(queryStatement, 2) {
                    type = String(cString: typeUnsafe)
                }
                
                // Original Path.
                var originalPathString: String = "file://"
                if let originalpathStringUnsafe = sqlite3_column_text(queryStatement, 3) {
                    originalPathString += String(cString: originalpathStringUnsafe)
                    originalPathString = originalPathString.replacingOccurrences(of: " ", with: "%20")
                }
                let originalPath: URL = URL(string: originalPathString) ?? URL(string: "www.google.es")!
                
                // Thumbnail Path.
                var thumbnailPathString: String = "file://"
                if let thumbnailPathStringUnsafe = sqlite3_column_text(queryStatement, 4) {
                    thumbnailPathString += String(cString: thumbnailPathStringUnsafe)
                    thumbnailPathString = thumbnailPathString.replacingOccurrences(of: " ", with: "%20")
                }
                let thumbnailPath: URL? = URL(string: thumbnailPathString)
                
                // Create the File element.
                responseFile = File(id: Int(id), name: name, type: type, originalPath: originalPath, thumbnailPath: thumbnailPath)
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Query is not prepared: \(errorMessage)")
        }
        
        return responseFile
    }
    
    ///
    /// Gets Files filtered.
    ///
    func getFilesIdWhere(sql_query: String) {
        var queryStatement: OpaquePointer?
        let queryStatementString = sql_query
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            self.filesId = []
            
            while (sqlite3_step(queryStatement) == SQLITE_ROW) {
                // Id.
                let id: Int32 = sqlite3_column_int(queryStatement, 0)
                
                self.filesId.append(Int(id))
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Query is not prepared: \(errorMessage)")
        }
        
        // Notify to refresh the CollectionView.
        NotificationCenter.default.post(name: Notification.Name("PhotosDB-Populated"), object: nil)
    }
    
}

// MARK: - UserDefaults

extension FilesDB {
    
    ///
    /// Save the selected URL in UserDefaults.
    ///
    private func saveURLFromOpenPanel(url: URL) {
        do {
            let pathData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(pathData, forKey: "FolderPermission")
            guard url.startAccessingSecurityScopedResource() else {
                fatalError("Failed starting to access security scoped resource for : \(url.path)")
            }
            print("Security Scope Resource - Save URL in UserDefaults : \(url)")
        } catch let error {
            print("Error getting bookmarkData from SafePath \(error)")
        }
    }
    
    ///
    /// Get the saved URL in UserDefaults.
    ///
    private func getURLFromOpenPanel() {
        guard let pathData = UserDefaults.standard.data(forKey: "FolderPermission") else { return }
        
        var isStale = false
        do {
            let savedURL = try URL(resolvingBookmarkData: pathData,
                                   options: .withSecurityScope,
                                   relativeTo: nil,
                                   bookmarkDataIsStale: &isStale)
            
            guard savedURL.startAccessingSecurityScopedResource() else { return }
            print("Security Scope Resource - Get URL from UserDefaults : \(savedURL)")
        } catch let error {
            print("Error \(error)")
        }
    }
    
}
