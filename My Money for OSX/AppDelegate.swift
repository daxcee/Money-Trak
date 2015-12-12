//
//  AppDelegate.swift
//  My Money for OSX
//
//  Created by Aaron Bratcher on 08/20/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
                            


    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        CommonDB.setup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(theApplication: NSApplication!) -> Bool {
        return true
    }

    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }


}

