//
//  AddReconciliation.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/10/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol ReconciliationHeaderDelegate {
	func reconciliationHeaderChanged()
}

class EditReconciliationHeaderController: UITableViewController, UITextFieldDelegate {
	@IBOutlet weak var balanceDateCell: UITableViewCell!
	@IBOutlet weak var startingBalance: AmountField!
	@IBOutlet weak var endingBalance: AmountField!
	@IBOutlet weak var datePickerCell: UITableViewCell!
	@IBOutlet weak var datePicker: UIDatePicker!
	
	var reconciliation: Reconciliation {
		get {
			return _reconciliation
		}
		
		set(newReconciliation) {
			_reconciliation = newReconciliation
		}
	}
	
	var delegate: ReconciliationHeaderDelegate?
	private var _reconciliation = Reconciliation()
	private var _changingDate = false
	private let _keyboardToolbar = UIToolbar(frame: CGRectMake(0, 0, 100, 34))
	
	override func viewDidLoad() {
		datePickerCell.clipsToBounds = true
		if _reconciliation.reconciled {
			navigationItem.rightBarButtonItem = nil
		}
		
		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: _reconciliation.accountKey)
		let reconciliationCondition = DBCondition(set: 0, objectKey: "key", conditionOperator: .notEqual, value: _reconciliation.key)
		
		if _reconciliation.beginningBalance != 0, let keys = ALBNoSQLDB.keysInTableForConditions(kReconcilationsTable, sortOrder: nil, conditions: [accountCondition, reconciliationCondition]) where keys.count > 0 {
			startingBalance.enabled = false
		}
		
		_keyboardToolbar.barStyle = UIBarStyle.BlackTranslucent
		_keyboardToolbar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 34)
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
		let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "doneTyping")
		doneButton.tintColor = UIColor.whiteColor() // (red: 0, green: 0.478431, blue: 1.0, alpha: 1.0)
		_keyboardToolbar.items = [flexSpace, doneButton]
		
	}
	
	override func viewWillAppear(animated: Bool) {
		startingBalance.keyboardType = .DecimalPad
		endingBalance.keyboardType = .DecimalPad
		datePicker.date = _reconciliation.date
		dateChanged(self)
		if _reconciliation.beginningBalance != 0 {
			startingBalance.text = CommonFunctions.formatForAmount(_reconciliation.beginningBalance, useThousandsSeparator: false)
		}
		
		if _reconciliation.endingBalance != 0 {
			endingBalance.text = CommonFunctions.formatForAmount(_reconciliation.endingBalance, useThousandsSeparator: false)
		}
		
		startingBalance.inputAccessoryView = _keyboardToolbar
		endingBalance.inputAccessoryView = _keyboardToolbar
	}
	
	override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		if indexPath.row == 1 {
			return (_changingDate ? 163 : 0)
		}
		
		return tableView.rowHeight;
	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if indexPath.row == 0 {
			_changingDate = !_changingDate
			balanceDateCell.detailTextLabel?.textColor = (_changingDate ? UIColor.redColor() : UIColor.blackColor())
			UIView.animateWithDuration(0.5, animations: {() -> Void in
					tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 1, inSection: 0)], withRowAnimation: .Fade)
					tableView.reloadData()
				})
		}
	}
	
	func doneTyping() {
		view.endEditing(true)
	}
	
	@IBAction func doneTapped(sender: AnyObject) {
		_reconciliation.beginningBalance = startingBalance.amount()
		_reconciliation.endingBalance = endingBalance.amount()
		_reconciliation.date = datePicker.date
		
		delegate!.reconciliationHeaderChanged()
		navigationController?.popViewControllerAnimated(true)
	}
	
	
	@IBAction func dateChanged(sender: AnyObject) {
		balanceDateCell.detailTextLabel?.text = datePicker.date.mediumDateString()
	}
}

extension EditReconciliationHeaderController: UITextViewDelegate {
	func textFieldDidBeginEditing(textField: UITextField) {
		_changingDate = false
		tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 1, inSection: 0)], withRowAnimation: .Fade)
	}
}