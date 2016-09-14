//
//  LogEntry.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/20/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

enum TransactionType: String {
	case purchase = "purchase"
	case deposit = "deposit"
	case ccPayment = "payment"
}

// MARK: - Log Entry

class Transaction: ALBNoSQLDBObject {
	var accountKey = CommonFunctions.currentAccountKey
	var ccAccountKey: String?
	var recurringTransactionKey = ""
	var date = Date()
	var checkNumber: Int?
	var locationKey: String?
	var addressKey: String?
	var categoryKey: String?
	var note: String?
	var amount = 0
	var type = TransactionType.purchase
	var isNew = true
	var reconciled = false
	var defaults = DefaultManager()

	func save() {
		var ccAccount: Account?
		var sameAmount = false
		let account = Account(key: accountKey)!
		var sameAccount = false

		if type == .ccPayment {
			ccAccount = Account(key: ccAccountKey!)
			if let ccAccount = ccAccount {
				locationKey = CommonDB.locationForName(ccAccount.name).key
				// create new transaction against the CC account for the same amount
				let transaction = Transaction()
				transaction.accountKey = ccAccount.key
				transaction.amount = abs(amount)
				transaction.type = TransactionType.deposit
				transaction.locationKey = CommonDB.locationForName("Paid with \(Account(key: accountKey)!.name)").key
				transaction.date = date
				transaction.categoryKey = defaultPrefix + DefaultCategory.Debt.rawValue
				let _ = ALBNoSQLDB.setValue(table: kTransactionsTable, key: transaction.key, value: transaction.jsonValue())
				let ccAccount = Account(key: ccAccountKey!)!
				ccAccount.balance += abs(amount)
				ccAccount.save()
			}
		}

		if !isNew {
			let oldTransaction = Transaction(key: key)!
			sameAmount = (amount == oldTransaction.amount)
			sameAccount = (accountKey == oldTransaction.accountKey)

			if !sameAccount {
				delete()
				isNew = true
			} else if !sameAmount {
				if ccAccount == nil || !ccAccount!.updateTotalAll {
					deleteAmountFromAvailable(oldTransaction)
				}
				deleteAmountFromBalances(oldTransaction)
			}
		}

		if locationKey != nil && categoryKey != nil {
			let location = Location(key: locationKey!)!
			location.categoryKey = categoryKey!
			location.save()
		}

		if (!sameAmount || !sameAccount) && account.updateTotalAll {
			if ccAccount == nil || !ccAccount!.updateTotalAll {
				addAmountToAvailable()
			}

			addAmountToBalances()
		}

		// this must be done last to ensure proper reversals above
		if !ALBNoSQLDB.setValue(table: kTransactionsTable, key: key, value: jsonValue()) {
			// TODO: Handle Error
		}

		let monthKey = monthKeyFromDate(date)
		let _ = ALBNoSQLDB.deleteForKey(table: kMonthlySummaryEntriesTable, key: monthKey)
	}

	func delete() {
		deleteAmountFromAvailable(self)
		deleteAmountFromBalances(self)
		let _ = ALBNoSQLDB.deleteForKey(table: kTransactionsTable, key: key)
	}

	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kTransactionsTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}

	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			isNew = false

			accountKey = dictValue["accountKey"] as! String
			date = ALBNoSQLDB.dateValueForString(dictValue["date"] as! String)!
			amount = dictValue["amount"] as! Int
			type = TransactionType(rawValue: dictValue["type"] as! String)!
			recurringTransactionKey = dictValue["recurringTransactionKey"] as! String

			if dictValue["locationKey"] != nil {
				locationKey = dictValue["locationKey"] as? String
			}

			if dictValue["categoryKey"] != nil {
				categoryKey = dictValue["categoryKey"] as? String
			}

			if dictValue["note"] != nil {
				note = dictValue["note"] as? String
			}

			if dictValue["checkNumber"] != nil {
				checkNumber = dictValue["checkNumber"] as? Int
			}

			if dictValue["ccAccountKey"] != nil {
				ccAccountKey = dictValue["ccAccountKey"] as? String
			}

			if dictValue["addressKey"] != nil {
				addressKey = dictValue["addressKey"] as? String
			}

			if dictValue["reconciled"] != nil {
				reconciled = (dictValue["reconciled"] as? String) == "true" ? true : false
			}
		}

		super.init(keyValue: keyValue)
	}

	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()
		dictValue["accountKey"] = accountKey as AnyObject
		dictValue["date"] = date.midnight().stringValue() as AnyObject
		dictValue["amount"] = amount as AnyObject
		dictValue["type"] = type.rawValue as AnyObject
		dictValue["recurringTransactionKey"] = recurringTransactionKey as AnyObject
		dictValue["reconciled"] = (reconciled ? "true" : "false") as AnyObject

		if locationKey != nil {
			dictValue["locationKey"] = locationKey! as AnyObject
		}

		if categoryKey != nil {
			dictValue["categoryKey"] = categoryKey! as AnyObject
		}

		if note != nil {
			dictValue["note"] = note! as AnyObject
		}

		if checkNumber != nil {
			dictValue["checkNumber"] = checkNumber! as AnyObject
		}

		if ccAccountKey != nil {
			dictValue["ccAccountKey"] = ccAccountKey! as AnyObject
		}

		if addressKey != nil {
			dictValue["addressKey"] = addressKey! as AnyObject
		}

		return dictValue
	}

	func locationName() -> String {
		var lName = ""
		if let locationKey = locationKey {
			let location = Location(key: locationKey)
			lName = location!.name
		}

		return lName
	}

	func categoryName() -> String {
		var cName = ""
		if let categoryKey = categoryKey {
			let category = Category(key: categoryKey)
			cName = category!.name
		}

		return cName
	}

	func addAmountToAvailable() {
		let amountAvailable = defaults.integerForKey(.AmountAvailable) + amount
		defaults.setInteger(amountAvailable, forKey: .AmountAvailable)

		let _ = ALBNoSQLDB.setValue(table: kProcessedTransactionsTable, key: key, value: "{}", autoDeleteAfter: nil)
	}

	func addAmountToBalances() {
		let account = Account(key: accountKey)!
		account.balance += amount
		account.save()
		// TODO: budget balances
		// TODO: monthly summary balances
	}

	func deleteAmountFromAvailable(_ transaction: Transaction) {
		let amountAvailable = defaults.integerForKey(.AmountAvailable) - transaction.amount
		defaults.setInteger(amountAvailable, forKey: .AmountAvailable)

		let _ = ALBNoSQLDB.deleteForKey(table: kProcessedTransactionsTable, key: key)
	}

	func deleteAmountFromBalances(_ transaction: Transaction) {
		let account = Account(key: accountKey)!
		account.balance -= transaction.amount
		account.save()
		// TODO: budget balances
		// TODO: monthly summary balances
	}
}

