//
//  FilesDB.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Foundation
import AppKit

final class FilesDB {
    
    // MARK: - Properties
    
    static var shared = FilesDB() // Singleton.
    
    public var selectedPath: URL? {
        didSet {
            guard let safePath = selectedPath else { return }
            
            // Clear files array.
            files = []
            
            RAWPhotos = 0
            JPEGPhotos = 0
            PNGPhotos = 0
            
            let selectedFilesURLs: [URL] = contentsOf(folder: safePath)
            
            populateDB(filesURLs: selectedFilesURLs)
        }
    }
    public var getFilesInsideFolders: Bool = true
    
    public var files: [File] = []
    
    private var RAWPhotos: Int = 0
    private var JPEGPhotos: Int = 0
    private var PNGPhotos: Int = 0
    
    // MARK: - Methods
    
    init() {}
    
    public func getFile(at: Int) -> File? {
        if files.count > at {
            return files[at]
        } else {
            return nil
        }
    }
    
    public func eraseAll() {
        files = []
    }
    
    public func count(extensionType: File.ExtensionType) -> Int {
        switch extensionType {
        case .RAWPhoto:
            return RAWPhotos
        case .JPEGPhoto:
            return JPEGPhotos
        case .PNGPhoto:
            return PNGPhotos
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
                    fileName = safeFileName
                }
                
                // File thumbnail image.
                var fileThumbnailImage: NSImage = NSImage()
                
                // Check file extension.
                switch fileURL.pathExtension {
                case "ARW":
                    self.RAWPhotos += 1
                    fileThumbnailImage = self.createThumbnail(fileURL: fileURL)
                case "jpg", "JPG", "jpeg", "JPEG":
                    self.JPEGPhotos += 1
                    // Maybe later we are going to create thumbnails for the big JPG photos.
                case "png", "PNG":
                    self.PNGPhotos += 1
                    // Maybe later we are going to create thumbnails for the big PNG photos.
                default:
                    print("Rest of the files")
                }
                
                // Create the File element.
                let file = File(name: fileName, thumbnailImage: fileThumbnailImage, originalPath: fileURL)
                
                // Append the new File to the files array of the PhotosDB.
                self.files.append(file)
            }
            
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
    
}
