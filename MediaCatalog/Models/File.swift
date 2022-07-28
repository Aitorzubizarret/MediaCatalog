//
//  File.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Foundation
import AppKit

struct File {
    
    // MARK: - Properties
    
    private let name: String
    private let thumbnailImage: NSImage
    private let originalPath: URL
    
    public enum ExtensionType {
        case RAWPhoto
        case JPEGPhoto
        case PNGPhoto
        case GIFPhoto
        case BMPPhoto
        case WEBPPhoto
        
//        case WEBLOCDoc
//        case PDFDoc
//        case DOCDoc
//        case RTFDoc
//        case TXTDoc
//        case PSDFile
//        case ZIPFile
//        case MP4Video
//        case MOVVideo
//        case 3GPVideo
//        case AVIVideo
//        case M1VVideo
//        case WMVVideo
//        case MP3Audio
        
        case all
    }
    
    // MARK: - Methods
    
    init(name: String, thumbnailImage: NSImage, originalPath: URL) {
        self.name = name
        self.thumbnailImage = thumbnailImage
        self.originalPath = originalPath
    }
    
    public func getName() -> String {
        return name
    }
    
    public func getThumbnailImage() -> NSImage {
        return thumbnailImage
    }
    
    public func getOriginalPath() -> URL {
        return originalPath
    }
    
}
