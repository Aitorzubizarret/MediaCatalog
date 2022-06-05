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
    
    public enum ExtensionType {
        case RAWPhoto
        case JPEGPhoto
        case all
    }
    
    // MARK: - Methods
    
    init(name: String, thumbnailImage: NSImage) {
        self.name = name
        self.thumbnailImage = thumbnailImage
    }
    
    public func getName() -> String {
        return name
    }
    
    public func getThumbnailImage() -> NSImage {
        return thumbnailImage
    }
    
}
