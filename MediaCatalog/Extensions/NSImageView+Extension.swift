//
//  NSImageView+Extension.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 23/7/22.
//

import Foundation
import AppKit

extension NSImageView {
    
    func loadFrom(localPath: URL) {
        DispatchQueue.main.async { [weak self] in
            if let imageData = try? Data(contentsOf: localPath) {
                if let safeImage = NSImage(data: imageData) {
                    self?.image = safeImage
                }
            }
        }
    }
    
}
