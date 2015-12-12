//
//  Setup.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/26/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import AppKit

class SetupController:NSViewController, AccountSaved {
    override func prepareForSegue(segue: NSStoryboardSegue!, sender: AnyObject!) {
        if segue.identifier == "AddAccount" {
            let controller = segue.destinationController as EditAccountController
            controller.delegate = self
        }
    }

    func saveAccount(account: Account) {
        var newAccount = false
        if account.key == nil {
            newAccount = true
            account.key = SimpleDB.guid()
        }
        
        account.save()
        //TODO: animate insert of new account into list
    }
}

class AccountTable:NSObject,NSTableViewDataSource,NSTableViewDelegate {
    var accounts = SimpleDB.keysInTable(kAccountsTable)
    
    func numberOfRowsInTableView(tableView: NSTableView!) -> Int {
        return accounts.count
    }
    
    func tableView(tableView: NSTableView!, objectValueForTableColumn tableColumn: NSTableColumn!, row: Int) -> AnyObject! {
        let account = SimpleDB.instanceOfClassForKey(accounts[row] as String, inTable: kAccountsTable) as Account
        let value = account.valueForKey(tableColumn.identifier) as String
        return value
    }
}