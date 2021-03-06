//
//  AccountController.swift
//  My Money
//
//  Created by Aaron Bratcher on 09/04/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import ALBNoSQLDB

protocol EditAccountDelegate {
	func accountCreated(_ account: Account)
	func accountUpdated(_ account: Account)
}

protocol AccountTypeDelegate {
	func accountTypeSelected(_ type: AccountType)
}

protocol UpdateDelegate {
	func updateTotalSelected()
}

class AccountsController: UITableViewController, EditAccountDelegate {
	var accountKeys = [String]()

	enum Segue: String {
		case addAccount
		case editAccount
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		if let accounts = ALBNoSQLDB.keysInTable(Table.accounts, sortOrder: "name") {
			accountKeys = accounts
		}
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let identifier = segue.identifier, let segueName =  Segue(rawValue: identifier) else { return }
		
			switch segueName {
			case .addAccount:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! EditAccountController
				controller.delegate = self

			case .editAccount:
				let controller = segue.destination as! EditAccountController
				controller.delegate = self
				let indexPath = self.tableView.indexPathForSelectedRow
				let row = (indexPath as NSIndexPath?)?.row
				let key = accountKeys[row!]
				let account = Account(key: key)
				controller.account = account
		}
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return accountKeys.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! AccountCell
		let accountKey = accountKeys[(indexPath as NSIndexPath).row]
		cell.account = Account(key: accountKey)!

		return cell
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == UITableViewCellEditingStyle.delete {
			SweetAlert().showAlert("Delete Account?", subTitle: "All related transactions and reconciliations will be deleted. This cannot be undone.", style: AlertStyle.warning, buttonTitle: "Cancel", buttonColor: UIColorFromRGB(0x909090), otherButtonTitle: "Delete", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in

				if isOtherButton == true {
					self.tableView.setEditing(false, animated: true)
				}
				else {
					self.deleteAccount(indexPath)
				}
			}
		}
	}

	func deleteAccount(_ indexPath: IndexPath) {
		let accountKey = self.accountKeys[(indexPath as NSIndexPath).row]
		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: accountKey as AnyObject)
		var error = false

		// delete relevant reconciliations
		if let reconciliationKeys = ALBNoSQLDB.keysInTableForConditions(Table.reconciliations, sortOrder: nil, conditions: [accountCondition]) {
			for key in reconciliationKeys {
				let _ = ALBNoSQLDB.deleteForKey(table: Table.reconciliations, key: key)
			}
		} else {
			error = true
		}

		// delete transactions
		if !error, let transactionKeys = ALBNoSQLDB.keysInTableForConditions(Table.transactions, sortOrder: nil, conditions: [accountCondition]) {
			for key in transactionKeys {
				let _ = ALBNoSQLDB.deleteForKey(table: Table.transactions, key: key)
			}
		} else {
			error = true
		}

		// delete upcoming transactions
		if !error, let upcomingKeys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: nil, conditions: [accountCondition]) {
			for key in upcomingKeys {
				let _ = ALBNoSQLDB.deleteForKey(table: Table.upcomingTransactions, key: key)
			}
		} else {
			error = true
		}
		// delete recurring transactions
		if !error, let recurringKeys = ALBNoSQLDB.keysInTableForConditions(Table.recurringTransactions, sortOrder: nil, conditions: [accountCondition]) {
			for key in recurringKeys {
				let _ = ALBNoSQLDB.deleteForKey(table: Table.recurringTransactions, key: key)
			}
		} else {
			error = true
		}

		// delete account
		if !error {
			let _ = ALBNoSQLDB.deleteForKey(table: Table.accounts, key: accountKey)
		}

		if error {
			let _ = SweetAlert().showAlert("Deletion Error", subTitle: "There has been an error deleting the account.", style: AlertStyle.error)
		} else {
			let _ = SweetAlert().showAlert("Complete", subTitle: "Account has been deleted.", style: AlertStyle.success)
			self.accountKeys = self.accountKeys.filter({ $0 != accountKey })
			tableView.deleteRows(at: [indexPath], with: .fade)
			CommonDB.recalculateAllBalances()
		}
	}

	func accountCreated(_ account: Account) {
		var index = 0
		for key in accountKeys {
			let testAccount = Account(key: key)!
			if account.name < testAccount.name {
				break
			} else {
				index += 1
			}
		}

		accountKeys.insert(account.key, at: index)
		let path = IndexPath(row: index, section: 0)
		self.tableView.insertRows(at: [path], with: UITableViewRowAnimation.top)
	}

	func accountUpdated(_ account: Account) {
		var index = 0
		for key in accountKeys {
			let testAccount = Account(key: key)!
			if account.name == testAccount.name {
				let indexPath = IndexPath(row: index, section: 0)
				self.tableView.reloadRows(at: [indexPath], with: .automatic)
			} else {
				index += 1
			}
		}
	}

	@IBAction func addTapped(_ sender: AnyObject) {
		performSegue(withIdentifier: Segue.addAccount.rawValue, sender: nil)
	}
}

class AccountCell: UITableViewCell, UsesCurrency {
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
