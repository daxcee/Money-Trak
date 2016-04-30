//
//  Transactions.swift
//  My Money
//
//  Created by Aaron Bratcher on 09/01/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

let _searchQueue = dispatch_queue_create("com.AaronLBratcher.MyMoneySearch", DISPATCH_QUEUE_SERIAL)

final class TransactionsController: UITableViewController, EditTransactionProtocol, AccountCellDelegate, AccountDelegate, Numbers {
	@IBOutlet weak var searchbar: UISearchBar!

	var inSummary = false
	var upcomingTransactions = false
	var recurringTransactions = false
	var transactionKeys = [String]() {
		didSet {
			if let text = self.searchbar.text where text.characters.count > 0 {
				_sum = CommonDB.sumTransactions(transactionKeys, table: kTransactionsTable)
			} else {
				_sum = nil
			}
		}
	}

	private var _currentAccountKey = CommonFunctions.currentAccountKey
	private var _accountView: AccountView?
	private var _lastSelection: NSIndexPath?
	private var _searching = false
	private var _sum: Int?

	enum Segue: String {
		case SetAccount
		case AddTransaction
		case EditTransaction
	}

	override func viewDidLoad() {
		if !upcomingTransactions && !recurringTransactions {
			if !inSummary, let accountView = NSBundle.mainBundle().loadNibNamed("AccountView", owner: self, options: nil)[0] as? AccountView {
				self._accountView = accountView
				accountView.delegate = self
				updateAccountInfo()

				if let searchbar = searchbar, keys = ALBNoSQLDB.keysInTable(kReconcilationsTable, sortOrder: nil) where keys.count > 0 {
					searchbar.showsScopeBar = true
					searchbar.scopeButtonTitles = ["All", "Outstanding", "Cleared"]
					searchbar.backgroundColor = UIColor.whiteColor()
					searchbar.selectedScopeButtonIndex = 0
					searchbar.sizeToFit()
				}
			}
		}

		if upcomingTransactions {
			NSNotificationCenter.defaultCenter().addObserverForName(kUpdateUpcomingTransactionsNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) -> Void in
				self.loadTransactions(.all(""))
				self.tableView.reloadData()
			})
		}

		if !inSummary {
			loadTransactions(.all(""))
		}

		if let searchbar = searchbar {
			let keyboardToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 34))
			keyboardToolbar.barStyle = UIBarStyle.BlackTranslucent
			keyboardToolbar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 34)
			let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
			let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: #selector(doneTyping))
			doneButton.tintColor = UIColor.whiteColor()
			keyboardToolbar.items = [flexSpace, doneButton]

			searchbar.inputAccessoryView = keyboardToolbar
		}
	}

	private func updateAccountInfo() {
		_accountView?.account = Account(key: _currentAccountKey)!
	}

	override func viewWillAppear(animated: Bool) {
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
		if searchbar.text?.characters.count > 0 {
			searchbar.showsCancelButton = true
		}
	}

	override func viewDidAppear(animated: Bool) {
		if let lastSelection = _lastSelection {
			self.tableView.selectRowAtIndexPath(lastSelection, animated: true, scrollPosition: UITableViewScrollPosition.None)

			delay(1.0, closure: { () -> () in
				self.tableView.deselectRowAtIndexPath(lastSelection, animated: true)
				self._lastSelection = nil
			})
		}
	}

	override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
		return UIInterfaceOrientation.Portrait
	}

	override func shouldAutorotate() -> Bool {
		return false
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segue(rawValue: segue.identifier!) {
			switch segueName {

			case .SetAccount:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! SelectAccountController
				controller.currentAccountKey = _currentAccountKey
				controller.accountDelegate = self

			case .AddTransaction:
				fallthrough

			case .EditTransaction:
				let controller: EditEntryController

				if let navController = segue.destinationViewController as? UINavigationController {
					controller = navController.viewControllers[0] as! EditEntryController
				} else {
					controller = segue.destinationViewController as! EditEntryController
				}

				controller.delegate = self
				controller.upcomingTransaction = upcomingTransactions
				controller.recurringTransaction = recurringTransactions

				if segue.identifier == "EditTransaction" {
					let indexPath = sender as! NSIndexPath
					let key = transactionKeys[indexPath.row]
					if upcomingTransactions {
						controller.transaction = UpcomingTransaction(key: key)!
						controller.title = "Edit Upcoming"
					} else {
						if recurringTransactions {
							controller.transaction = RecurringTransaction(key: key)!
							controller.title = "Edit Recurring"
						} else {
							controller.showAccountSelector = false
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

	func loadTransactions(filter: TransactionFilter) {
		if recurringTransactions {
			transactionKeys = CommonDB.recurringTransactionKeys(filter)
		} else {
			if upcomingTransactions {
				transactionKeys = CommonDB.upcomingTransactionKeys(filter)
			} else {
				transactionKeys = CommonDB.transactionKeys(filter)
			}
		}

		dispatch_async(dispatch_get_main_queue(), { () -> Void in
			self.tableView.reloadData()
		})
	}

	// MARK: - Other

	func accountCellTapped() {
		performSegueWithIdentifier(Segue.SetAccount.rawValue, sender: nil)
	}

	@IBAction func addTapped(sender: AnyObject) {
		performSegueWithIdentifier(Segue.AddTransaction.rawValue, sender: nil)
	}

	func accountSet(account: Account) {
		_currentAccountKey = account.key
		CommonFunctions.currentAccountKey = _currentAccountKey
		updateAccountInfo()
		processSearchText()
	}

	func ccAccountSet(account: Account) {
		// not used
	}

	func deleteTransaction(row: Int) {
		var transaction: Transaction?
		var indexPath = NSIndexPath(forRow: row, inSection: 0)

		if upcomingTransactions {
			transaction = UpcomingTransaction(key: transactionKeys[row])
		} else {
			if recurringTransactions {
				transaction = RecurringTransaction(key: transactionKeys[row])
			} else {
				transaction = Transaction(key: transactionKeys[row])
				indexPath = NSIndexPath(forRow: row, inSection: 0)
			}
		}

		if transaction != nil {
			transaction?.delete()
			transactionKeys.removeAtIndex(row)
			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
			updateAccountInfo()
		}
	}

	func transactionAdded(transaction: Transaction) {
		transactionKeys.insert(transaction.key, atIndex: 0)

		let path = NSIndexPath(forRow: 0, inSection: 0)
		tableView.insertRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.Top)
		updateAccountInfo()
	}

	func transactionUpdated(transaction: Transaction) {
		var path = NSIndexPath(forRow: 0, inSection: 0)

		for index in 0 ..< transactionKeys.count {
			if transactionKeys[index] == transaction.key {
				path = NSIndexPath(forRow: index, inSection: 0)
				break
			}
		}

		tableView.reloadRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.None)
		updateAccountInfo()
	}

	@IBAction func doneTapped(sender: AnyObject) {
		dismissViewControllerAnimated(true, completion: nil);
	}
}

// MARK: - TableView
extension TransactionsController {
	override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if _accountView != nil {
			return 40
		}

		return 0
	}

	override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return _accountView
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return 60
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return transactionKeys.count
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let transactionCell = tableView.dequeueReusableCellWithIdentifier("TransactionCell", forIndexPath: indexPath) as! TransactionCell
		transactionCell.upcomingTransaction = upcomingTransactions
		transactionCell.recurringTransaction = recurringTransactions
		transactionCell.transactionKey = transactionKeys[indexPath.row]

		return transactionCell
	}

	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		if recurringTransactions || upcomingTransactions {
			return true
		}

		let transaction = Transaction(key: transactionKeys[indexPath.row])!
		return !transaction.reconciled
	}

	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == UITableViewCellEditingStyle.Delete {
			// if recurring, delete all remaining upcoming
			if recurringTransactions {
				let transaction = RecurringTransaction(key: transactionKeys[indexPath.row])!
				let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: transaction.recurringTransactionKey)
				let keys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: nil, conditions: [recurringCondition])
				if keys == nil {
					delay(0.5, closure: { () -> () in
						self.tableView.setEditing(false, animated: true)
					})
					return
				}

				if keys!.count == 0 {
					self.deleteTransaction(indexPath.row)
				} else {
					SweetAlert().showAlert("Delete Recurring?", subTitle: "\(keys!.count) pending transactions will be deleted.", style: AlertStyle.Warning, buttonTitle: "Cancel", buttonColor: UIColorFromRGB(0x909090), otherButtonTitle: "Delete", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in
						if isOtherButton == true {
							self.tableView.setEditing(false, animated: true)
						}
						else {
							for key in keys! {
								let upcoming = UpcomingTransaction(key: key)!
								upcoming.delete()
							}
							self.deleteTransaction(indexPath.row)
							SweetAlert().showAlert("Complete", subTitle: "Recurring transactions have been deleted.", style: AlertStyle.Success)
						}
					}
				}
			} else {
				deleteTransaction(indexPath.row)
			}
		}
	}

	override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
		_lastSelection = indexPath
		performSegueWithIdentifier(Segue.EditTransaction.rawValue, sender: indexPath)
	}

	override func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
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
	func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
		searchbar.showsCancelButton = true
		return true
	}

	func searchBar(searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		if let text = searchbar.text {
			performSearch(text, selectedScope: selectedScope)
		}
	}

	func searchBarSearchButtonClicked(searchBar: UISearchBar) {
		processSearchText()
		dispatch_async(dispatch_get_main_queue()) {
			self.view.endEditing(false)
		}
	}

	func searchBarCancelButtonClicked(searchBar: UISearchBar) {
		searchbar.text = ""
		searchbar.endEditing(true)
		performSearch("", selectedScope: searchBar.selectedScopeButtonIndex)
	}

	func searchBarShouldEndEditing(searchBar: UISearchBar) -> Bool {
		searchbar.showsCancelButton = false
		return true
	}

	func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
		processSearchText()
	}

	func textFieldShouldReturn(textField: UITextField) -> Bool {
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

		dispatch_async(_searchQueue, { () -> Void in
			if let text = self.searchbar.text {
				self.performSearch(text, selectedScope: selectedScope)
			}
			self._searching = false
		})
	}

	func performSearch(text: String, selectedScope: Int) {
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