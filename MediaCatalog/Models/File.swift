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
    
}
