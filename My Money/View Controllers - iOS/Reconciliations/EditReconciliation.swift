//
//  ReconcileAccount.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/10/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol EditReconciliationProtocol {
	func reconciliationAdded(_ reconciliation: Reconciliation)
	func reconciliationUpdated(_ reconciliation: Reconciliation)
}

class EditReconciliationController: UIViewController, ReconciliationHeaderDelegate, EditTransactionProtocol, UISearchBarDelegate, UsesCurrency {

	@IBOutlet weak var searchbar: UISearchBar!
	@IBOutlet weak var headerView: UIView!
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var endingBalance: UILabel!
	@IBOutlet weak var transactionCount: UILabel!
	@IBOutlet weak var difference: UILabel!

	@IBOutlet weak var tableConstraint: NSLayoutConstraint!

	var delegate: EditReconciliationProtocol?
	var reconciliation = Reconciliation()

	fileprivate var _transactionKeys = [String]()
	fileprivate var _lastSelection: IndexPath?
	fileprivate var _searching = false
	fileprivate var _buffered = false
	fileprivate var _firstForAccount = false
	fileprivate var _initialBalanceTansactionKey: String?

	fileprivate let _keyboardToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 34))

	enum Segues: String {
		case ShowHeader = "ShowHeader"
		case EditTransaction = "EditTransaction"
		case AddTransaction = "AddTransaction"
	}

	// MARK: - View

	override func viewDidLoad() {
		super.viewDidLoad()

		if reconciliation.isNew {
			performSegue(withIdentifier: Segues.ShowHeader.rawValue, sender: nil)
			if let lastReconciliation = CommonDB.lastReconciliationForAccount(reconciliation.accountKey, ignoreUnreconciled: true) {
				reconciliation.beginningBalance = lastReconciliation.endingBalance
			} else {
				_firstForAccount = true
			}
		}

		if reconciliation.reconciled {
			navigationItem.rightBarButtonItem = nil
			navigationItem.leftBarButtonItem = nil
			headerView.removeFromSuperview()
			searchbar.removeFromSuperview()
			tableConstraint.constant = -80
		} else {
			let addButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(addTransaction))
			let saveButton = navigationItem.rightBarButtonItem!
			navigationItem.rightBarButtonItems = [saveButton, addButton]
		}

		updateHeader()
		loadTransactions()

		_keyboardToolbar.barStyle = UIBarStyle.blackTranslucent
		_keyboardToolbar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 34)
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(doneTyping))
		doneButton.tintColor = UIColor.white // (red: 0, green: 0.478431, blue: 1.0, alpha: 1.0)
		_keyboardToolbar.items = [flexSpace, doneButton]
	}

	override func viewDidAppear(_ animated: Bool) {
		if let lastSelection = _lastSelection {
			delay(0.25, closure: { () -> () in
				self.tableView.selectRow(at: lastSelection, animated: true, scrollPosition: UITableViewScrollPosition.none)
				delay(1.0, closure: { () -> () in
					self.tableView.deselectRow(at: lastSelection, animated: true)
					self._lastSelection = nil
				})
			})
		}

		searchbar.inputAccessoryView = _keyboardToolbar
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier != nil, let segueName = Segues(rawValue: segue.identifier!) {
			switch segueName {
			case .ShowHeader:
				let controller = segue.destination as! EditReconciliationHeaderController
				controller.reconciliation = reconciliation
				controller.delegate = self

			case .EditTransaction:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! EditEntryController
				controller.delegate = self

				let indexPath = sender as! IndexPath
				let key = _transactionKeys[(indexPath as NSIndexPath).row]
				controller.showAccountSelector = false
				controller.transaction = Transaction(key: key)!
				controller.title = "Edit Transaction"

			case .AddTransaction:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! EditEntryController
				controller.delegate = self
				controller.maxDate = reconciliation.date
				controller.showAccountSelector = false
				controller.title = "Add Transaction"
			}
		}
	}

	// MARK: - Misc

	func doneTyping() {
		view.endEditing(true)
	}

	func reconciliationHeaderChanged() {
		if _firstForAccount {
			if let key = _initialBalanceTansactionKey {
				CommonDB.updateInitialBalanceTransaction(key, reconciliation: reconciliation)
			} else {
				_initialBalanceTansactionKey = CommonDB.createInitialBalanceTransaction(reconciliation)
			}
		}

		loadTransactions()
		updateHeader()
	}

	func loadTransactions(_ searchString: String? = nil) {
		_searching = true

		CommonDB.loadTransactionsForReconciliation(reconciliation, searchString: searchString) { (transactionKeys) -> () in
			DispatchQueue.main.async(execute: { () -> Void in
				self._transactionKeys = transactionKeys
				self.tableView.reloadData()
				self._searching = false
			})
		}
	}

	func updateHeader() {
		endingBalance.text = formatForAmount(reconciliation.endingBalance, useThousandsSeparator: true)
		let countString = formatInteger(reconciliation.transactionKeys.count)
		transactionCount.text = countString
		difference.text = formatForAmount(reconciliation.difference, useThousandsSeparator: true)
	}

	// MARK: - Searchbar
	func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
		searchbar.showsCancelButton = true
		return true
	}

	func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		if let text = searchbar.text {
			performSearch(text)
		}
	}

	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		searchbar.text = ""
		searchbar.endEditing(true)
		performSearch("")
	}

	func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
		searchbar.showsCancelButton = false
		return true
	}

	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		// if a search is already in progress... wait a second before doing a search.
		// Only do this dispatch once per search.
		if _searching {
			if !_buffered {
				_buffered = true
				DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1000000000), execute: { () -> Void in
					if let text = self.searchbar.text {
						self.performSearch(text)
					}
					self._searching = false
				})
			}

			return
		}

		var useText = true
		if let text = searchBar.text, text.characters.count < 2 {
			useText = false
		}

		_buffered = false

		if let text = searchbar.text {
			performSearch(useText ? text : "")
		}
	}

	func performSearch(_ text: String) {
		loadTransactions(text)
	}

	// MARK: - User Actions

	@IBAction func headerTapped(_ sender: AnyObject) {
		performSegue(withIdentifier: Segues.ShowHeader.rawValue, sender: nil)
	}

	@IBAction func cancelTapped(_ sender: AnyObject) {
		// TODO: Show alert if changes made

		if reconciliation.isNew {
			dismiss(animated: true, completion: nil)
		} else {
			let _ = navigationController?.popViewController(animated: true)
		}
	}

	@IBAction func saveTapped(_ sender: AnyObject) {
		doneTyping()

		if reconciliation.difference == 0 && reconciliation.transactionKeys.count > 0 {
			DispatchQueue.main.async(execute: { [unowned self]() -> Void in
				SweetAlert().showAlert("Reconciled?", subTitle: "Save this as fully reconciled? This cannot be undone.", style: AlertStyle.warning, buttonTitle: "Yes", buttonColor: UIColorFromRGB(0x909090), otherButtonTitle: "No", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in

					if isOtherButton == true {
						let _ = CozyLoadingActivity.show("Saving...", sender: self, disableUI: true)

						dbProcessingQueue.async(execute: { () -> Void in
							self.reconciliation.reconciled = true
							for key in self.reconciliation.transactionKeys {
								let transaction = Transaction(key: key)!
								transaction.reconciled = true
								transaction.save()
							}

							let _ = CozyLoadingActivity.hide(success: true, animated: true)

							DispatchQueue.main.async(execute: { () -> Void in
								self.closeView()
							})
						})
					} else {
						self.closeView()
					}
				}
			})
		} else {
			self.closeView()
		}
	}

	func closeView() {
		reconciliation.save()

		if reconciliation.isNew {
			dismiss(animated: true, completion: { () -> Void in
				self.delegate?.reconciliationAdded(self.reconciliation)
				return
			})
		} else {
			let _ = navigationController?.popViewController(animated: true)
			delegate?.reconciliationUpdated(reconciliation)
		}
	}

	func addTransaction() {
		performSegue(withIdentifier: Segues.AddTransaction.rawValue, sender: nil)
	}

	func transactionAdded(_ transaction: Transaction) {
		var index = 0
		for key in _transactionKeys {
			let testTransaction = Transaction(key: key)!
			let testDate = testTransaction.date.stringValue()
			let date = transaction.date.stringValue()
			if date > testDate {
				break
			} else {
				index += 1
			}
		}

		_transactionKeys.insert(transaction.key, at: index)
		let path = IndexPath(row: index, section: 0)
		if _transactionKeys.count > 5 {
			self.tableView.scrollToRow(at: path, at: UITableViewScrollPosition.middle, animated: true)
		}
		self.tableView.insertRows(at: [path], with: UITableViewRowAnimation.top)
		self.tableView.selectRow(at: path, animated: true, scrollPosition: .middle)
		delay(0.5, closure: { () -> () in
			self.tableView(self.tableView, didSelectRowAt: path)
			self.tableView.deselectRow(at: path, animated: true)
		})
	}

	func transactionUpdated(_ transaction: Transaction) {
		var path = IndexPath(row: 0, section: 0)

		for index in 0 ..< _transactionKeys.count {
			if _transactionKeys[index] == transaction.key {
				path = IndexPath(row: index, section: 0)
				break
			}
		}

		tableView.reloadRows(at: [path], with: UITableViewRowAnimation.none)
	}
}

