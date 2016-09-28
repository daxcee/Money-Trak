//
//  EditEntryControllers.swift
//  My Money
//
//  Created by Aaron Bratcher on 09/11/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import TableViewHelper
import ALBNoSQLDB

protocol EditTransactionProtocol {
	func transactionAdded(_ transaction: Transaction)
	func transactionUpdated(_ transaction: Transaction)
}

//MARK: - Edit Entry Controller
class EditEntryController: UIViewController, UITableViewDataSource, UITableViewDelegate, AccountDelegate, LocationDelegate, CategoryDelegate, AlertDelegate, UITextFieldDelegate, AccountCellDelegate, MemoDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UsesCurrency {
	@IBOutlet private weak var tableView: UITableView!

	var showAccountSelector = true
	var upcomingTransaction = false
	var recurringTransaction = false
	var maxDate: Date?
	var delegate: EditTransactionProtocol?
	var transaction = Transaction()

	private var _helper: TableViewHelper!
	private var _accountView: AccountView?
	private var _numCCAccounts = CommonDB.numCCAccounts()
	private var _account = Account(key: CommonFunctions.currentAccountKey)!
	private var _lastSelection: IndexPath?

	private let _keyboardToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 34))

	private var _recurringHeader: String?
	private var _transactionCount: UITextField?
	private var _amountField: UITextField?
	private var _keyboardHeight: CGFloat = 0.0
	private var _fieldOffset: CGFloat = 0.0

	private var _frequencyItems = ["Weekly", "Every 2 Weeks", "Monthly", "Every 2 Months", "Every 3 Months", "Every 6 Months", "Annually"]

	enum Segue: String {
		case setAccount
		case setCCAccount
		case setLocation
		case setCategory
		case setAlert
		case setFrequency
		case setMemo
	}

	enum CellName: String {
		case transactionType
		case amount
		case account
		case ccAccount
		case date
		case datePicker
		case location
		case category
		case checkNumber
		case notes
		case alert

		case frequency
		case frequencyPicker
		case startDate
		case startDatePicker
		case useEndDate
		case endDate
		case endDatePicker
		case transactionCount
	}

	// MARK: - View
	override func viewDidLoad() {
		_helper = TableViewHelper(tableView: self.tableView)

		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.transactionType.rawValue)!, name: CellName.transactionType.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.amount.rawValue)!, name: CellName.amount.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.ccAccount.rawValue)!, name: CellName.ccAccount.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.date.rawValue)!, name: CellName.date.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.datePicker.rawValue)!, name: CellName.datePicker.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.location.rawValue)!, name: CellName.location.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.category.rawValue)!, name: CellName.category.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.checkNumber.rawValue)!, name: CellName.checkNumber.rawValue)
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: CellName.notes.rawValue)!, name: CellName.notes.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.alert.rawValue)!, name: CellName.alert.rawValue)

		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.frequency.rawValue)!, name: CellName.frequency.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.frequencyPicker.rawValue)!, name: CellName.frequencyPicker.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.startDate.rawValue)!, name: CellName.startDate.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.startDatePicker.rawValue)!, name: CellName.startDatePicker.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.useEndDate.rawValue)!, name: CellName.useEndDate.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.endDate.rawValue)!, name: CellName.endDate.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.endDatePicker.rawValue)!, name: CellName.endDatePicker.rawValue)
		_helper.addCell(2, cell: tableView.dequeueReusableCell(withIdentifier: CellName.transactionCount.rawValue)!, name: CellName.transactionCount.rawValue)

		_keyboardToolbar.barStyle = UIBarStyle.blackTranslucent
		_keyboardToolbar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 34)
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(doneTyping))
		doneButton.tintColor = UIColor.white // (red: 0, green: 0.478431, blue: 1.0, alpha: 1.0)
		_keyboardToolbar.items = [flexSpace, doneButton]

