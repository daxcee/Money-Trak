//
//  Transactions.swift
//  My Money
//
//  Created by Aaron Bratcher on 09/01/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import ALBNoSQLDB

let _searchQueue = DispatchQueue(label: "com.AaronLBratcher.MyMoneySearch")

final class TransactionsController: UITableViewController, EditTransactionProtocol, AccountCellDelegate, AccountDelegate, UsesCurrency {
	@IBOutlet weak var searchbar: UISearchBar!

	var inSummary = false
	var upcomingTransactions = false
	var recurringTransactions = false
	var transactionKeys = [String]() {
		didSet {
			if let text = self.searchbar.text, text.characters.count > 0 {
				_sum = CommonDB.sumTransactions(transactionKeys, table: Table.transactions)
			} else {
				_sum = nil
			}
		}
	}

	fileprivate var _currentAccountKey = CommonFunctions.currentAccountKey
	fileprivate var _accountView: AccountView?
	fileprivate var _lastSelection: IndexPath?
	fileprivate var _searching = false
	fileprivate var _sum: Int?

	enum Segue: String {
		case setAccount
		case addTransaction
		case editTransaction
	}

	override func viewDidLoad() {
		if !upcomingTransactions && !recurringTransactions {
			if !inSummary, let accountView = Bundle.main.loadNibNamed("AccountView", owner: self, options: nil)?[0] as? AccountView {
				self._accountView = accountView
				accountView.delegate = self
				updateAccountInfo()

				if let searchbar = searchbar, let keys = ALBNoSQLDB.keysInTable(Table.reconciliations, sortOrder: nil), keys.count > 0 {
					searchbar.showsScopeBar = true
					searchbar.scopeButtonTitles = ["All", "Outstanding", "Cleared"]
					searchbar.backgroundColor = UIColor.white
					searchbar.selectedScopeButtonIndex = 0
					searchbar.sizeToFit()
				}
			}
		}

		if upcomingTransactions {
			NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: kUpdateUpcomingTransactionsNotification), object: nil, queue: OperationQueue.main, using: { (notification) -> Void in
				self.loadTransactions(.all(""))
				self.tableView.reloadData()
			})
		}

		if !inSummary {
			loadTransactions(.all(""))
		}

		if let searchbar = searchbar {
			let keyboardToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 34))
			keyboardToolbar.barStyle = UIBarStyle.blackTranslucent
			keyboardToolbar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 34)
			let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
			let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(doneTyping))
			doneButton.tintColor = UIColor.white
			keyboardToolbar.items = [flexSpace, doneButton]

			searchbar.inputAccessoryView = keyboardToolbar
		}
	}

	private func updateAccountInfo() {
		_accountView?.account = Account(key: _currentAccountKey)!
	}

	override func viewWillAppear(_ animated: Bool) {
		if upcomingTransactions {
			navigationItem.title = "Upcoming"
		} else {
			if recurringTransactions {
				navigationItem.title = "Recurring"
			} else {
				navigationItem.title = "Transactions"
			}
		}
	}

	func doneTyping() {
		searchbar.resignFirstResponder()
		guard let text = searchbar.text, text.characters.count > 0 else { return }
		searchbar.showsCancelButton = true
	}

	override func viewDidAppear(_ animated: Bool) {
		if let lastSelection = _lastSelection {
			self.tableView.selectRow(at: lastSelection, animated: true, scrollPosition: UITableViewScrollPosition.none)

			delay(0.5, closure: { () -> () in
				self.tableView.deselectRow(at: lastSelection, animated: true)
				self._lastSelection = nil
			})
		}
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier != nil, let segueName = Segue(rawValue: segue.identifier!) {
			switch segueName {

			case .setAccount:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! SelectAccountController
				controller.currentAccountKey = _currentAccountKey
				controller.accountDelegate = self

			case .addTransaction, .editTransaction:
				let controller: EditEntryController

				if let navController = segue.destination as? UINavigationController {
					controller = navController.viewControllers[0] as! EditEntryController
				} else {
					controller = segue.destination as! EditEntryController
				}

				controller.delegate = self
				controller.upcomingTransaction = upcomingTransactions
				controller.recurringTransaction = recurringTransactions

				if segueName == .editTransaction {
					let indexPath = sender as! IndexPath
					let key = transactionKeys[(indexPath as NSIndexPath).row]
					if upcomingTransactions {
						controller.transaction = UpcomingTransaction(key: key)!
						controller.title = "Edit Upcoming"
					} else {
						if recurringTransactions {
							controller.transaction = RecurringTransaction(key: key)!
							controller.title = "Edit Recurring"
						} else {
							controller.transaction = Transaction(key: key)!
							controller.title = "Edit Transaction"
						}
					}
				} else {
					if recurringTransactions {
						controller.title = "Add Recurring"
					} else {
						if upcomingTransactions {
							controller.title = "Add Upcoming"
						} else {
							controller.showAccountSelector = false
							controller.title = "Add Transaction"
						}
					}
				}
			}
		}
	}

	func loadTransactions(_ filter: TransactionFilter) {
		if recurringTransactions {
			transactionKeys = CommonDB.recurringTransactionKeys(filter)
		} else {
			if upcomingTransactions {
				transactionKeys = CommonDB.upcomingTransactionKeys(filter)
			} else {
				transactionKeys = CommonDB.transactionKeys(filter)
			}
		}

		DispatchQueue.main.async(execute: { () -> Void in
			self.tableView.reloadData()
		})
	}

	// MARK: - Other

	func accountCellTapped() {
		performSegue(withIdentifier: Segue.setAccount.rawValue, sender: nil)
	}

	@IBAction func addTapped(_ sender: AnyObject) {
		performSegue(withIdentifier: Segue.addTransaction.rawValue, sender: nil)
	}

	func accountSet(_ account: Account) {
		_currentAccountKey = account.key
		CommonFunctions.currentAccountKey = _currentAccountKey
		updateAccountInfo()
		processSearchText()
	}

	func ccAccountSet(_ account: Account) {
		// not used
	}

	func deleteTransaction(_ row: Int) {
		var transaction: Transaction?
		var indexPath = IndexPath(row: row, section: 0)

		if upcomingTransactions {
			transaction = UpcomingTransaction(key: transactionKeys[row])
		} else {
			if recurringTransactions {
				transaction = RecurringTransaction(key: transactionKeys[row])
			} else {
				transaction = Transaction(key: transactionKeys[row])
				indexPath = IndexPath(row: row, section: 0)
			}
		}

		if transaction != nil {
			transaction?.delete()
			transactionKeys.remove(at: row)
			tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.fade)
			updateAccountInfo()
		}
	}

	func transactionAdded(_ transaction: Transaction) {
		transactionKeys.insert(transaction.key, at: 0)

		let path = IndexPath(row: 0, section: 0)
		tableView.insertRows(at: [path], with: UITableViewRowAnimation.top)
		updateAccountInfo()
	}

	func transactionUpdated(_ transaction: Transaction) {
		var path = IndexPath(row: 0, section: 0)

		for index in 0 ..< transactionKeys.count {
			if transactionKeys[index] == transaction.key {
				path = IndexPath(row: index, section: 0)
				break
			}
		}

		tableView.reloadRows(at: [path], with: UITableViewRowAnimation.none)
		updateAccountInfo()
	}

	@IBAction func doneTapped(_ sender: AnyObject) {
		dismiss(animated: true, completion: nil);
	}
}

