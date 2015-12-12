//
//  Accounts.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/24/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Cocoa

protocol AccountSaved {
    func saveAccount(account:Account)
}
@IBOutlet weak var accountType: UISegmentedControl!

class EditAccountController:NSViewController {

    @IBOutlet weak var accountName: NSTextField!
    @IBOutlet weak var typeCell: UITableViewCell!
    @IBOutlet weak var updateTotalCell: UITableViewCell!
    @IBOutlet weak var updateTotalCell: UITableViewCell!
    @IBOutlet weak var accountType: NSPopUpButton!
    @IBOutlet weak var balance: NSTextField!
    @IBOutlet weak var totalCredit: NSTextField!
    @IBOutlet weak var creditAvailableCell: UITableViewCell!
    @IBOutlet weak var creditAvailableCell: UITableViewCell!
    @IBOutlet weak var creditAvailableCell: UITableViewCell!
    @IBOutlet weak var creditAvailableCell: UITableViewCell!
    @IBOutlet weak var updateTotal: NSButton!

    var popover:NSPopover?
    var account:Account?
    var delegate:AccountSaved?
    
    override func viewWillAppear() {
        if account == nil {
            setFrame()
            return;
        }
        
        accountName.stringValue = account!.name
        accountType.stringValue = account!.type
        totalCredit.stringValue = CommonFunctions.intFormatForAmount(account!.maxBalance)
        updateTotal.state = (account!.updateTotal == true ? NSOnState : NSOffState)
     }
    
    
    @IBAction func typeChanged(sender: AnyObject) {
        setFrame()
    }
    
    func setFrame() {
        var frame = view.frame
        let type = accountType.titleOfSelectedItem
        if type != nil && type == "Credit Card" {
            frame.size.height = 231
            totalCredit.hidden = false
        } else {
            frame.size.height = 231-32
            totalCredit.hidden = true
        }
        view.frame = frame
    }
    
    @IBAction func saveClicked(sender: AnyObject) {
        if account == nil {
            account = Account()
            account?.name = accountName.stringValue
            account?.type = accountType.stringValue
            account?.balance = Int(floor(startingBlance.doubleValue * 100))
        }
        
        delegate!.saveAccount(account!)
        dismissController(self)
    }
    
}