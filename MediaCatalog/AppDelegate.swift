//
//  AppDelegate.swift
//  MediaCatalog
//
//  Created by Aitor Zubizarreta on 5/6/22.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - UI Elements
    
    // MARK: - Properties
    
    lazy var mainWindowController = MainWindowController()
    
    // MARK: - Methods
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        mainWindowController.showWindow(nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
}