// MARK: - TableView
extension TransactionsController {
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if _accountView != nil {
			return 40
		}

		return 0
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return _accountView
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 60
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return transactionKeys.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let transactionCell = tableView.dequeueReusableCell(withIdentifier: "TransactionCell", for: indexPath) as! TransactionCell
		transactionCell.upcomingTransaction = upcomingTransactions
		transactionCell.recurringTransaction = recurringTransactions
		transactionCell.transactionKey = transactionKeys[(indexPath as NSIndexPath).row]

		return transactionCell
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		if recurringTransactions || upcomingTransactions {
			return true
		}

		let transaction = Transaction(key: transactionKeys[(indexPath as NSIndexPath).row])!
		return !transaction.reconciled
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == UITableViewCellEditingStyle.delete {
			// if recurring, delete all remaining upcoming
			if recurringTransactions {
				let transaction = RecurringTransaction(key: transactionKeys[(indexPath as NSIndexPath).row])!
				let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: transaction.recurringTransactionKey as AnyObject)
				let keys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: nil, conditions: [recurringCondition])
				if keys == nil {
					delay(0.5, closure: { () -> () in
						self.tableView.setEditing(false, animated: true)
					})
					return
				}

				if keys!.count == 0 {
					self.deleteTransaction((indexPath as NSIndexPath).row)
				} else {
					SweetAlert().showAlert("Delete Recurring?", subTitle: "\(keys!.count) pending transactions will be deleted.", style: AlertStyle.warning, buttonTitle: "Cancel", buttonColor: UIColorFromRGB(0x909090), otherButtonTitle: "Delete", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in
						if isOtherButton == true {
							self.tableView.setEditing(false, animated: true)
						} else {
							for key in keys! {
								let upcoming = UpcomingTransaction(key: key)!
								upcoming.delete()
							}
							self.deleteTransaction((indexPath as NSIndexPath).row)
							let _ = SweetAlert().showAlert("Complete", subTitle: "Recurring transactions have been deleted.", style: AlertStyle.success)
						}
					}
				}
			} else {
				deleteTransaction((indexPath as NSIndexPath).row)
			}
		}
	}

	override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
		_lastSelection = indexPath
		performSegue(withIdentifier: Segue.editTransaction.rawValue, sender: indexPath)
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if let sum = _sum {
			let entryName = transactionKeys.count == 1 ? "entry" : "entries"
			return "\(transactionKeys.count) \(entryName) \n \(formatForAmount(sum, useThousandsSeparator: true))"
		} else {
			return nil
		}
	}
}

// MARK: - Search Bar
extension TransactionsController: UISearchBarDelegate {
	func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
		searchbar.showsCancelButton = true
		return true
	}

	func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		if let text = searchbar.text {
			performSearch(text, selectedScope: selectedScope)
		}
	}

	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		processSearchText()
		DispatchQueue.main.async {
			self.view.endEditing(false)
		}
	}

	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		searchbar.text = ""
		searchbar.endEditing(true)
		performSearch("", selectedScope: searchBar.selectedScopeButtonIndex)
	}

	func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
		searchbar.showsCancelButton = false
		return true
	}

	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		processSearchText()
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		view.endEditing(false)

		return true
	}

	func processSearchText() {
		if _searching {
			return
		}

		_searching = true

		let selectedScope: Int
		if searchbar.showsScopeBar {
			selectedScope = searchbar.selectedScopeButtonIndex
		} else {
			selectedScope = 0
		}

		_searchQueue.async(execute: { () -> Void in
			if let text = self.searchbar.text {
				self.performSearch(text, selectedScope: selectedScope)
			}
			self._searching = false
		                   })
	}

	func performSearch(_ text: String, selectedScope: Int) {
		switch selectedScope {
		case 1:
			loadTransactions(.outstanding(text))
		case 2:
			loadTransactions(.cleared(text))
		default:
			loadTransactions(.all(text))
		}
	}
}
