//
//  Frequency.swift
//  My Money
//
//  Created by Aaron Bratcher on 11/14/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class FrenquencyController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
	@IBOutlet weak var tableView: UITableView!

	var transaction = RecurringTransaction()

	private var _helper: TableViewHelper?
	private var _frequencyItems = ["Weekly", "Every 2 Weeks", "Monthly", "Every 2 Months", "Every 3 Months", "Every 6 Months", "Annually"]

	override func viewDidLoad() {
		_helper = TableViewHelper(tableView: self.tableView)

		_helper!.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "StartDate")!, name: "StartDate")
		_helper!.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "StartDatePicker")!, name: "StartDatePicker")
		_helper!.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "UseEndDate")!, name: "UseEndDate")
		_helper!.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "EndDate")!, name: "EndDate")
		_helper!.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "EndDatePicker")!, name: "EndDatePicker")
		_helper!.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "TransactionCount")!, name: "TransactionCount")
		_helper!.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "Frequency")!, name: "Frequency")
		_helper!.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "FrequencyPicker")!, name: "FrequencyPicker")

		_helper!.hideCell("StartDatePicker")
		_helper!.hideCell("EndDatePicker")
		_helper!.hideCell("FrequencyPicker")
		if transaction.endDate == nil {
			_helper!.hideCell("EndDate")
		} else {
			_helper!.hideCell("TransactionCount")
		}
	}

	// MARK: - TableView
	func numberOfSections(in tableView: UITableView) -> Int {
		return _helper!.numberOfSections()
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return _helper!.numberOfRowsInSection(section)
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return nil
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		let cellName = _helper!.cellNameAtIndexPath(indexPath)

		if cellName == "StartDatePicker" || cellName == "EndDatePicker" || cellName == "FrequencyPicker" {
			return 163
		}

		return 44
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = _helper!.cellForRowAtIndexPath(indexPath)
		if let name = _helper!.cellNameAtIndexPath(indexPath) {
			switch name {
			case "StartDate":
				cell.detailTextLabel?.text = transaction.startDate.mediumDateString()

			case "StartDatePicker":
				let picker = cell.viewWithTag(1) as! UIDatePicker
				picker.date = transaction.startDate
				picker.minimumDate = Date().midnight()
				picker.addTarget(self, action: #selector(startDateChanged), for: .valueChanged)

			case "EndDate":
				cell.detailTextLabel?.text = transaction.endDate!.mediumDateString()

			case "EndDatePicker":
				let picker = cell.viewWithTag(1) as! UIDatePicker
				if transaction.endDate == nil {
					picker.date = Date().midnight()
				} else {
					picker.date = transaction.endDate!
				}
				picker.minimumDate = Date().midnight()
				picker.addTarget(self, action: #selector(endDateChanged), for: .valueChanged)

			case "UseEndDate":
				let useEndDate = cell.viewWithTag(1)! as! UISwitch
				useEndDate.addTarget(self, action: #selector(useEndDateChanged), for: UIControlEvents.valueChanged)
				useEndDate.isOn = transaction.endDate != nil

			case "TransactionCount":
				let transactionCount = cell.viewWithTag(1) as! UITextField
				transactionCount.text = "\(transaction.transactionCount)"
				transactionCount.delegate = self

			case "Frequency":
				cell.detailTextLabel?.text = transaction.frequency.stringValue()

			case "FrequencyPicker":
				let picker = cell.viewWithTag(1) as! UIPickerView
				picker.dataSource = self
				picker.delegate = self
				picker.selectRow(transaction.frequency.rawValue, inComponent: 0, animated: true)

			default:
				break
			}
		}

		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let showingStartDate = _helper!.visibleCellsWithName("StartDatePicker").count > 0
		let showingEndDate = _helper!.visibleCellsWithName("EndDatePicker").count > 0
		let showingFrequency = _helper!.visibleCellsWithName("FrequencyPicker").count > 0

		if let name = _helper!.cellNameAtIndexPath(indexPath) {
			switch name {
			case "StartDate":
				if !showingStartDate {
					_helper!.showCell("StartDatePicker")
				}
			case "EndDate":
				if !showingEndDate {
					_helper!.showCell("EndDatePicker")
				}
			case "Frequency":
				if !showingFrequency {
					_helper!.showCell("FrequencyPicker")
				}
			default:
				break
			}
		}

		if showingStartDate {
			_helper!.hideCell("StartDatePicker")
			tableView.deselectRow(at: _helper!.indexPathForCellNamed("StartDate")!, animated: true)
		}

		if showingEndDate {
			_helper!.hideCell("EndDatePicker")
			tableView.deselectRow(at: _helper!.indexPathForCellNamed("EndDate")!, animated: true)
		}

		if showingFrequency {
			_helper!.hideCell("FrequencyPicker")
			tableView.deselectRow(at: _helper!.indexPathForCellNamed("Frequency")!, animated: true)
		}
	}

	// MARK: - User Actions
	func startDateChanged() {
		let cell = _helper!.visibleCellsWithName("StartDatePicker")[0]
		let picker = cell.viewWithTag(1) as! UIDatePicker

		transaction.startDate = picker.date.midnight()
		self.tableView.reloadRows(at: [_helper!.indexPathForCellNamed("StartDate")!], with: .none)
	}

	func endDateChanged() {
		let cell = _helper!.visibleCellsWithName("EndDatePicker")[0]
		let picker = cell.viewWithTag(1) as! UIDatePicker

		transaction.endDate = picker.date.midnight()
		self.tableView.reloadRows(at: [_helper!.indexPathForCellNamed("EndDate")!], with: .none)
	}

	func useEndDateChanged() {
		let cell = _helper!.visibleCellsWithName("UseEndDate")[0]
		let useEndDate = cell.viewWithTag(1)! as! UISwitch
		if useEndDate.isOn {
			transaction.endDate = Date().addDate(years: 0, months: 12, weeks: 0, days: 0).midnight()
			_helper!.showCell("EndDate")
			_helper!.hideCell("TransactionCount")
		} else {
			transaction.endDate = nil
			_helper!.hideCell("EndDate")
			_helper!.showCell("TransactionCount")
		}
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		transaction.transactionCount = NSString(string: textField.text!).integerValue
	}

	// MARK: - Frequency items

	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}

	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return 7
	}

	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return _frequencyItems[row]
	}

	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		transaction.frequency = TransactionFrequency(rawValue: row)!
		self.tableView.reloadRows(at: [_helper!.indexPathForCellNamed("Frequency")!], with: .none)
	}
}