// MARK: - TableView
extension EditReconciliationController: UITableViewDataSource, UITableViewDelegate {
	func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return _transactionKeys.count
		} else {
			return 1
		}
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if (indexPath as NSIndexPath).section == 0 {
			return tableView.rowHeight
		}

		return 44
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		var tableCell: UITableViewCell
		if (indexPath as NSIndexPath).section == 0 {
			var cell: TransactionCell
			if let transaction = Transaction(key: _transactionKeys[(indexPath as NSIndexPath).row]) {
				if transaction.checkNumber != nil && transaction.checkNumber! > 0 {
					cell = tableView.dequeueReusableCell(withIdentifier: "CheckCell") as! TransactionCell
				} else {
					cell = tableView.dequeueReusableCell(indexPath: indexPath) as TransactionCell
				}
				cell.transactionKey = _transactionKeys[(indexPath as NSIndexPath).row]
				if !reconciliation.reconciled {
					let cleared = reconciliation.transactionKeys.filter({ $0 == transaction.key }).count > 0
					cell.reconciled = cleared
				}
			} else {
				cell = tableView.dequeueReusableCell(indexPath: indexPath) as TransactionCell
			}

			tableCell = cell
		} else {
			let cell = tableView.dequeueReusableCell(indexPath: indexPath) as ClearAllCell
			cell.delegate = self

			tableCell = cell
		}

		return tableCell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if reconciliation.reconciled {
			tableView.deselectRow(at: indexPath, animated: true)
			return
		}

		delay(1.0, closure: { () -> () in
			tableView.deselectRow(at: indexPath, animated: true)
		})

		let key = _transactionKeys[(indexPath as NSIndexPath).row]
		if reconciliation.hasTransactionKey(key) {
			reconciliation.removeTransactionKey(key)
		} else {
			reconciliation.addTransactionKey(key)
		}

		updateHeader()
		tableView.reloadRows(at: [indexPath], with: .none)
	}

	func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
		_lastSelection = indexPath
		performSegue(withIdentifier: Segues.EditTransaction.rawValue, sender: indexPath)
	}
}

extension EditReconciliationController: ClearAllProtocol {
	func clearAllTapped() {
		SweetAlert().showAlert("Clear Selections?", subTitle: "All selections will be cleared.", style: AlertStyle.warning, buttonTitle: "Cancel", buttonColor: UIColorFromRGB(0x909090), otherButtonTitle: "Clear", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in

			if !isOtherButton {
				self.reconciliation.transactionKeys.removeAll()
				self.tableView.reloadData()
				self.updateHeader()
			}
		}
	}
}
