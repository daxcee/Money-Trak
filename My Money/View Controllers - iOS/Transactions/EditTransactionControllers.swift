//
//  EditEntryControllers.swift
//  My Money
//
//  Created by Aaron Bratcher on 09/11/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol EditTransactionProtocol {
	func transactionAdded(transaction: Transaction)
	func transactionUpdated(transaction: Transaction)
}


//MARK: - Edit Entry Controller
class EditEntryController: UIViewController, UITableViewDataSource, UITableViewDelegate, AccountDelegate, LocationDelegate, CategoryDelegate, AlertDelegate, UITextFieldDelegate, AccountCellDelegate, MemoDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
	@IBOutlet private weak var tableView: UITableView!
	
	var showAccountSelector = true
	var upcomingTransaction = false
	var recurringTransaction = false
	var maxDate: NSDate?
	var delegate: EditTransactionProtocol?
	var transaction = Transaction()
	
	private var _helper: TableViewHelper?
	private var _accountView: AccountView?
	private var _numCCAccounts = CommonDB.numCCAccounts()
	private var _account = Account(key: CommonFunctions.currentAccountKey)!
	private var _lastSelection: NSIndexPath?
	
	private let _keyboardToolbar = UIToolbar(frame: CGRectMake(0, 0, 100, 34))
	
	private var _recurringHeader: String?
	private var _transactionCount: UITextField?
	private var _amountField: UITextField?
	private var _keyboardHeight: CGFloat = 0.0
	private var _fieldOffset: CGFloat = 0.0
	
	private var _frequencyItems = ["Weekly", "Every 2 Weeks", "Monthly", "Every 2 Months", "Every 3 Months", "Every 6 Months", "Annually"]
	
	enum Segues: String {
		case SetAccount = "SetAccount"
		case SetCCAccount = "SetCCAccount"
		case SetLocation = "SetLocation"
		case SetCategory = "SetCategory"
		case SetAlert = "SetAlert"
		case SetFrequency = "SetFrequency"
		case SetMemo = "SetMemo"
	}
	
	enum CellNames: String {
		case TransactionType = "TransactionType"
		case Amount = "Amount"
		case CCAccount = "CCAccount"
		case Date = "Date"
		case DatePicker = "DatePicker"
		case Location = "Location"
		case Category = "Category"
		case CheckNumber = "CheckNumber"
		case Notes = "Notes"
		case Alert = "Alert"
		
		case Frequency = "Frequency"
		case FrequencyPicker = "FrequencyPicker"
		case StartDate = "StartDate"
		case StartDatePicker = "StartDatePicker"
		case UseEndDate = "UseEndDate"
		case EndDate = "EndDate"
		case EndDatePicker = "EndDatePicker"
		case TransactionCount = "TransactionCount"
	}
	
	// MARK: - View
	override func viewDidLoad() {
		_helper = TableViewHelper(tableView: self.tableView)
		
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.TransactionType.rawValue)!, name: CellNames.TransactionType.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.Amount.rawValue)!, name: CellNames.Amount.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.CCAccount.rawValue)!, name: CellNames.CCAccount.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.Date.rawValue)!, name: CellNames.Date.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.DatePicker.rawValue)!, name: CellNames.DatePicker.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.Location.rawValue)!, name: CellNames.Location.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.Category.rawValue)!, name: CellNames.Category.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.CheckNumber.rawValue)!, name: CellNames.CheckNumber.rawValue)
		_helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.Notes.rawValue)!, name: CellNames.Notes.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.Alert.rawValue)!, name: CellNames.Alert.rawValue)
		
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.Frequency.rawValue)!, name: CellNames.Frequency.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.FrequencyPicker.rawValue)!, name: CellNames.FrequencyPicker.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.StartDate.rawValue)!, name: CellNames.StartDate.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.StartDatePicker.rawValue)!, name: CellNames.StartDatePicker.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.UseEndDate.rawValue)!, name: CellNames.UseEndDate.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.EndDate.rawValue)!, name: CellNames.EndDate.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.EndDatePicker.rawValue)!, name: CellNames.EndDatePicker.rawValue)
		_helper!.addCell(2, cell: tableView.dequeueReusableCellWithIdentifier(CellNames.TransactionCount.rawValue)!, name: CellNames.TransactionCount.rawValue)
		
		_keyboardToolbar.barStyle = UIBarStyle.BlackTranslucent
		_keyboardToolbar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 34)
		let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
		let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "doneTyping")
		doneButton.tintColor = UIColor.whiteColor() // (red: 0, green: 0.478431, blue: 1.0, alpha: 1.0)
		_keyboardToolbar.items = [flexSpace, doneButton]
		
