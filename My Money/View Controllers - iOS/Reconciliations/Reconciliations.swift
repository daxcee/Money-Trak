//
//  Reconciliations.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/18/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class ReconciliationsController: UITableViewController, EditReconciliationProtocol, AccountCellDelegate, AccountDelegate {
	var reconciliationKeys = [String]()
	var currentAccountKey = CommonFunctions.currentAccountKey

	private var accountView: AccountView?

	enum Segue: String {
		case ViewReconciliation = "ViewReconciliation"
		case AddReconciliation = "AddReconciliation"
		case SetAccount = "SetAccount"
	}

	override func viewDidLoad() {
		if let accountView = Bundle.main.loadNibNamed("AccountView", owner: self, options: nil)?[0] as? AccountView {
			self.accountView = accountView
			accountView.delegate = self
			updateAccountInfo()
		}
	}

	private func updateAccountInfo() {
		accountView?.account = Account(key: currentAccountKey)!
		reconciliationKeys = CommonDB.accountReconciliations(currentAccountKey)
		tableView.reloadData()
	}

	func prepare(for segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segue(rawValue: segue.identifier!) {
			switch segueName {
			case .ViewReconciliation:
				let controller = segue.destination as! EditReconciliationController
				controller.reconciliation = Reconciliation(key: sender as! String)!
				controller.delegate = self

			case .AddReconciliation:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! EditReconciliationController
				controller.delegate = self

			case .SetAccount:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! SelectAccountController
				controller.currentAccountKey = currentAccountKey
				controller.accountDelegate = self
			}
		}
	}

	// MARK: - TableView
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if accountView != nil {
			return 56
		}

		return 0
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return accountView
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return reconciliationKeys.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! ReconciliationCell
		cell.reconciliationKey = reconciliationKeys[(indexPath as NSIndexPath).row]

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		performSegue(withIdentifier: Segue.ViewReconciliation.rawValue, sender: reconciliationKeys[(indexPath as NSIndexPath).row])
	}

	// MARK: - User Actions

	@IBAction func doneTapped(_ sender: AnyObject) {
		dismiss(animated: true, completion: nil)
	}

	@IBAction func addTapped(_ sender: AnyObject) {
		// see if last reconciliation is complete
		if let reconciliation = CommonDB.lastReconciliationForAccount(currentAccountKey, ignoreUnreconciled: false) {
			if !reconciliation.reconciled {
				let _ = SweetAlert().showAlert("Incomplete", subTitle: "The last reconciliation must be complete before adding more.", style: AlertStyle.error)

				return
			}
		}

		performSegue(withIdentifier: Segue.AddReconciliation.rawValue, sender: self)
	}

// MARK: - Delegate Calls

	func reconciliationAdded(_ reconciliation: Reconciliation) {
		reconciliationKeys.insert(reconciliation.key, at: 0)

		let path = IndexPath(row: 0, section: 0)
		tableView.insertRows(at: [path], with: UITableViewRowAnimation.top)
	}

	func reconciliationUpdated(_ reconciliation: Reconciliation) {
		var path = IndexPath(row: 0, section: 0)

		for index in 0 ..< reconciliationKeys.count {
			if reconciliationKeys[index] == reconciliation.key {
				path = IndexPath(row: index, section: 0)
				break
			}
		}

		tableView.reloadRows(at: [path], with: UITableViewRowAnimation.none)
	}

	func accountCellTapped() {
		performSegue(withIdentifier: Segue.SetAccount.rawValue, sender: nil)
	}

	func accountSet(_ account: Account) {
		currentAccountKey = account.key
		CommonFunctions.currentAccountKey = currentAccountKey
		updateAccountInfo()
	}

	func ccAccountSet(_ account: Account) {
	}
}

class ReconciliationCell: UITableViewCell, UsesCurrency {
	@IBOutlet weak var reconciliationDate: UILabel!
	@IBOutlet weak var reconciliationYear: UILabel!
	@IBOutlet weak var endingBalance: UILabel!

	var reconciliationKey: String {
		get {
			return ""
		}

		set(key) {
			let _reconciliation = Reconciliation(key: key)!

			reconciliationDate.text = dayFormatter.string(from: _reconciliation.date)
			reconciliationYear.text = yearFormatter.string(from: _reconciliation.date)
			endingBalance.text = formatForAmount(_reconciliation.endingBalance, useThousandsSeparator: true)
		}
	}
}