// MARK: - Recurring Transaction

enum TransactionFrequency: Int {
	case weekly = 0
	case biWeekly = 1
	case monthly = 2
	case biMonthly = 3
	case quarterly = 4
	case semiAnnually = 5
	case annually = 6

	func stringValue() -> String {
		switch self {
		case .weekly:
			return "Weekly"
		case .biWeekly:
			return "Every 2 Weeks"
		case .monthly:
			return "Monthly"
		case .biMonthly:
			return "Every 2 Months"
		case .quarterly:
			return "Every 3 Months"
		case .semiAnnually:
			return "Every 6 Months"
		case .annually:
			return "Annually"
		}
	}
}

class RecurringTransaction: Transaction {
	var startDate = Date().addDate(years: 0, months: 0, weeks: 0, days: 1).midnight()
	var endDate: Date?
	var frequency = TransactionFrequency.monthly
	var transactionCount = 12
	var dbInstanceKey = ALBNoSQLDB.dbInstanceKey()! // only the device that last saved this will process this into upcoming transactions

	func convertToUpcomingTransaction() -> UpcomingTransaction {
		let transaction = UpcomingTransaction()

		transaction.accountKey = self.accountKey
		transaction.recurringTransactionKey = self.recurringTransactionKey
		transaction.date = self.date
		transaction.checkNumber = self.checkNumber
		transaction.locationKey = self.locationKey
		transaction.categoryKey = self.categoryKey
		transaction.note = self.note
		transaction.amount = self.amount
		transaction.type = self.type
		transaction.isNew = self.isNew
		transaction.dbInstanceKey = self.dbInstanceKey

		return transaction
	}

	required convenience init() {
		self.init(keyValue: ALBNoSQLDB.guid())

		dbInstanceKey = ALBNoSQLDB.dbInstanceKey()!
		recurringTransactionKey = key
	}

	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kRecurringTransactionsTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}

	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			startDate = ALBNoSQLDB.dateValueForString(dictValue["startDate"] as! String)!
			frequency = TransactionFrequency(rawValue: dictValue["frequency"] as! Int)!
			dbInstanceKey = dictValue["dbInstanceKey"] as! String
			transactionCount = dictValue["transactionCount"] as! Int

			if dictValue["endDate"] != nil {
				endDate = ALBNoSQLDB.dateValueForString(dictValue["endDate"] as! String)!
			}
		}

		super.init(keyValue: keyValue, dictValue: dictValue)
	}

	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = super.dictionaryValue()

		dictValue["startDate"] = ALBNoSQLDB.stringValueForDate(startDate) as AnyObject
		dictValue["frequency"] = frequency.rawValue as AnyObject
		dictValue["dbInstanceKey"] = dbInstanceKey as AnyObject
		dictValue["transactionCount"] = transactionCount as AnyObject

		if endDate != nil {
			dictValue["endDate"] = ALBNoSQLDB.stringValueForDate(endDate!) as AnyObject
		}

		return dictValue
	}

	override func save() {
		if isNew {
			date = startDate
		}
		dbInstanceKey = ALBNoSQLDB.dbInstanceKey()!

		if !ALBNoSQLDB.setValue(table: kRecurringTransactionsTable, key: key, value: jsonValue()) {
			// TODO: Handle Error
		}
	}

	override func delete() {
		let _ = ALBNoSQLDB.deleteForKey(table: kRecurringTransactionsTable, key: key)
	}
}