//		if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
//			navigationItem.leftBarButtonItem = nil
//		}

		if transaction.reconciled {
			navigationItem.rightBarButtonItem = nil
		}

		_account = Account(key: transaction.accountKey)!
		let minimumDate = Date().midnight().addDate(years: 0, months: 0, weeks: 0, days: 1)
		if transaction.isNew {
			if upcomingTransaction {
				transaction = UpcomingTransaction()
				transaction.date = minimumDate
			} else {
				if recurringTransaction {
					transaction = RecurringTransaction()
				} else {
					transaction = Transaction()
					if let maxDate = maxDate {
						transaction.date = maxDate
					}
				}
			}
		}

		let transactionType = _helper.cellForRowAtIndexPath(_helper.indexPathForCellNamed(CellName.transactionType.rawValue)!).viewWithTag(1)! as! UISegmentedControl

		switch transaction.type {
		case .purchase:
			transactionType.selectedSegmentIndex = 0
		case .deposit:
			transactionType.selectedSegmentIndex = 1
		case .ccPayment:
			transactionType.selectedSegmentIndex = 2
		}

		typeChanged()

		let datePickerCell = _helper.visibleCellsWithName(CellName.datePicker.rawValue)[0]
		let datePicker = datePickerCell.viewWithTag(1) as! UIDatePicker
		datePicker.date = transaction.date
		datePicker.addTarget(self, action: #selector(dateChanged), for: UIControlEvents.valueChanged)

		if upcomingTransaction {
			datePicker.minimumDate = minimumDate
		}

		if let accountView = Bundle.main.loadNibNamed("AccountView", owner: self, options: nil)?[0] as? AccountView {
			self._accountView = accountView
			if let keys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder: nil) {
				if keys.count == 1 || !showAccountSelector {
					accountView.allowTap(false)
					accountView.delegate = nil
				} else {
					accountView.allowTap(true)
					accountView.delegate = self
				}
			}
			accountView.account = _account
		}

		if !upcomingTransaction {
			_helper.hideCell(CellName.alert.rawValue)
		}

		if !recurringTransaction {
			_helper.hideCell(CellName.frequency.rawValue)
		}

		if recurringTransaction {
			_helper.hideCell(CellName.date.rawValue)
			let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: transaction.recurringTransactionKey as AnyObject)
			let keys = ALBNoSQLDB.keysInTableForConditions(kTransactionsTable, sortOrder: "date desc", conditions: [recurringCondition])
			if keys != nil && keys!.count > 0 {
				let lastTransaction = Transaction(key: keys![0])!
				var amount = 0
				for key in keys! {
					let temp = Transaction(key: key)!
					amount += temp.amount
				}
				amount = abs(amount)
				_recurringHeader = "Last Transaction — \(lastTransaction.date.mediumDateString())\n\(keys!.count) completed totalling \(formatForAmount(amount, useThousandsSeparator: true))"
			}

			if !transaction.isNew {
				let keys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: "date", conditions: [recurringCondition])
				if keys != nil && keys!.count > 0 {
					let firstTransaction = UpcomingTransaction(key: keys![0])!
					if let recurring = transaction as? RecurringTransaction {
						recurring.startDate = firstTransaction.date
					}
				}
			}

			if let recurring = transaction as? RecurringTransaction {
				if recurring.endDate == nil {
					_helper.hideCell(CellName.endDate.rawValue)
				} else {
					_helper.hideCell(CellName.transactionCount.rawValue)
				}
			}
		} else {
			_helper.hideCell(CellName.startDate.rawValue)
			_helper.hideCell(CellName.useEndDate.rawValue)
			_helper.hideCell(CellName.endDate.rawValue)
			_helper.hideCell(CellName.transactionCount.rawValue)
			_helper.hideCell(CellName.frequency.rawValue)
		}

		hidePickers()

		if _account.type == .creditCard {
			_helper.hideCell("CCAccount")
		}

		if transaction.isNew && !recurringTransaction && !upcomingTransaction {
			CurrentLocation.currentLocation({ (currentLocation) in
				guard let currentLocation = currentLocation
					, let addressParts = currentLocation.addressParts as? [CLPlacemark]
					else { return }
				
				if let address = addressParts[0].addressDictionary as? [String: AnyObject], let addressLines = address["FormattedAddressLines"] as? [String] {
					var compoundAddress = ""
					for addressLine in addressLines {
						compoundAddress += addressLine + ":"
					}

					self.transaction.addressKey = compoundAddress
					if self.transaction.locationKey == nil, let savedLocation = CommonDB.locationForAddress(compoundAddress) {
						self.locationSet(savedLocation)
					}
				}
			})
		}

		super.viewDidLoad()
	}

	override func viewDidAppear(_ animated: Bool) {
		if let lastSelection = _lastSelection {
			tableView.deselectRow(at: lastSelection, animated: true)
			self._lastSelection = nil
		}

		NotificationCenter.default.addObserver(self, selector: #selector(keyboardShown(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardHidden(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
	}

	override func viewDidDisappear(_ animated: Bool) {
		NotificationCenter.default.removeObserver(self)
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		view.endEditing(true)
		if segue.identifier != nil, let segueName = Segue(rawValue: segue.identifier!) {
			switch segueName {
			case .setAccount:
				let controller = segue.destination as! SelectAccountController
				controller.includeCreditCards = true
				controller.includeNonCreditCards = true
				controller.currentAccountKey = transaction.accountKey
				controller.accountDelegate = self

			case .setCCAccount:
				let controller = segue.destination as! SelectAccountController
				controller.includeCreditCards = true
				controller.includeNonCreditCards = false
				controller.currentAccountKey = transaction.ccAccountKey!
				controller.accountDelegate = self

			case .setLocation:
				let controller = segue.destination as! SelectLocationController
				controller.delegate = self
				if transaction.locationKey != nil {
					controller.selectedLocation = Location(key: transaction.locationKey!)
				}

			case .setCategory:
				let controller = segue.destination as! SelectCategoryController
				controller.delegate = self
				if transaction.categoryKey != nil {
					controller.selectedCategory = Category(key: transaction.categoryKey!)
				}

			case .setAlert:
				let controller = segue.destination as! AlertController
				let upcoming = transaction as? UpcomingTransaction
				controller.transaction = upcoming!
				controller.delegate = self

			case .setFrequency:
				let controller = segue.destination as! FrenquencyController
				let recurring = transaction as? RecurringTransaction
				controller.transaction = recurring!

			case .setMemo:
				let controller = segue.destination as! SetMemoController
				controller.transaction = transaction
				controller.delegate = self
			}
		}
	}

	// MARK: - Text Fields
	func keyboardShown(_ notification: Notification) {
		if let userInfo = notification.userInfo, let rectValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect {
			let keyboardHeight = rectValue.size.height
			self._keyboardHeight = keyboardHeight
			offsetTable()
		}
	}

	func keyboardHidden(_ notification: Notification) {
		self._keyboardHeight = 0
		offsetTable()
	}

	func offsetTable() {
		let height = UIScreen.main.bounds.size.height
		let minOffset = height - _keyboardHeight - 64
		var contentOffset = tableView.contentOffset
		if _keyboardHeight != 0 && _fieldOffset != 0 && _fieldOffset > minOffset {
			contentOffset.y = _fieldOffset - minOffset
		} else {
			contentOffset.y = -64
		}

		self.tableView.setContentOffset(contentOffset, animated: true)
	}

	func textFieldDidBeginEditing(_ textField: UITextField) {
		hidePickers()
		if let selectedPath = tableView.indexPathForSelectedRow {
			tableView.deselectRow(at: selectedPath, animated: true)
		}

		let pointInTable = textField.superview?.convert(textField.frame.origin, to: self.tableView) as CGPoint!
		_fieldOffset = (pointInTable?.y)!
		offsetTable()
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		textField.resignFirstResponder()
		let buttonPosition = textField.convert(CGPoint.zero, to: self.tableView)
		let indexPath = tableView.indexPathForRow(at: buttonPosition)
		tableView.scrollToRow(at: indexPath!, at: UITableViewScrollPosition.middle, animated: true)
		if textField == _transactionCount {
			if let recurring = transaction as? RecurringTransaction {
				recurring.transactionCount = NSString(string: textField.text!).integerValue
			}
		}
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		if textField == _transactionCount {
			if let recurring = transaction as? RecurringTransaction {
				recurring.transactionCount = NSString(string: textField.text!).integerValue
			}
		}

		return true
	}

	func doneTyping() {
		view.endEditing(true)
	}

	func hidePickers() {
		hidePickerNamed("DatePicker", parentName: "Date")
		hidePickerNamed("FrequencyPicker", parentName: "Frequency")
		hidePickerNamed("StartDatePicker", parentName: "StartDate")
		hidePickerNamed("EndDatePicker", parentName: "EndDate")
	}

	func hidePickerNamed(_ pickerName: String, parentName: String) {
		_helper.hideCell(pickerName)
		let cells = _helper.visibleCellsWithName(parentName)
		if cells.count > 0 {
			cells[0].detailTextLabel?.textColor = UIColor(white: 0.56, alpha: 1)
		}
	}

	func showPickerNamed(_ pickerName: String, parentName: String) {
		_helper.showCell(pickerName)
		let cells = _helper.visibleCellsWithName(parentName)
		if cells.count > 0 {
			cells[0].detailTextLabel?.textColor = UIColor.red
		}
	}

	// MARK: - TableView
	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if section == 0 && _accountView != nil {
			return 56
		}

		return 0
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 && _accountView != nil {
			return _accountView!
		}

		return nil
	}

	func numberOfSections(in tableView: UITableView) -> Int {
		return _helper.numberOfSections()
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return _helper.numberOfRowsInSection(section)
	}

	func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 1 && recurringTransaction {
			return _recurringHeader
		}

		return nil
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if let rawName =  _helper.cellNameAtIndexPath(indexPath)
			, let cellName = CellName(rawValue:rawName)
			, [.datePicker, .startDatePicker, .endDatePicker, .frequencyPicker].contains(cellName)
		{
		
			return 163
		}

		return 44
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = _helper.cellForRowAtIndexPath(indexPath)
		if let name = _helper.cellNameAtIndexPath(indexPath), let cellName = CellName(rawValue: name) {
			switch cellName {
			case .ccAccount:
				cell.detailTextLabel?.text = Account(key: transaction.ccAccountKey!)!.name

			case .transactionType:
				let transactionType = cell.viewWithTag(1)! as! UISegmentedControl
				transactionType.removeAllSegments()
				transactionType.insertSegment(withTitle: "Payment", at: 0, animated: false)
				transactionType.insertSegment(withTitle: "Deposit", at: 1, animated: false)
				transactionType.insertSegment(withTitle: "CC Payment", at: 2, animated: false)

				transactionType.addTarget(self, action: #selector(typeChanged), for: UIControlEvents.valueChanged)

				switch transaction.type {
				case .purchase:
					transactionType.selectedSegmentIndex = 0
				case .deposit:
					transactionType.selectedSegmentIndex = 1
				case .ccPayment:
					transactionType.selectedSegmentIndex = 2
				}

				if _numCCAccounts == 0 {
					transactionType.removeSegment(at: 2, animated: false)
				}

				if _account.type == .creditCard {
					if transaction.type == .deposit {
						transactionType.removeSegment(at: 1, animated: false)
						transactionType.removeSegment(at: 0, animated: false)
						transactionType.selectedSegmentIndex = -1
						transactionType.selectedSegmentIndex = 0
					} else {
						transactionType.setTitle("Purchase", forSegmentAt: 0)
						transactionType.setTitle("Payment", forSegmentAt: 1)
						transactionType.removeSegment(at: 2, animated: false)
					}
				}

			case .checkNumber:
				let checkNumber = cell.viewWithTag(1)! as! UITextField
				if transaction.checkNumber != nil && transaction.checkNumber! > 0 {
					checkNumber.text = "\(transaction.checkNumber!)"
				}
				checkNumber.keyboardType = .numberPad
				checkNumber.delegate = self
				checkNumber.inputAccessoryView = _keyboardToolbar

			case .date:
				cell.detailTextLabel?.text = mediumDateFormatter.string(from: transaction.date)

			case .datePicker:
				let datePicker = cell.viewWithTag(1) as! UIDatePicker
				if transaction.isNew {
					if upcomingTransaction {
						datePicker.minimumDate = Date().addDate(years: 0, months: 0, weeks: 0, days: 1)
						datePicker.date = datePicker.minimumDate!
					} else {
						datePicker.date = Date()
					}
				} else {
					datePicker.date = transaction.date
				}

			case .amount:
				let amount = cell.viewWithTag(1)! as! UITextField
				_amountField = amount
				if transaction.amount != 0 {
					amount.text = formatForAmount(abs(transaction.amount), useThousandsSeparator: false)
				}
				amount.keyboardType = .decimalPad
				amount.inputAccessoryView = _keyboardToolbar

			case .location:
				cell.detailTextLabel?.text = transaction.locationName()

			case .category:
				cell.detailTextLabel?.text = transaction.categoryName()

			case .notes:
				cell.detailTextLabel?.text = transaction.note

			case .alert:
				if upcomingTransaction {
					if let transaction = transaction as? UpcomingTransaction {
						cell.detailTextLabel?.text = transaction.alertString()
					}
				}

				// recurring transactions
			case .startDate:
				if let recurring = transaction as? RecurringTransaction {
					cell.detailTextLabel?.text = recurring.startDate.mediumDateString()
				}

			case .startDatePicker:
				if let recurring = transaction as? RecurringTransaction {
					let picker = cell.viewWithTag(1) as! UIDatePicker
					picker.date = recurring.startDate
					picker.minimumDate = Date().midnight()
					picker.addTarget(self, action: #selector(startDateChanged), for: .valueChanged)
				}

			case .endDate:
				if let recurring = transaction as? RecurringTransaction {
					cell.detailTextLabel?.text = recurring.endDate!.mediumDateString()
				}

			case .endDatePicker:
				if let recurring = transaction as? RecurringTransaction {
					let picker = cell.viewWithTag(1) as! UIDatePicker
					if recurring.endDate == nil {
						picker.date = Date().midnight()
					} else {
						picker.date = recurring.endDate!
					}
					picker.minimumDate = Date().midnight()
					picker.addTarget(self, action: #selector(endDateChanged), for: .valueChanged)
				}

			case .useEndDate:
				if let recurring = transaction as? RecurringTransaction {
					let useEndDate = cell.viewWithTag(1)! as! UISwitch
					useEndDate.addTarget(self, action: #selector(useEndDateChanged), for: UIControlEvents.valueChanged)
					useEndDate.isOn = recurring.endDate != nil
				}

			case .transactionCount:
				if let recurring = transaction as? RecurringTransaction {
					let transactionCount = cell.viewWithTag(1) as! UITextField
					transactionCount.delegate = self
					self._transactionCount = transactionCount
					transactionCount.inputAccessoryView = _keyboardToolbar
					transactionCount.text = "\(recurring.transactionCount)"
				}

			case .frequency:
				if let recurring = transaction as? RecurringTransaction {
					cell.detailTextLabel?.text = recurring.frequency.stringValue()
				}

			case .frequencyPicker:
				if let recurring = transaction as? RecurringTransaction {
					let picker = cell.viewWithTag(1) as! UIPickerView
					picker.dataSource = self
					picker.delegate = self
					picker.selectRow(recurring.frequency.rawValue, inComponent: 0, animated: true)
				}
				
			default:
				break
			}
		}

		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		view.endEditing(true)
		_lastSelection = indexPath
		let showingDate = _helper.visibleCellsWithName(CellName.datePicker.rawValue).count > 0
		let showingStartDate = _helper.visibleCellsWithName(CellName.startDatePicker.rawValue).count > 0
		let showingEndDate = _helper.visibleCellsWithName(CellName.endDatePicker.rawValue).count > 0
		let showingFrequency = _helper.visibleCellsWithName(CellName.frequencyPicker.rawValue).count > 0

		if let rawName = _helper.cellNameAtIndexPath(indexPath), let name = CellName(rawValue: rawName) {
			hidePickers()

			switch name {
			case .account:
				performSegue(withIdentifier: Segue.setAccount.rawValue, sender: nil)

			case .ccAccount:
				performSegue(withIdentifier: Segue.setCCAccount.rawValue, sender: nil)

			case .date:
				if !showingDate {
					showPickerNamed("DatePicker", parentName: "Date")
					if let maxDate = maxDate {
						let datePickerCell = _helper.visibleCellsWithName(CellName.datePicker.rawValue)[0]
						let datePicker = datePickerCell.viewWithTag(1) as! UIDatePicker
						datePicker.maximumDate = maxDate
					}
				}

			case .category:
				performSegue(withIdentifier: Segue.setCategory.rawValue, sender: nil)

			case .location:
				performSegue(withIdentifier: Segue.setLocation.rawValue, sender: nil)

			case .alert:
				performSegue(withIdentifier: Segue.setAlert.rawValue, sender: nil)

			case .notes:
				performSegue(withIdentifier: Segue.setMemo.rawValue, sender: nil)

			case .startDate:
				if !showingStartDate {
					showPickerNamed(CellName.startDatePicker.rawValue, parentName: CellName.startDate.rawValue)
				}
			case .endDate:
				if !showingEndDate {
					showPickerNamed(CellName.endDatePicker.rawValue, parentName: CellName.endDate.rawValue)
				}
			case.frequency:
				if !showingFrequency {
					showPickerNamed(CellName.frequencyPicker.rawValue, parentName: CellName.frequency.rawValue)
				}

			default:
				break;
			}
		}

		tableView.deselectRow(at: indexPath, animated: true)
	}

	// MARK: - User Actions
	func startDateChanged() {
		if let recurring = transaction as? RecurringTransaction {
			let cell = _helper.visibleCellsWithName(CellName.startDatePicker.rawValue)[0]
			let picker = cell.viewWithTag(1) as! UIDatePicker

			recurring.startDate = picker.date.midnight()
			self.tableView.reloadRows(at: [_helper.indexPathForCellNamed(CellName.startDate.rawValue)!], with: .none)
		}
	}

	func endDateChanged() {
		if let recurring = transaction as? RecurringTransaction {
			let cell = _helper.visibleCellsWithName(CellName.endDatePicker.rawValue)[0]
			let picker = cell.viewWithTag(1) as! UIDatePicker

			recurring.endDate = picker.date.midnight()
			self.tableView.reloadRows(at: [_helper.indexPathForCellNamed(CellName.endDate.rawValue)!], with: .none)
		}
	}

	func useEndDateChanged() {
		hidePickers()
		if let recurring = transaction as? RecurringTransaction {
			let cell = _helper.visibleCellsWithName(CellName.useEndDate.rawValue)[0]
			let useEndDate = cell.viewWithTag(1)! as! UISwitch
			if useEndDate.isOn {
				recurring.endDate = Date().addDate(years: 0, months: 12, weeks: 0, days: 0).midnight()
				_helper.showCell(CellName.endDate.rawValue)
				_helper.hideCell(CellName.transactionCount.rawValue)
			} else {
				recurring.endDate = nil
				_helper.hideCell(CellName.endDate.rawValue)
				_helper.showCell(CellName.transactionCount.rawValue)
			}
		}
	}

	@IBAction func accountCellTapped() {
		performSegue(withIdentifier: Segue.setAccount.rawValue, sender: nil)
	}

	@IBAction func cancelTapped(_ sender: AnyObject) {
		view.endEditing(true)
		dismiss(animated: true, completion: nil)
	}

	@IBAction func saveTapped(_ sender: AnyObject) {
		let amountCell = _helper.visibleCellsWithName(CellName.amount.rawValue)[0]
		let amountField = amountCell.viewWithTag(1)! as! AmountField
		var amountValue = amountField.amount()

		if amountValue == 0 {
			amountField.becomeFirstResponder()
			return
		}

		view.endEditing(true)

		let transactionTypeCell = _helper.visibleCellsWithName(CellName.transactionType.rawValue)[0]
		let transactionType = transactionTypeCell.viewWithTag(1)! as! UISegmentedControl

		if _helper.visibleCellsWithName(CellName.checkNumber.rawValue).count > 0 {
			let checkCell = _helper.visibleCellsWithName(CellName.checkNumber.rawValue)[0]
			let checkNumber = checkCell.viewWithTag(1)! as! UITextField
			if checkNumber.text != "" {
				transaction.checkNumber = Int(checkNumber.text!)
			} else {
				transaction.checkNumber = nil
			}
		} else {
			transaction.checkNumber = 0
		}

		if transactionType.selectedSegmentIndex != 1 {
			amountValue *= -1
		}

		transaction.amount = Int(amountValue)

		switch transactionType.selectedSegmentIndex {
		case 1:
			transaction.type = .deposit
		case 2:
			transaction.type = .ccPayment
		default:
			transaction.type = .purchase
		}

		transaction.save()

		if transaction.addressKey != nil && transaction.locationKey != nil {
			CommonDB.saveLocationForAddress(transaction.addressKey!, locationKey: transaction.locationKey!)
		}

		if let recurring = transaction as? RecurringTransaction {
			CommonDB.generateUpcomingFromRecurring(recurring)
		}

		dismiss(animated: true, completion: { () -> Void in
			if self.transaction.isNew {
				self.delegate?.transactionAdded(self.transaction)
			} else {
				self.delegate?.transactionUpdated(self.transaction)
			}
		})
	}

	// MARK: - Other

	func typeChanged() {
		view.endEditing(true)
		let transactionTypeCell = _helper.visibleCellsWithName(CellName.transactionType.rawValue)[0]
		let transactionType = transactionTypeCell.viewWithTag(1)! as! UISegmentedControl

		if _account.type == .checking {
			let showingCheckNumber = (transactionType.selectedSegmentIndex != 1)
			if showingCheckNumber && !upcomingTransaction && !recurringTransaction {
				_helper.showCell(CellName.checkNumber.rawValue)
			} else {
				_helper.hideCell(CellName.checkNumber.rawValue)
			}
		} else {
			_helper.hideCell(CellName.checkNumber.rawValue)
		}

		if _account.type != .creditCard {
			let showingCCAccount = (transactionType.selectedSegmentIndex == 2)
			if showingCCAccount {
				_helper.hideCell(CellName.location.rawValue)
				_helper.hideCell(CellName.category.rawValue)
				transaction.ccAccountKey = CommonDB.firstCCAccount().key
				if transaction.amount == 0 {
					let ccAccount = Account(key: transaction.ccAccountKey!)!
					transaction.amount = abs(ccAccount.balance)
					transaction.categoryKey = defaultPrefix + DefaultCategory.debt.rawValue
					if let path = self._helper.indexPathForCellNamed(CellName.amount.rawValue) {
						self.tableView.reloadRows(at: [path], with: .none)
					}
					if let path = self._helper.indexPathForCellNamed(CellName.category.rawValue) {
						self.tableView.reloadRows(at: [path], with: .none)
						self.tableView.reloadRows(at: [path], with: .none)
					}
				}

				_helper.showCell(CellName.ccAccount.rawValue)
			} else {
				_helper.showCell(CellName.category.rawValue)
				_helper.showCell(CellName.location.rawValue)
				_helper.hideCell(CellName.ccAccount.rawValue)
			}

			switch transactionType.selectedSegmentIndex {
			case 1:
				transaction.type = .deposit
			case 2:
				transaction.type = .ccPayment
			default:
				transaction.type = .purchase
			}
		}
	}

	func dateChanged() {
		let datePickerCell = _helper.visibleCellsWithName(CellName.datePicker.rawValue)[0]
		let datePicker = datePickerCell.viewWithTag(1) as! UIDatePicker

		transaction.date = datePicker.date
		if let path = _helper.indexPathForCellNamed(CellName.date.rawValue) {
			tableView.reloadRows(at: [path], with: .none)
		}
	}

	// MARK: - Delegate Calls

	func accountSet(_ account: Account) {
		self._account = account
		transaction.accountKey = account.key
		_accountView?.account = account

		if let path = _helper.indexPathForCellNamed(CellName.transactionType.rawValue) {
			tableView.reloadRows(at: [path], with: .none)
		}
	}

	func ccAccountSet(_ account: Account) {
		transaction.ccAccountKey = account.key
		let cell = _helper.visibleCellsWithName(CellName.ccAccount.rawValue)[0]
		cell.detailTextLabel?.text = account.name

		if transaction.amount == 0 {
			transaction.amount = abs(account.balance)
			if let path = _helper.indexPathForCellNamed(CellName.amount.rawValue) {
				tableView.reloadRows(at: [path], with: .none)
			}
		}
	}

	func locationSet(_ location: Location) {
		transaction.locationKey = location.key

		if let path = _helper.indexPathForCellNamed(CellName.location.rawValue) {
			tableView.reloadRows(at: [path], with: .none)
			tableView.reloadRows(at: [path], with: .none)
		}

		if location.categoryKey != nil {
			transaction.categoryKey = location.categoryKey
			categorySet(Category(key: location.categoryKey!)!)
			if let categoryPath = _helper.indexPathForCellNamed(CellName.category.rawValue) {
				tableView.reloadRows(at: [categoryPath], with: .none)
				tableView.reloadRows(at: [categoryPath], with: .none)
			}
		}
	}

	func categorySet(_ category: Category) {
		transaction.categoryKey = category.key

		if let path = _helper.indexPathForCellNamed(CellName.category.rawValue) {
			tableView.reloadRows(at: [path], with: .none)
			tableView.reloadRows(at: [path], with: .none)
		}
	}

	func alertSet() {
		if transaction is UpcomingTransaction {
			if let path = _helper.indexPathForCellNamed(CellName.alert.rawValue) {
				tableView.reloadRows(at: [path], with: .none)
			}
		}
	}

	func memoSet() {
		if let path = _helper.indexPathForCellNamed(CellName.notes.rawValue) {
			tableView.reloadRows(at: [path], with: .none)
			tableView.reloadRows(at: [path], with: .none)
		}
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
		if let recurring = transaction as? RecurringTransaction {
			recurring.frequency = TransactionFrequency(rawValue: row)!
			self.tableView.reloadRows(at: [_helper.indexPathForCellNamed(CellName.frequency.rawValue)!], with: .none)
		}
	}
}
