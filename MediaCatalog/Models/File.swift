//
//  File.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Foundation
import AppKit

public enum FileExtensionGroup {
    case all
    case photos
    case videos
    case others
}

struct File {
    
    // MARK: - Properties
    
    private let id: Int
    private let name: String
    private let type: String
    private let creationDate: String
    private let originalPath: URL
    private let thumbnailPath: URL?
    
    public enum ExtensionType {
        case RAWPhoto
        case HEICPhoto
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
    
    init(id: Int, name: String, type: String, creationDate: String, originalPath: URL, thumbnailPath: URL?) {
        self.id = id
        self.name = name
        self.type = type
        self.creationDate = creationDate
        self.originalPath = originalPath
        self.thumbnailPath = thumbnailPath
    }
    
    public func getId() -> Int {
        return id
    }
    
    public func getName() -> String {
        return name
    }
    
    public func getType() -> String {
        return type
    }
    
    public func getCreationDate() -> String {
        return creationDate
    }
    
    public func getOriginalPath() -> URL {
        return originalPath
    }
    
    public func getThumbnailImagePath() -> URL? {
        return thumbnailPath
    }
    
}
