//
//  AddReconciliation.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/10/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import ALBNoSQLDB

protocol ReconciliationHeaderDelegate {
	func reconciliationHeaderChanged()
}

class EditReconciliationHeaderController: UITableViewController, UsesCurrency {
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
	fileprivate var _reconciliation = Reconciliation()
	fileprivate var _changingDate = false
	fileprivate let _keyboardToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 34))
	fileprivate var _currentField: UITextField?

	override func viewDidLoad() {
		datePickerCell.clipsToBounds = true
		if _reconciliation.reconciled {
			navigationItem.rightBarButtonItem = nil
		}

		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: _reconciliation.accountKey as AnyObject)
		let reconciliationCondition = DBCondition(set: 0, objectKey: "key", conditionOperator: .notEqual, value: _reconciliation.key as AnyObject)

		if _reconciliation.beginningBalance != 0, let keys = ALBNoSQLDB.keysInTableForConditions(Table.reconciliations, sortOrder: nil, conditions: [accountCondition, reconciliationCondition]) , keys.count > 0 {
			startingBalance.isEnabled = false
		}

		_keyboardToolbar.barStyle = UIBarStyle.blackTranslucent
		_keyboardToolbar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 34)

		let image = UIImage(imageIdentifier: .Negative)

		let negativeButton = UIBarButtonItem(image: image?.withRenderingMode(.alwaysTemplate), style: UIBarButtonItemStyle.plain, target: self, action: #selector(negativeTapped))
		negativeButton.tintColor = UIColor.white
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTyping))
		doneButton.tintColor = UIColor.white // (red: 0, green: 0.478431, blue: 1.0, alpha: 1.0)
		_keyboardToolbar.items = [negativeButton, flexSpace, doneButton]
	}

	override func viewWillAppear(_ animated: Bool) {
		startingBalance.keyboardType = .decimalPad
		endingBalance.keyboardType = .decimalPad
		datePicker.date = _reconciliation.date as Date
		dateChanged(self)
		if _reconciliation.beginningBalance != 0 {
			startingBalance.text = formatForAmount(_reconciliation.beginningBalance, useThousandsSeparator: false)
		}

		if _reconciliation.endingBalance != 0 {
			endingBalance.text = formatForAmount(_reconciliation.endingBalance, useThousandsSeparator: false)
		}

		startingBalance.inputAccessoryView = _keyboardToolbar
		endingBalance.inputAccessoryView = _keyboardToolbar
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if (indexPath as NSIndexPath).row == 1 {
			return (_changingDate ? 163 : 0)
		}

		return tableView.rowHeight;
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if (indexPath as NSIndexPath).row == 0 {
			_changingDate = !_changingDate
			balanceDateCell.detailTextLabel?.textColor = (_changingDate ? UIColor.red : UIColor.black)
			UIView.animate(withDuration: 0.5, animations: { () -> Void in
				tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .fade)
				tableView.reloadData()
			})
		}
	}

	func doneTyping() {
		view.endEditing(true)
		_currentField = nil
	}

	func  negativeTapped() {
		if let currentField = _currentField, let text = currentField.text {
			let amount = amountFromText(text) * -1
			currentField.text = formatForAmount(amount, useThousandsSeparator: false)
		}
	}

	@IBAction func doneTapped(_ sender: AnyObject) {
		let startBalance = startingBalance.amount()
		let endBalance = endingBalance.amount()

		_reconciliation.beginningBalance = startBalance
		_reconciliation.endingBalance = endBalance
		_reconciliation.date = datePicker.date

		delegate!.reconciliationHeaderChanged()
		let _ = navigationController?.popViewController(animated: true)
	}

	@IBAction func dateChanged(_ sender: AnyObject) {
		balanceDateCell.detailTextLabel?.text = datePicker.date.mediumDateString()
	}
}

extension EditReconciliationHeaderController: UITextFieldDelegate {
	func textFieldDidBeginEditing(_ textField: UITextField) {
		_currentField = textField
		_changingDate = false
		tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .fade)
	}
}
