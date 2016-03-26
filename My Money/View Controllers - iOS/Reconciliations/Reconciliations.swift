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
		if let accountView = NSBundle.mainBundle().loadNibNamed("AccountView", owner: self, options: nil)[0] as? AccountView {
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

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segue(rawValue: segue.identifier!) {
			switch segueName {
			case .ViewReconciliation:
				let controller = segue.destinationViewController as! EditReconciliationController
				controller.reconciliation = Reconciliation(key: sender as! String)!
				controller.delegate = self

			case .AddReconciliation:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! EditReconciliationController
				controller.delegate = self

			case .SetAccount:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! SelectAccountController
				controller.currentAccountKey = currentAccountKey
				controller.accountDelegate = self
			}
		}
	}

	// MARK: - TableView
	override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if accountView != nil {
			return 56
		}

		return 0
	}

	override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return accountView
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return reconciliationKeys.count
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("Cell") as! ReconciliationCell
		cell.reconciliationKey = reconciliationKeys[indexPath.row]

		return cell
	}

	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		performSegueWithIdentifier(Segue.ViewReconciliation.rawValue, sender: reconciliationKeys[indexPath.row])
	}

	// MARK: - User Actions

	@IBAction func doneTapped(sender: AnyObject) {
		dismissViewControllerAnimated(true, completion: nil)
	}

	@IBAction func addTapped(sender: AnyObject) {
		// see if last reconciliation is complete
		if let reconciliation = CommonDB.lastReconciliationForAccount(currentAccountKey, ignoreUnreconciled: false) {
			if !reconciliation.reconciled {
				SweetAlert().showAlert("Incomplete", subTitle: "The last reconciliation must be complete before adding more.", style: AlertStyle.Error)

				return
			}
		}

		performSegueWithIdentifier(Segue.AddReconciliation.rawValue, sender: self)
	}

// MARK: - Delegate Calls

	func reconciliationAdded(reconciliation: Reconciliation) {
		reconciliationKeys.insert(reconciliation.key, atIndex: 0)

		let path = NSIndexPath(forRow: 0, inSection: 0)
		tableView.insertRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.Top)
	}

	func reconciliationUpdated(reconciliation: Reconciliation) {
		var path = NSIndexPath(forRow: 0, inSection: 0)

		for index in 0 ..< reconciliationKeys.count {
			if reconciliationKeys[index] == reconciliation.key {
				path = NSIndexPath(forRow: index, inSection: 0)
				break
			}
		}

		tableView.reloadRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.None)
	}

	func accountCellTapped() {
		performSegueWithIdentifier(Segue.SetAccount.rawValue, sender: nil)
	}

	func accountSet(account: Account) {
		currentAccountKey = account.key
		CommonFunctions.currentAccountKey = currentAccountKey
		updateAccountInfo()
	}

	func ccAccountSet(account: Account) {
	}
}

class ReconciliationCell: UITableViewCell, Numbers {
	@IBOutlet weak var reconciliationDate: UILabel!
	@IBOutlet weak var reconciliationYear: UILabel!
	@IBOutlet weak var endingBalance: UILabel!

	var reconciliationKey: String {
		get {
			return ""
		}

		set(key) {
			let _reconciliation = Reconciliation(key: key)!

			reconciliationDate.text = dayFormatter.stringFromDate(_reconciliation.date)
			reconciliationYear.text = yearFormatter.stringFromDate(_reconciliation.date)
			endingBalance.text = formatForAmount(_reconciliation.endingBalance, useThousandsSeparator: true)
		}
	}
}