//		if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
//			navigationItem.leftBarButtonItem = nil
//		}
		
		if transaction.reconciled {
			navigationItem.rightBarButtonItem = nil
		}
		
		_account = Account(key: transaction.accountKey)!
		let minimumDate = NSDate().midnight().addDate(years: 0, months: 0, weeks: 0, days: 1)
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
		
		let transactionType = _helper!.cellForRowAtIndexPath(_helper!.indexPathForCellNamed(CellNames.TransactionType.rawValue)!).viewWithTag(1)! as! UISegmentedControl
		
		switch transaction.type {
		case .purchase:
			transactionType.selectedSegmentIndex = 0
		case .deposit:
			transactionType.selectedSegmentIndex = 1
		case .ccPayment:
			transactionType.selectedSegmentIndex = 2
		}
		
		typeChanged()
		
		let datePickerCell = _helper!.visibleCellsWithName("DatePicker") [0]
		let datePicker = datePickerCell.viewWithTag(1) as! UIDatePicker
		datePicker.date = transaction.date
		datePicker.addTarget(self, action: "dateChanged", forControlEvents: UIControlEvents.ValueChanged)
		
		if upcomingTransaction {
			datePicker.minimumDate = minimumDate
		}
		
		if let accountView = NSBundle.mainBundle().loadNibNamed("AccountView", owner: self, options: nil) [0] as? AccountView {
			self._accountView = accountView
			if let keys = ALBNoSQLDB.keysInTable("Accounts", sortOrder: nil) {
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
			_helper!.hideCell("Alert")
		}
		
		if !recurringTransaction {
			_helper!.hideCell("Frequency")
		}
		
		if recurringTransaction {
			_helper!.hideCell("Date")
			let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: transaction.recurringTransactionKey)
			let keys = ALBNoSQLDB.keysInTableForConditions(kTransactionsTable, sortOrder: "date desc", conditions: [recurringCondition])
			if keys != nil && keys!.count > 0 {
				let lastTransaction = Transaction(key: keys![0])!
				var amount = 0
				for key in keys! {
					let temp = Transaction(key: key)!
					amount += temp.amount
				}
				amount = abs(amount)
				_recurringHeader = "Last Transaction — \(lastTransaction.date.mediumDateString())\n\(keys!.count) completed totalling \(CommonFunctions.formatForAmount(amount, useThousandsSeparator: true))"
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
					_helper!.hideCell("EndDate")
				} else {
					_helper!.hideCell("TransactionCount")
				}
			}
		} else {
			_helper!.hideCell("StartDate")
			_helper!.hideCell("UseEndDate")
			_helper!.hideCell("EndDate")
			_helper!.hideCell("TransactionCount")
			_helper!.hideCell("Frequency")
		}
		
		hidePickers()
		
		if _account.type == .creditCard {
			_helper!.hideCell("CCAccount")
		}
		
		if transaction.isNew && !recurringTransaction && !upcomingTransaction {
			CurrentLocation.currentLocation({(currentLocation: CurrentLocation!) -> Void in
					if currentLocation == nil || currentLocation!.addressParts == nil {
						return
					}
					
					if let address = currentLocation!.addressParts[0].addressDictionary as? [String: AnyObject], addressLines = address["FormattedAddressLines"] as? [String] {
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
	
	override func viewDidAppear(animated: Bool) {
		if let lastSelection = _lastSelection {
			tableView.deselectRowAtIndexPath(lastSelection, animated: true)
			self._lastSelection = nil
		}
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardShown:", name: UIKeyboardDidShowNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardHidden:", name: UIKeyboardDidHideNotification, object: nil)
	}
	
	override func viewDidDisappear(animated: Bool) {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
		return UIInterfaceOrientation.Portrait
	}
	
	override func shouldAutorotate() -> Bool {
		return false
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		view.endEditing(true)
		if segue.identifier != nil, let segueName = Segues(rawValue: segue.identifier!) {
			switch segueName {
			case .SetAccount:
				let controller = segue.destinationViewController as! SelectAccountController
				controller.includeCreditCards = true
				controller.includeNonCreditCards = true
				controller.currentAccountKey = transaction.accountKey
				controller.accountDelegate = self
			
			case .SetCCAccount:
				let controller = segue.destinationViewController as! SelectAccountController
				controller.includeCreditCards = true
				controller.includeNonCreditCards = false
				controller.currentAccountKey = transaction.ccAccountKey!
				controller.accountDelegate = self
			
			case .SetLocation:
				let controller = segue.destinationViewController as! SelectLocationController
				controller.delegate = self
				if transaction.locationKey != nil {
					controller.selectedLocation = Location(key: transaction.locationKey!)
				}
			
			case .SetCategory:
				let controller = segue.destinationViewController as! SelectCategoryController
				controller.delegate = self
				if transaction.categoryKey != nil {
					controller.selectedCategory = Category(key: transaction.categoryKey!)
				}
			
			case .SetAlert:
				let controller = segue.destinationViewController as! AlertController
				let upcoming = transaction as? UpcomingTransaction
				controller.transaction = upcoming!
				controller.delegate = self
			
			case .SetFrequency:
				let controller = segue.destinationViewController as! FrenquencyController
				let recurring = transaction as? RecurringTransaction
				controller.transaction = recurring!
			
			case .SetMemo:
				let controller = segue.destinationViewController as! SetMemoController
				controller.transaction = transaction
				controller.delegate = self
			}
		}
	}
	
	// MARK: - Text Fields
	func keyboardShown(notification: NSNotification) {
		if let userInfo = notification.userInfo, keyboardHeight = userInfo[UIKeyboardFrameEndUserInfoKey]?.CGRectValue.size.height {
			self._keyboardHeight = keyboardHeight
			offsetTable()
		}
	}
	
	func keyboardHidden(notification: NSNotification) {
		self._keyboardHeight = 0
		offsetTable()
	}
	
	func offsetTable() {
		let height = UIScreen.mainScreen().bounds.size.height
		let minOffset = height - _keyboardHeight - 64
		var contentOffset = tableView.contentOffset
		if _keyboardHeight != 0 && _fieldOffset != 0 && _fieldOffset > minOffset {
			contentOffset.y = _fieldOffset - minOffset
		} else {
			contentOffset.y = -64
		}
		
		self.tableView.setContentOffset(contentOffset, animated: true)
	}
	
	func textFieldDidBeginEditing(textField: UITextField) {
		hidePickers()
		if let selectedPath = tableView.indexPathForSelectedRow {
			tableView.deselectRowAtIndexPath(selectedPath, animated: true)
		}
		
		let pointInTable = textField.superview?.convertPoint(textField.frame.origin, toView: self.tableView) as CGPoint!
		_fieldOffset = pointInTable.y
		offsetTable()
	}
	
	func textFieldDidEndEditing(textField: UITextField) {
		textField.resignFirstResponder()
		let buttonPosition = textField.convertPoint(CGPointZero, toView: self.tableView)
		let indexPath = tableView.indexPathForRowAtPoint(buttonPosition)
		tableView.scrollToRowAtIndexPath(indexPath!, atScrollPosition: UITableViewScrollPosition.Middle, animated: true)
		if textField == _transactionCount {
			if let recurring = transaction as? RecurringTransaction {
				recurring.transactionCount = NSString(string: textField.text!).integerValue
			}
		}
	}
	
	func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
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
	
	func hidePickerNamed(pickerName: String, parentName: String) {
		_helper!.hideCell(pickerName)
		let cells = _helper!.visibleCellsWithName(parentName)
		if cells.count > 0 {
			cells[0].detailTextLabel?.textColor = UIColor(white: 0.56, alpha: 1)
		}
	}
	
	func showPickerNamed(pickerName: String, parentName: String) {
		_helper!.showCell(pickerName)
		let cells = _helper!.visibleCellsWithName(parentName)
		if cells.count > 0 {
			cells[0].detailTextLabel?.textColor = UIColor.redColor()
		}
	}
	
	
	// MARK: - TableView
	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if section == 0 && _accountView != nil {
			return 56
		}
		
		return 0
	}
	
	func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 && _accountView != nil {
			return _accountView!
		}
		
		return nil
	}
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return _helper!.numberOfSections()
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return _helper!.numberOfRowsInSection(section)
	}
	
	
	func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 1 && recurringTransaction {
			return _recurringHeader
		}
		
		return nil
	}
	
	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		let cellName = _helper!.cellNameAtIndexPath(indexPath)
		
		if cellName == "DatePicker" || cellName == "StartDatePicker" || cellName == "EndDatePicker" || cellName == "FrequencyPicker" {
			return 163
		}
		
		return 44
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = _helper!.cellForRowAtIndexPath(indexPath)
		if let name = _helper!.cellNameAtIndexPath(indexPath), cellName = CellNames(rawValue: name) {
			switch cellName {
			case .CCAccount:
				cell.detailTextLabel?.text = Account(key: transaction.ccAccountKey!)!.name
			
			case .TransactionType:
				let transactionType = cell.viewWithTag(1)! as! UISegmentedControl
				transactionType.removeAllSegments()
				transactionType.insertSegmentWithTitle("Payment", atIndex: 0, animated: false)
				transactionType.insertSegmentWithTitle("Deposit", atIndex: 1, animated: false)
				transactionType.insertSegmentWithTitle("CC Payment", atIndex: 2, animated: false)
				
				transactionType.addTarget(self, action: "typeChanged", forControlEvents: UIControlEvents.ValueChanged)
				
				switch transaction.type {
				case .purchase:
					transactionType.selectedSegmentIndex = 0
				case .deposit:
					transactionType.selectedSegmentIndex = 1
				case .ccPayment:
					transactionType.selectedSegmentIndex = 2
				}
				
				if _numCCAccounts == 0 {
					transactionType.removeSegmentAtIndex(2, animated: false)
				}
				
				if _account.type == .creditCard {
					if transaction.type == .deposit {
						transactionType.removeSegmentAtIndex(1, animated: false)
						transactionType.removeSegmentAtIndex(0, animated: false)
						transactionType.selectedSegmentIndex = -1
						transactionType.selectedSegmentIndex = 0
					} else {
						transactionType.setTitle("Purchase", forSegmentAtIndex: 0)
						transactionType.setTitle("Payment", forSegmentAtIndex: 1)
						transactionType.removeSegmentAtIndex(2, animated: false)
					}
				}
			
			case .CheckNumber:
				let checkNumber = cell.viewWithTag(1)! as! UITextField
				if transaction.checkNumber != nil && transaction.checkNumber! > 0 {
					checkNumber.text = "\(transaction.checkNumber!)"
				}
				checkNumber.keyboardType = .NumberPad
				checkNumber.delegate = self
				checkNumber.inputAccessoryView = _keyboardToolbar
			
			case .Date:
				cell.detailTextLabel?.text = mediumDateFormatter.stringFromDate(transaction.date)
			
			case .DatePicker:
				let datePicker = cell.viewWithTag(1) as! UIDatePicker
				if transaction.isNew {
					if upcomingTransaction {
						datePicker.minimumDate = NSDate().addDate(years: 0, months: 0, weeks: 0, days: 1)
						datePicker.date = datePicker.minimumDate!
					} else {
						datePicker.date = NSDate()
					}
				} else {
					datePicker.date = transaction.date
				}
			
			case .Amount:
				let amount = cell.viewWithTag(1)! as! UITextField
				_amountField = amount
				if transaction.amount != 0 {
					amount.text = CommonFunctions.formatForAmount(abs(transaction.amount), useThousandsSeparator: false)
				}
				amount.keyboardType = .DecimalPad
				amount.inputAccessoryView = _keyboardToolbar
			
			case .Location:
				cell.detailTextLabel?.text = transaction.locationName()
			
			case .Category:
				cell.detailTextLabel?.text = transaction.categoryName()
			
			case .Notes:
				cell.detailTextLabel?.text = transaction.note
			
			case .Alert:
				if upcomingTransaction {
					if let transaction = transaction as? UpcomingTransaction {
						cell.detailTextLabel?.text = transaction.alertString()
					}
				}
				
				// recurring transactions
			case .StartDate:
				if let recurring = transaction as? RecurringTransaction {
					cell.detailTextLabel?.text = recurring.startDate.mediumDateString()
				}
			
			case .StartDatePicker:
				if let recurring = transaction as? RecurringTransaction {
					let picker = cell.viewWithTag(1) as! UIDatePicker
					picker.date = recurring.startDate
					picker.minimumDate = NSDate().midnight()
					picker.addTarget(self, action: "startDateChanged", forControlEvents: .ValueChanged)
				}
			
			case .EndDate:
				if let recurring = transaction as? RecurringTransaction {
					cell.detailTextLabel?.text = recurring.endDate!.mediumDateString()
				}
			
			case .EndDatePicker:
				if let recurring = transaction as? RecurringTransaction {
					let picker = cell.viewWithTag(1) as! UIDatePicker
					if recurring.endDate == nil {
						picker.date = NSDate().midnight()
					} else {
						picker.date = recurring.endDate!
					}
					picker.minimumDate = NSDate().midnight()
					picker.addTarget(self, action: "endDateChanged", forControlEvents: .ValueChanged)
				}
			
			case .UseEndDate:
				if let recurring = transaction as? RecurringTransaction {
					let useEndDate = cell.viewWithTag(1)! as! UISwitch
					useEndDate.addTarget(self, action: "useEndDateChanged", forControlEvents: UIControlEvents.ValueChanged)
					useEndDate.on = recurring.endDate != nil
				}
			
			case .TransactionCount:
				if let recurring = transaction as? RecurringTransaction {
					let transactionCount = cell.viewWithTag(1) as! UITextField
					transactionCount.delegate = self
					self._transactionCount = transactionCount
					transactionCount.inputAccessoryView = _keyboardToolbar
					transactionCount.text = "\(recurring.transactionCount)"
				}
			
			case .Frequency:
				if let recurring = transaction as? RecurringTransaction {
					cell.detailTextLabel?.text = recurring.frequency.stringValue()
				}
			
			case .FrequencyPicker:
				if let recurring = transaction as? RecurringTransaction {
					let picker = cell.viewWithTag(1) as! UIPickerView
					picker.dataSource = self
					picker.delegate = self
					picker.selectRow(recurring.frequency.rawValue, inComponent: 0, animated: true)
				}
			}
		}
		
		return cell
	}
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		view.endEditing(true)
		_lastSelection = indexPath
		let showingDate = _helper!.visibleCellsWithName("DatePicker").count > 0
		let showingStartDate = _helper!.visibleCellsWithName("StartDatePicker").count > 0
		let showingEndDate = _helper!.visibleCellsWithName("EndDatePicker").count > 0
		let showingFrequency = _helper!.visibleCellsWithName("FrequencyPicker").count > 0
		
		if let name = _helper!.cellNameAtIndexPath(indexPath) {
			hidePickers()
			
			switch name {
			case "Account":
				performSegueWithIdentifier(Segues.SetAccount.rawValue, sender: nil)
			
			case "CCAccount":
				performSegueWithIdentifier(Segues.SetCCAccount.rawValue, sender: nil)
			
			case "Date":
				if !showingDate {
					showPickerNamed("DatePicker", parentName: "Date")
					if let maxDate = maxDate {
						let datePickerCell = _helper!.visibleCellsWithName(CellNames.DatePicker.rawValue) [0]
						let datePicker = datePickerCell.viewWithTag(1) as! UIDatePicker
						datePicker.maximumDate = maxDate
					}
				}
			
			case "Category":
				performSegueWithIdentifier(Segues.SetCategory.rawValue, sender: nil)
			
			case "Location":
				performSegueWithIdentifier(Segues.SetLocation.rawValue, sender: nil)
			
			case "Alert":
				performSegueWithIdentifier(Segues.SetAlert.rawValue, sender: nil)
			
			case "Notes":
				performSegueWithIdentifier(Segues.SetMemo.rawValue, sender: nil)
			
			case "StartDate":
				if !showingStartDate {
					showPickerNamed("StartDatePicker", parentName: "StartDate")
				}
			case "EndDate":
				if !showingEndDate {
					showPickerNamed("EndDatePicker", parentName: "EndDate")
				}
			case "Frequency":
				if !showingFrequency {
					showPickerNamed("FrequencyPicker", parentName: "Frequency")
				}
			
			default:
				break;
			}
		}
		
		tableView.deselectRowAtIndexPath(indexPath, animated: true)
	}
	
	// MARK: - User Actions
	func startDateChanged() {
		if let recurring = transaction as? RecurringTransaction {
			let cell = _helper!.visibleCellsWithName(CellNames.StartDatePicker.rawValue) [0]
			let picker = cell.viewWithTag(1) as! UIDatePicker
			
			recurring.startDate = picker.date.midnight()
			self.tableView.reloadRowsAtIndexPaths([_helper!.indexPathForCellNamed(CellNames.StartDate.rawValue)!], withRowAnimation: .None)
		}
	}
	
	func endDateChanged() {
		if let recurring = transaction as? RecurringTransaction {
			let cell = _helper!.visibleCellsWithName("EndDatePicker") [0]
			let picker = cell.viewWithTag(1) as! UIDatePicker
			
			recurring.endDate = picker.date.midnight()
			self.tableView.reloadRowsAtIndexPaths([_helper!.indexPathForCellNamed(CellNames.EndDate.rawValue)!], withRowAnimation: .None)
		}
	}
	
	func useEndDateChanged() {
		hidePickers()
		if let recurring = transaction as? RecurringTransaction {
			let cell = _helper!.visibleCellsWithName("UseEndDate") [0]
			let useEndDate = cell.viewWithTag(1)! as! UISwitch
			if useEndDate.on {
				recurring.endDate = NSDate().addDate(years: 0, months: 12, weeks: 0, days: 0).midnight()
				_helper!.showCell("EndDate")
				_helper!.hideCell("TransactionCount")
			} else {
				recurring.endDate = nil
				_helper!.hideCell("EndDate")
				_helper!.showCell("TransactionCount")
			}
		}
	}
	
	
	@IBAction func accountCellTapped() {
		performSegueWithIdentifier(Segues.SetAccount.rawValue, sender: nil)
	}
	
	@IBAction func cancelTapped(sender: AnyObject) {
		view.endEditing(true)
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func saveTapped(sender: AnyObject) {
		let amountCell = _helper!.visibleCellsWithName("Amount") [0]
		let amountField = amountCell.viewWithTag(1)! as! AmountField
		var amountValue = amountField.amount()
		
		if amountValue == 0 {
			amountField.becomeFirstResponder()
			return
		}
		
		view.endEditing(true)
		
		let transactionTypeCell = _helper!.visibleCellsWithName("TransactionType") [0]
		let transactionType = transactionTypeCell.viewWithTag(1)! as! UISegmentedControl
		
		if _helper!.visibleCellsWithName("CheckNumber").count > 0 {
			let checkCell = _helper!.visibleCellsWithName("CheckNumber") [0]
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
		
		dismissViewControllerAnimated(true, completion: {() -> Void in
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
		let transactionTypeCell = _helper!.visibleCellsWithName("TransactionType") [0]
		let transactionType = transactionTypeCell.viewWithTag(1)! as! UISegmentedControl
		
		if _account.type == .checking {
			let showingCheckNumber = (transactionType.selectedSegmentIndex != 1)
			if showingCheckNumber && !upcomingTransaction && !recurringTransaction {
				_helper!.showCell(CellNames.CheckNumber.rawValue)
			} else {
				_helper!.hideCell(CellNames.CheckNumber.rawValue)
			}
		} else {
			_helper!.hideCell(CellNames.CheckNumber.rawValue)
		}
		
		if _account.type != .creditCard {
			let showingCCAccount = (transactionType.selectedSegmentIndex == 2)
			if showingCCAccount {
				_helper!.hideCell(CellNames.Location.rawValue)
				_helper!.hideCell(CellNames.Category.rawValue)
				transaction.ccAccountKey = CommonDB.firstCCAccount().key
				if transaction.amount == 0 {
					let ccAccount = Account(key: transaction.ccAccountKey!)!
					transaction.amount = abs(ccAccount.balance)
					transaction.categoryKey = defaultPrefix + DefaultCategory.Debt.rawValue
					if let path = self._helper!.indexPathForCellNamed(CellNames.Amount.rawValue) {
						self.tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
					}
					if let path = self._helper!.indexPathForCellNamed(CellNames.Category.rawValue) {
						self.tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
						self.tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
					}
				}
				
				_helper!.showCell(CellNames.CCAccount.rawValue)
			} else {
				_helper!.showCell(CellNames.Category.rawValue)
				_helper!.showCell(CellNames.Location.rawValue)
				_helper!.hideCell(CellNames.CCAccount.rawValue)
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
		let datePickerCell = _helper!.visibleCellsWithName(CellNames.DatePicker.rawValue) [0]
		let datePicker = datePickerCell.viewWithTag(1) as! UIDatePicker
		
		transaction.date = datePicker.date
		if let path = _helper!.indexPathForCellNamed(CellNames.Date.rawValue) {
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
		}
	}
	
	// MARK: - Delegate Calls
	
	func accountSet(account: Account) {
		self._account = account
		transaction.accountKey = account.key
		_accountView?.account = account
		
		if let path = _helper!.indexPathForCellNamed(CellNames.TransactionType.rawValue) {
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
		}
	}
	
	func ccAccountSet(account: Account) {
		transaction.ccAccountKey = account.key
		let cell = _helper!.visibleCellsWithName(CellNames.CCAccount.rawValue) [0]
		cell.detailTextLabel?.text = account.name
		
		if transaction.amount == 0 {
			transaction.amount = abs(account.balance)
			if let path = _helper!.indexPathForCellNamed(CellNames.Amount.rawValue) {
				tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
			}
		}
	}
	
	func locationSet(location: Location) {
		transaction.locationKey = location.key
		
		if let path = _helper!.indexPathForCellNamed("Location") {
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
		}
		
		if location.categoryKey != nil {
			transaction.categoryKey = location.categoryKey
			categorySet(Category(key: location.categoryKey!)!)
			if let categoryPath = _helper!.indexPathForCellNamed("Category") {
				tableView.reloadRowsAtIndexPaths([categoryPath], withRowAnimation: .None)
				tableView.reloadRowsAtIndexPaths([categoryPath], withRowAnimation: .None)
			}
		}
	}
	
	func categorySet(category: Category) {
		transaction.categoryKey = category.key
		
		if let path = _helper!.indexPathForCellNamed("Category") {
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
		}
	}
	
	func alertSet() {
		if transaction is UpcomingTransaction {
			if let path = _helper!.indexPathForCellNamed("Alert") {
				tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
			}
		}
	}
	
	func memoSet() {
		if let path = _helper!.indexPathForCellNamed("Notes") {
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
			tableView.reloadRowsAtIndexPaths([path], withRowAnimation: .None)
		}
	}
	
	// MARK: - Frequency items
	func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
		return 1
	}
	
	func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return 7
	}
	
	func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return _frequencyItems[row]
	}
	
	func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		if let recurring = transaction as? RecurringTransaction {
			recurring.frequency = TransactionFrequency(rawValue: row)!
			self.tableView.reloadRowsAtIndexPaths([_helper!.indexPathForCellNamed("Frequency")!], withRowAnimation: .None)
		}
	}
}