//
//  SplitViewController.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/24/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import AppKit

class SplitViewController:NSSplitViewController {
    @IBOutlet weak var amountAvailable: UILabel!
    var detailPane:NSSplitViewItem?
    
    override func viewWillAppear() {
        let menuController: MenuController = splitViewItems[0].viewController as MenuController
        menuController.splitViewController = self
        menuController.setup()
    }
    
    func showController(controller:NSViewController) {
        if detailPane != nil {
            removeSplitViewItem(detailPane)
        }
        detailPane = NSSplitViewItem(viewController: controller)
        addSplitViewItem(detailPane)
    }
}


class MenuController:NSViewController {
    @IBOutlet weak var totalAvailable: NSTextField!
    
    @IBOutlet weak var transactionLogButton: NSButton!
    @IBOutlet weak var upcomingTransactionsButton: NSButton!
    @IBOutlet weak var recurringTransactionsButton: NSButton!
    @IBOutlet weak var spendingSummaryButton: NSButton!
    @IBOutlet weak var budgetsButton: NSButton!
    @IBOutlet weak var syncButton: NSButton!
    @IBOutlet weak var totalAvailable: UILabel!
    @IBOutlet weak var setupButton: NSButton!
    
    weak var splitViewController: SplitViewController!

    let kAmountAvailableKey = "amountAvailable"
    let kLastViewKey = "lastViewShown"
    var accountKeys = SimpleDB.keysInTable(kAccountsTable)

    var amountAvailable = 0
        
    func setup() {
        let defaults = NSUserDefaults.standardUserDefaults()
        if defaults.objectForKey(kAmountAvailableKey) != nil {
            amountAvailable = defaults.integerForKey(kAmountAvailableKey)
        }
        totalAvailable.stringValue = "Total Available: "+CommonFunctions.intFormatForAmount(amountAvailable)
        
        var controllerName = "Setup"
        if defaults.objectForKey(kLastViewKey) != nil {
            controllerName = defaults.stringForKey(kLastViewKey)!
        }
        
       loadStateForControllerName(controllerName)
        
        NSNotificationCenter.defaultCenter().addObserverForName("adjustAmountAvailable", object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
            self.amountAvailable += notification.object.integerValue
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setInteger(self.amountAvailable, forKey: self.kAmountAvailableKey)
            NSUserDefaults.resetStandardUserDefaults()
            self.totalAvailable.stringValue = CommonFunctions.intFormatForAmount(self.amountAvailable)
        }
    }
    
    @IBAction func buttonClicked(sender: NSButton) {
        var controllerName = ""
        
        switch(sender) {
        case transactionLogButton:
            controllerName = "LogEntries"
        case upcomingTransactionsButton:
            controllerName = "UpcomingTransactions"
        case recurringTransactionsButton:
            controllerName = "RecurringTransactions"
        case spendingSummaryButton:
            controllerName = "SpendingSummary"
        case budgetsButton:
            controllerName = "Budgets"
        case syncButton:
            controllerName = "Sync"
        default:
            controllerName = "Setup"
        }
        
        loadStateForControllerName(controllerName)
    }
    
    func loadStateForControllerName(controllerName:String) {
        transactionLogButton.state = (controllerName == "LogEntries" ? NSOnState : NSOffState)
        upcomingTransactionsButton.state = (controllerName == "UpcomingTransactions" ? NSOnState : NSOffState)
        recurringTransactionsButton.state = (controllerName == "RecurringTransactions" ? NSOnState : NSOffState)
        spendingSummaryButton.state = (controllerName == "SpendingSummary" ? NSOnState : NSOffState)
        budgetsButton.state = (controllerName == "Budgets" ? NSOnState : NSOffState)
        syncButton.state = (controllerName == "Sync" ? NSOnState : NSOffState)
        setupButton.state = (controllerName == "Setup" ? NSOnState : NSOffState)

        let controller:NSViewController? = storyboard.instantiateControllerWithIdentifier(controllerName) as? NSViewController
        if controller != nil {
            splitViewController.showController(controller!)
        }
        
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject(controllerName, forKey: kLastViewKey)
        NSUserDefaults.resetStandardUserDefaults()
    }
}