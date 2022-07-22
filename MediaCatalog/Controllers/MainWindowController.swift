//
//  MainWindowController.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 22/7/22.
//

import Cocoa

class MainWindowController: NSWindowController {
    
    // MARK: - UI Elements
    
    // MARK: - Methods
    
    convenience init() {
        self.init(windowNibName: "MainWindowController")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        contentViewController = ViewerViewController()
    }
    
}
