//
//  SelectAccount.swift
//  My Money
//
//  Created by Aaron Bratcher on 11/6/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import ALBNoSQLDB

protocol AccountDelegate {
	func accountSet(_ account: Account)
	func ccAccountSet(_ account: Account)
}

class SelectAccountController: UITableViewController, UsesCurrency {
	var accountDelegate: AccountDelegate?
	var currentAccountKey = ""
	var includeCreditCards = true
	var includeNonCreditCards = true
	var popOnSelection = true

	private var _accountKeys = [String]()

	override func viewDidLoad() {
		if !includeCreditCards || !includeNonCreditCards {
			let ccCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: (includeCreditCards ? .equal : .notEqual), value: "Credit Card" as AnyObject)
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
			popOnSelection = false
			navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(dismissController))
		}
	}

	func dismissController() {
		if popOnSelection {
			let _ = navigationController?.popViewController(animated: true)
		} else {
			self.dismiss(animated: true, completion: nil)
		}
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return _accountKeys.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		let account = Account(key: _accountKeys[(indexPath as NSIndexPath).row])!
		cell.textLabel?.text = account.name
		cell.detailTextLabel?.text = formatForAmount(account.balance, useThousandsSeparator: true)

		if account.key == currentAccountKey {
			cell.accessoryType = UITableViewCellAccessoryType.checkmark
		} else {
			cell.accessoryType = UITableViewCellAccessoryType.none
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		currentAccountKey = _accountKeys[(indexPath as NSIndexPath).row]

		if includeNonCreditCards {
			accountDelegate?.accountSet(Account(key: currentAccountKey)!)
		} else {
			accountDelegate?.ccAccountSet(Account(key: currentAccountKey)!)
		}

		dismissController()
	}
}
