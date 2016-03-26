//
//  AccountController.swift
//  My Money
//
//  Created by Aaron Bratcher on 09/04/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol EditAccountDelegate {
	func accountCreated(account: Account)
	func accountUpdated(account: Account)
}

protocol AccountTypeDelegate {
	func accountTypeSelected(type: AccountType)
}

protocol UpdateDelegate {
	func updateTotalSelected()
}

class AccountsController: UITableViewController, EditAccountDelegate {
	var accountKeys = [String]()

	enum Segues: String {
		case AddAccount = "AddAccount"
		case EditAccount = "EditAccount"
		case PurchaseAccount = "PurchaseAccount"
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		if let accounts = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder: "name") {
			accountKeys = accounts
		}

		if PurchaseKit.sharedInstance.maxAccounts() == kDefaultAccounts {
			PurchaseKit.sharedInstance.loadProductsForScreen(.Accounts)
			NSNotificationCenter.defaultCenter().addObserverForName(kPurchaseSuccessfulNotification, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
				if let userInfo = notification.userInfo as? [String: String], identifier = userInfo[kProductIdentifierKey] where identifier == StoreProducts.AddMultipleAccounts.rawValue {
					delay(1.0, closure: { () -> () in
						self.addTapped(self)
					})
				}
			}
		}
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segues(rawValue: segue.identifier!) {
			switch segueName {
			case .AddAccount:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! EditAccountController
				controller.delegate = self

			case .EditAccount:
				let controller = segue.destinationViewController as! EditAccountController
				controller.delegate = self
				let indexPath = self.tableView.indexPathForSelectedRow
				let row = indexPath?.row
				let key = accountKeys[row!]
				let account = Account(key: key)
				controller.account = account

			case .PurchaseAccount:
				let controller = segue.destinationViewController as! MakePurchaseController
				controller.products = PurchaseKit.sharedInstance.availableProductsForScreen(.Accounts)
			}
		}
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return accountKeys.count
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! AccountCell
		let accountKey = accountKeys[indexPath.row]
		cell.account = Account(key: accountKey)!

		return cell
	}

	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}

	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == UITableViewCellEditingStyle.Delete {
			SweetAlert().showAlert("Delete Account?", subTitle: "All related transactions and reconciliations will be deleted. This cannot be undone.", style: AlertStyle.Warning, buttonTitle: "Cancel", buttonColor: UIColorFromRGB(0x909090), otherButtonTitle: "Delete", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in

				if isOtherButton == true {
					self.tableView.setEditing(false, animated: true)
				}
				else {
					self.deleteAccount(indexPath)
				}
			}
		}
	}

	func deleteAccount(indexPath: NSIndexPath) {
		let accountKey = self.accountKeys[indexPath.row]
		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: accountKey)
		var error = false

		// delete relevant reconciliations
		if let reconciliationKeys = ALBNoSQLDB.keysInTableForConditions(kReconcilationsTable, sortOrder: nil, conditions: [accountCondition]) {
			for key in reconciliationKeys {
				ALBNoSQLDB.deleteForKey(table: kReconcilationsTable, key: key)
			}
		} else {
			error = true
		}

		// delete transactions
		if !error, let transactionKeys = ALBNoSQLDB.keysInTableForConditions(kTransactionsTable, sortOrder: nil, conditions: [accountCondition]) {
			for key in transactionKeys {
				ALBNoSQLDB.deleteForKey(table: kTransactionsTable, key: key)
			}
		} else {
			error = true
		}

		// delete upcoming transactions
		if !error, let upcomingKeys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: nil, conditions: [accountCondition]) {
			for key in upcomingKeys {
				ALBNoSQLDB.deleteForKey(table: kUpcomingTransactionsTable, key: key)
			}
		} else {
			error = true
		}
		// delete recurring transactions
		if !error, let recurringKeys = ALBNoSQLDB.keysInTableForConditions(kRecurringTransactionsTable, sortOrder: nil, conditions: [accountCondition]) {
			for key in recurringKeys {
				ALBNoSQLDB.deleteForKey(table: kRecurringTransactionsTable, key: key)
			}
		} else {
			error = true
		}

		// delete account
		if !error {
			ALBNoSQLDB.deleteForKey(table: kAccountsTable, key: accountKey)
		}

		if error {
			SweetAlert().showAlert("Deletion Error", subTitle: "There has been an error deleting the account.", style: AlertStyle.Error)
		} else {
			SweetAlert().showAlert("Complete", subTitle: "Account has been deleted.", style: AlertStyle.Success)
			self.accountKeys = self.accountKeys.filter({ $0 != accountKey })
			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
			CommonDB.recalculateAllBalances()
		}
	}

	func accountCreated(account: Account) {
		var index = 0
		for key in accountKeys {
			let testAccount = Account(key: key)!
			if account.name < testAccount.name {
				break
			} else {
				index += 1
			}
		}

		accountKeys.insert(account.key, atIndex: index)
		let path = NSIndexPath(forRow: index, inSection: 0)
		self.tableView.insertRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.Top)
	}

	func accountUpdated(account: Account) {
		var index = 0
		for key in accountKeys {
			let testAccount = Account(key: key)!
			if account.name == testAccount.name {
				let indexPath = NSIndexPath(forRow: index, inSection: 0)
				self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
			} else {
				index += 1
			}
		}
	}

	@IBAction func addTapped(sender: AnyObject) {
		purchaseSegue(self, screen: .Accounts, segue: Segues.AddAccount.rawValue, purchaseSegue: Segues.PurchaseAccount.rawValue)
	}
}

class AccountCell: UITableViewCell, Numbers {
	@IBOutlet weak var name: UILabel!
	@IBOutlet weak var type: UILabel!
	@IBOutlet weak var balance: UILabel!

	var account: Account {
		get {
			return Account()
		}

		set(account) {
			name.text = account.name
			type.text = account.type.rawValue
			balance.text = formatForAmount(account.balance, useThousandsSeparator: true)
		}
	}
}
