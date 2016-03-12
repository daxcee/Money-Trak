//
//  SelectAccount.swift
//  My Money
//
//  Created by Aaron Bratcher on 11/6/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol AccountDelegate {
	func accountSet(account: Account)
	func ccAccountSet(account: Account)
}

class SelectAccountController: UITableViewController, Numbers {
	var accountDelegate: AccountDelegate?
	var currentAccountKey = ""
	var includeCreditCards = true
	var includeNonCreditCards = true

	private var _accountKeys = [String]()

	override func viewDidLoad() {
		if !includeCreditCards || !includeNonCreditCards {
			let ccCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: (includeCreditCards ? .equal : .notEqual), value: "Credit Card")
			if let keys = ALBNoSQLDB.keysInTableForConditions(kAccountsTable, sortOrder: "name", conditions: [ccCondition]) {
				_accountKeys = keys
			}
		} else {
			if let keys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder: "name") {
				_accountKeys = keys
			}
		}

		let stack = navigationController?.viewControllers
		if stack!.count == 1 {
			navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "dismissController")
		}
	}

	func dismissController() {
		self.dismissViewControllerAnimated(true, completion: nil)
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return _accountKeys.count
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
		let account = Account(key: _accountKeys[indexPath.row])!
		cell.textLabel?.text = account.name
		cell.detailTextLabel?.text = formatForAmount(account.balance, useThousandsSeparator: true)

		if account.key == currentAccountKey {
			cell.accessoryType = UITableViewCellAccessoryType.Checkmark
		} else {
			cell.accessoryType = UITableViewCellAccessoryType.None
		}

		return cell
	}

	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		currentAccountKey = _accountKeys[indexPath.row]

		if includeNonCreditCards {
			accountDelegate?.accountSet(Account(key: currentAccountKey)!)
		} else {
			accountDelegate?.ccAccountSet(Account(key: currentAccountKey)!)
		}

		tableView.reloadData()
	}
}