// MARK: - Upcoming Transaction

class UpcomingTransaction: Transaction {
	var alerts: [String]?
	var dbInstanceKey = ALBNoSQLDB.dbInstanceKey()! // only the device that last saved this will process this into upcoming transactions

	required convenience init() {
		self.init(keyValue: ALBNoSQLDB.guid())
		dbInstanceKey = ALBNoSQLDB.dbInstanceKey()!
	}

	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kUpcomingTransactionsTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}

	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			alerts = dictValue["alerts"] as? [String]
			dbInstanceKey = dictValue["dbInstanceKey"] as! String
		}

		super.init(keyValue: keyValue, dictValue: dictValue)
	}

	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = super.dictionaryValue()

		dictValue["dbInstanceKey"] = dbInstanceKey as AnyObject
		if let alerts = alerts {
			dictValue["alerts"] = alerts as AnyObject
		}

		return dictValue
	}

	func convertToTransaction() -> Transaction {
		let transaction = Transaction()
		transaction.key = self.key
		transaction.accountKey = self.accountKey
		transaction.recurringTransactionKey = self.recurringTransactionKey
		transaction.date = self.date
		transaction.checkNumber = self.checkNumber
		transaction.locationKey = self.locationKey
		transaction.categoryKey = self.categoryKey
		transaction.note = self.note
		transaction.amount = self.amount
		transaction.type = self.type
		transaction.isNew = self.isNew

		return transaction
	}

	override func save() {
		if !isNew {
			let oldTransaction = UpcomingTransaction(key: key)!
			let hasKey = ALBNoSQLDB.tableHasKey(table: kProcessedTransactionsTable, key: key)
			if hasKey != nil && hasKey! {
				deleteAmountFromAvailable(oldTransaction)
			}
		}
		dbInstanceKey = ALBNoSQLDB.dbInstanceKey()!

		processAmountAvailable()

		// this must be done last to ensure proper reversals
		if !ALBNoSQLDB.setValue(table: kUpcomingTransactionsTable, key: key, value: jsonValue()) {
			// TODO: Handle Error
		}
	}

	override func delete() {
		let hasKey = ALBNoSQLDB.tableHasKey(table: kProcessedTransactionsTable, key: key)
		if hasKey != nil && hasKey! {
			deleteAmountFromAvailable(self)
		}
		let _ = ALBNoSQLDB.deleteForKey(table: kUpcomingTransactionsTable, key: key)
	}

	func processAmountAvailable() {
		let account = Account(key: accountKey)!

		// if this isn't a CC account and it's a payment to a CCAccount that already updates total available
		// then we don't need to adjust amount available
		if account.type != .creditCard && type == .ccPayment {
			if let ccAccountKey = ccAccountKey {
				let ccAccount = Account(key: ccAccountKey)!
				if ccAccount.updateTotalAll {
					return
				}
			}
		}

		// For upcoming transactions, we don't add to what's available we only subtract
		if amount < 0 && date <= UpcomingTransaction.processDate(account) {
			addAmountToAvailable()
		}
	}

	struct AccountProcessDate {
		static var accountProcessDate: [String: Date] = [String: Date]()
	}

	class func processDate(_ account: Account) -> Date {
		var processDate = Date().midnight().addDate(years: 0, months: 0, weeks: 0, days: account.updateUpcomingDays)

		if account.stopUpdatingAtDeposit {
			let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key as AnyObject)
			let depositCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: .equal, value: "deposit" as AnyObject)
			let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: processDate.stringValue() as AnyObject)

			let depositKeys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: "date", conditions: [accountCondition, depositCondition, dateCondition])
			if depositKeys != nil && depositKeys!.count > 0 {
				let deposit = UpcomingTransaction(key: depositKeys![0])!
				if deposit.date < processDate {
					processDate = deposit.date
				}
			}
		}

		AccountProcessDate.accountProcessDate[account.key] = processDate
		return processDate
	}

	func alertString() -> String {
		var alert = ""

		if let alerts = self.alerts {
			if alerts.contains("1m") {
				alert = "1 month"
			} else {
				if alerts.contains("2w") {
					alert = "2 weeks"
				} else {
					if alerts.contains("1w") {
						alert = "1 week"
					} else {
						if alerts.contains("2d") {
							alert = "2 days"
						} else {
							if alerts.contains("1d") {
								alert = "1 day"
							}
						}
					}
				}
			}

			if alerts.count > 1 {
				alert += ", more…"
			}
		} else {
			alert = "None"
		}

		return alert
	}
}
