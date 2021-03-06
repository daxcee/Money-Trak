//
// CommonDB.swift
// My Money
//
// Created by Aaron Bratcher on 08/24/2014.
// Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import ALBNoSQLDB

// table names
enum Table {
	static let accounts = "Accounts"
	static let categories = "Categories"
	static let locations = "Locations"
	static let locationAddresses = "LocationAddresses"
	static let transactions = "Transactions"
	static let processedTransactions = "ProcessedTransactions"
	static let notifiedTransactions = "NotifiedTransactions"
	static let budgets = "Budgets"
	static let budgetEntries = "BudgetEntries"
	static let upcomingTransactions = "UpcomingTransactions"
	static let recurringTransactions = "RecurringTransactions"
	static let monthlySummaryEntries = "MonthlySummaryEntries"
	static let reconciliations = "Reconciliations"
	static let devices = "Devices"
}

// user notification constants
let kNegativeBalanceWarning = "NegativeBalanceWarning"
let kNegativeBalanceGone = "NegativeBalanceGone"

// program notification constants
let kUpdateTotalAvailableNotification = "UpdateTotalAvailable"
let kUpdateUpcomingTransactionsNotification = "UpdateUpcomingTransactions"

let kInitialBalance = "Initial Balance"
let defaultPrefix = "MMDefault:"

let dbProcessingQueue = DispatchQueue(label: "com.AaronLBratcher.processingQueue")

enum TransactionFilter {
	case all(String)
	case outstanding(String)
	case cleared(String)
}

enum DefaultCategory: String {
	case autoMaintenance = "Auto Maintenance"
	case autoTransportation = "Auto/Transportation"
	case clothing = "Clothing"
	case debt = "Debt"
	case education = "Education/Day Care"
	case eatingOut = "Eating Out"
	case entertainment = "Entertainment"
	case food = "Food"
	case gas = "Gas"
	case healthBeauty = "Health/Beauty"
	case homeFurnishings = "Home Furnishings"
	case homeMaintenance = "Home Maintenance"
	case insurance = "Insurance"
	case interest
	case medicalDental = "Medical/Dental"
	case miscellaneous = "Miscellaneous"
	case payroll = "Payroll"
	case rentMortgage = "Rent/Mortgage"
	case savingsInvestment = "Saving/Investment"
	case taxes = "Taxes"
	case tithingCharity = "Tithing/Charity"
	case utilities = "Utilities"
	case vacation = "Vacation"

	static func allCategories() -> [DefaultCategory] {
		return [.autoMaintenance
			, .autoTransportation
			, .clothing
			, .debt
			, .education
			, .eatingOut
			, .entertainment
			, .food
			, .gas
			, .healthBeauty
			, .homeFurnishings
			, .homeMaintenance
			, .insurance
			, .interest
			, .medicalDental
			, .miscellaneous
			, .payroll
			, .rentMortgage
			, .savingsInvestment
			, .taxes
			, .tithingCharity
			, .utilities
			, .vacation
		]
	}
}

class CommonDB: UsesCurrency {
	static let instance = CommonDB()
	var defaults = DefaultManager()

	class func setup() {
		if !ALBNoSQLDB.syncingEnabled()! {
			if !ALBNoSQLDB.enableSyncing() {
				// TODO: handle error
			}
		}

		if !ALBNoSQLDB.setUnsyncedTables([Table.devices, Table.processedTransactions, Table.notifiedTransactions, Table.monthlySummaryEntries]) {
			print("unable to set unsyncedTables")
		}

		for category in DefaultCategory.allCategories() {
			addCategory(category)
		}

		// setup default account
		if let accountKeys = ALBNoSQLDB.keysInTable(Table.accounts, sortOrder: nil) , accountKeys.count == 0 {
			let checking = Account()
			checking.key = defaultPrefix + "Checking"
			checking.save()

			let creditCard = Account()
			creditCard.key = defaultPrefix + "CreditCard"
			creditCard.type = .creditCard
			creditCard.name = "Credit Card"
			creditCard.save()
		} else {
			// handle error
		}

		ALBNoSQLDB.setTableIndexes(table: Table.transactions, indexes: ["accountKey", "date"])
		ALBNoSQLDB.setTableIndexes(table: Table.upcomingTransactions, indexes: ["date"])

		dbProcessingQueue.async(execute: { () -> Void in
			CommonDB.processUpcomingTransactions(false)
			CommonDB.checkForNegativeUpcoming(nil)
			CommonDB.removeUnusedLocations()
			CommonDB.fixDuplicateNames()
		})
	}

	class func addCategory(_ category: DefaultCategory) {
		let categoryKey = defaultPrefix + category.rawValue
		let condition = DBCondition(set: 0, objectKey: "key", conditionOperator: .equal, value: categoryKey as AnyObject)
		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.categories, sortOrder: nil, conditions: [condition]) , keys.count > 0 {
			// category already exists
			return
		}

		let newCategory = Category()
		newCategory.key = categoryKey
		newCategory.name = category.rawValue
		if category == .payroll {
			newCategory.inSummary = false
		}

		newCategory.save()
	}

	class func calcAmountAvailable() {
		dbProcessingQueue.async { () -> Void in
			var amountAvailable = 0

			let updateCondition = DBCondition(set: 0, objectKey: "updateTotalAll", conditionOperator: .equal, value: 1 as AnyObject)
			if let accountKeys = ALBNoSQLDB.keysInTableForConditions(Table.accounts, sortOrder: nil, conditions: [updateCondition]) {
				for accountKey in accountKeys {
					let account = Account(key: accountKey)!
					// process transactions to update account balance

					amountAvailable += account.balance

					// process upcoming transactions
					let processDate = UpcomingTransaction.processDate(account)
					let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key as AnyObject)
					let depositCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: .notEqual, value: "deposit" as AnyObject)
					let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: processDate.stringValue() as AnyObject)

					if let upcomingKeys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: "date,amount", conditions: [accountCondition, depositCondition, dateCondition]) {
						for transactionKey in upcomingKeys {
							guard let transaction = UpcomingTransaction(key: transactionKey) else { continue }

							// if this isn't a CC account and it's a payment to a CCAccount that already updates total available
							// then we don't need to adjust amount available
							if account.type != .creditCard && transaction.type == .ccPayment {
								if let ccAccountKey = transaction.ccAccountKey {
									let ccAccount = Account(key: ccAccountKey)!
									if ccAccount.updateTotalAll {
										continue
									}
								}
							}

							amountAvailable += transaction.amount
							let _ = ALBNoSQLDB.setValue(table: Table.processedTransactions, key: transaction.key, value: "{}", autoDeleteAfter: nil)
						}
					}
				}
			}

			CommonDB.instance.defaults.setInteger(amountAvailable, forKey: .amountAvailable)
			NotificationCenter.default.post(name: Notification.Name(rawValue: kUpdateTotalAvailableNotification), object: nil)
		}
	}

	// MARK: - Transactions
	class func processUpcomingTransactions(_ force: Bool) {
		let now = Date()

		if !force {
			// only do this twice a day
			if let processDate = CommonDB.instance.defaults.objectForKey(.upcomingTransactionScan) as? Date {
				let checkDate = processDate.addTime(hours: 12, minutes: 0, seconds: 0)
				if (checkDate as NSDate).earlierDate(now) == now {
					return
				}
			}
		}

		if let instanceKey = ALBNoSQLDB.dbInstanceKey() {
			let deviceCondition = DBCondition(set: 0, objectKey: "dbInstanceKey", conditionOperator: .equal, value: instanceKey as AnyObject)
			let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThan, value: ALBNoSQLDB.stringValueForDate(Date().addDate(years: 0, months: 2, weeks: 0, days: 0)) as AnyObject)
			let today = Date().midnight()
			var accountProcessDates = [String: Date]()

			if let keys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: "date", conditions: [deviceCondition, dateCondition]) {
				var finalRecurringKeys = [String]()
				for key in keys {
					guard let upcomingTransaction = UpcomingTransaction(key: key)
					, let account = Account(key: upcomingTransaction.accountKey) else { continue }

					// move from upcoming into standard transaction if necessary
					if (today as NSDate).laterDate(upcomingTransaction.date) == today {
						if upcomingTransaction.recurringTransactionKey != "" {
							let recurring = RecurringTransaction(key: upcomingTransaction.recurringTransactionKey)!
							recurring.transactionCount -= 1
							recurring.save()

							if recurring.transactionCount <= 0 {
								finalRecurringKeys.append(recurring.key)
							}
						}

						let newTransaction = upcomingTransaction.convertToTransaction()
						upcomingTransaction.delete();
						newTransaction.isNew = true
						newTransaction.save()
					} else {
						// possibly process total available instead
						var processDate: Date

						if accountProcessDates[account.key] == nil {
							let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key as AnyObject)
							let depositCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: .equal, value: "deposit" as AnyObject)
							let updateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: Date().midnight().addDate(years: 0, months: 0, weeks: 0, days: account.updateUpcomingDays).stringValue() as AnyObject)

							processDate = Date().midnight().addDate(years: 0, months: 0, weeks: 0, days: account.updateUpcomingDays)

							if account.stopUpdatingAtDeposit {
								let depositKeys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: "date", conditions: [accountCondition, depositCondition, updateCondition])
								if depositKeys != nil && depositKeys!.count > 0 {
									let deposit = UpcomingTransaction(key: depositKeys![0])!
									if deposit.date < processDate {
										processDate = deposit.date
									}
								}
							}

							accountProcessDates[account.key] = processDate
						} else {
							processDate = accountProcessDates[account.key]!
						}

						if upcomingTransaction.type != .deposit && upcomingTransaction.date >= processDate {
							// see if need to adjust total available
							let hasKey = ALBNoSQLDB.tableHasKey(table: Table.processedTransactions, key: key)
							if !hasKey! {
								upcomingTransaction.processAmountAvailable()
							}
						}

						// see if an alert notification needs to be made
						let userInfo = ["transaction": upcomingTransaction]
						NotificationCenter.default.post(name: Notification.Name(rawValue: "CreateLocalNotification"), object: nil, userInfo: userInfo)
					}
				}

				if finalRecurringKeys.count > 0 {
					let userInfo = ["keys": finalRecurringKeys]
					NotificationCenter.default.post(name: Notification.Name(rawValue: "LastRecurringProcessed"), object: nil, userInfo: userInfo)
				}
			} else {
				// error opening DB, couldn't get keys
				return
			}

			CommonDB.instance.defaults.setObject(now.midnight() as AnyObject?, forKey: .upcomingTransactionScan)

			NotificationCenter.default.post(name: Notification.Name(rawValue: kUpdateTotalAvailableNotification), object: nil)
		}

		calcAmountAvailable()
	}

	class func checkForNegativeUpcoming(_ accountKey: String?) {
		let now = Date()

		if accountKey == nil {
			let processDate: Date? = CommonDB.instance.defaults.objectForKey(.upcomingBalanceScan) as? Date
			if processDate != nil {
				let checkDate = processDate!.addTime(hours: 24, minutes: 0, seconds: 0)
				if (checkDate as NSDate).earlierDate(now) == now {
					return
				}
			}
		}

		CommonDB.instance.defaults.setObject(now as AnyObject?, forKey: .upcomingBalanceScan)

		let keys = upcomingTransactionKeys(.all(""))
		var accountKeys = [String]()
		if accountKey == nil {
			// get accounts
			for key in keys {
				let transaction = UpcomingTransaction(key: key)!
				if accountKeys.filter({ $0 == transaction.accountKey }).count == 0 {
					accountKeys.append(transaction.accountKey)
				}
			}
		} else {
			accountKeys.append(accountKey!)
		}

		// for each account, scan through keys to make sure balance doesn't dip below 0
		var showAlert = false
		for accountKey in accountKeys {
			let account = Account(key: accountKey)!
			var balance = account.balance

			for key in keys {
				guard let transaction = UpcomingTransaction(key: key) else { continue }

				if transaction.accountKey != accountKey {
					continue
				}

				balance += transaction.amount
				if balance < 0 {
					showAlert = true
				}
			}
		}

		let alertDate = CommonDB.instance.defaults.objectForKey(.upcomingTransactionsWarning) as? Date

		if showAlert {
			if alertDate != nil {
				let newShowDate = alertDate!.addTime(hours: 24, minutes: 0, seconds: 0)
				// alert was previously shown. Wait 24 hours before showing it again.
				if (Date() as NSDate).laterDate(newShowDate) == newShowDate {
					return
				}
			}

			CommonDB.instance.defaults.setObject(now as AnyObject?, forKey: .upcomingTransactionsWarning)

			DispatchQueue.main.async(execute: { () -> Void in
				NotificationCenter.default.post(name: Notification.Name(rawValue: kNegativeBalanceWarning), object: nil)
			})
		} else {
			CommonDB.instance.defaults.removeObjectForKey(.upcomingTransactionsWarning)

			if alertDate != nil {
				// alert was previously shown and now we're okay
				DispatchQueue.main.async(execute: { () -> Void in
					NotificationCenter.default.post(name: Notification.Name(rawValue: kNegativeBalanceGone), object: nil)
				})
			}
		}
	}

	class func generateUpcomingFromRecurring(_ recurringTransaction: RecurringTransaction) {
		// delete all pending upcoming transactions
		dbProcessingQueue.async(execute: { () -> Void in
			let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: recurringTransaction.recurringTransactionKey as AnyObject)
			let keys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: nil, conditions: [recurringCondition])
			if keys == nil {
				// TODO: handle error
				return
			}

			for key in keys! {
				let upcoming = UpcomingTransaction(key: key)!
				upcoming.delete()
			}

			// create new upcoming transactions
			var date = recurringTransaction.startDate
			var complete = false
			var remaining = recurringTransaction.transactionCount
			recurringTransaction.transactionCount = 0

			if recurringTransaction.endDate == nil && remaining == 0 {
				complete = true
			}

			while !complete {
				let upcoming = recurringTransaction.convertToUpcomingTransaction()
				upcoming.isNew = true
				upcoming.date = date
				upcoming.save()
				recurringTransaction.transactionCount += 1

				switch recurringTransaction.frequency {
				case .weekly:
					date = date.addDate(years: 0, months: 0, weeks: 1, days: 0)
				case .biWeekly:
					date = date.addDate(years: 0, months: 0, weeks: 2, days: 0)
				case .monthly:
					date = date.addDate(years: 0, months: 1, weeks: 0, days: 0)
				case .biMonthly:
					date = date.addDate(years: 0, months: 2, weeks: 0, days: 0)
				case .quarterly:
					date = date.addDate(years: 0, months: 3, weeks: 0, days: 0)
				case .semiAnnually:
					date = date.addDate(years: 0, months: 6, weeks: 0, days: 0)
				case .annually:
					date = date.addDate(years: 1, months: 0, weeks: 0, days: 0)
				}

				if recurringTransaction.endDate != nil {
					if recurringTransaction.endDate! < date {
						complete = true
					}
				} else {
					remaining -= 1
					if remaining == 0 {
						complete = true
					}
				}
			}

			recurringTransaction.save()
			self.processUpcomingTransactions(true)
			self.checkForNegativeUpcoming(recurringTransaction.accountKey)

			DispatchQueue.main.async(execute: { () -> Void in
				NotificationCenter.default.post(name: Notification.Name(rawValue: kUpdateUpcomingTransactionsNotification), object: nil)
				NotificationCenter.default.post(name: Notification.Name(rawValue: kUpdateTotalAvailableNotification), object: nil)
			})
		})
	}

	class func transactionKeys(_ filter: TransactionFilter) -> [String] {
		let account = CommonFunctions.currentAccountKey
		if account != "" {
			var accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account as AnyObject)
			var searchString = ""
			var reconciledCondition: DBCondition?

			switch filter {
			case .all(let searchText):
				searchString = searchText
			case .cleared(let searchText):
				searchString = searchText
				reconciledCondition = DBCondition(set: 0, objectKey: "reconciled", conditionOperator: .equal, value: "true" as AnyObject)
			case .outstanding(let searchText):
				searchString = searchText
				reconciledCondition = DBCondition(set: 0, objectKey: "reconciled", conditionOperator: .equal, value: "false" as AnyObject)
			}

			var finalConditionSet = [DBCondition]()

			if let searchConditions = conditionsForSearchString(searchString) {
				for condition in searchConditions {
					let set = condition.set
					finalConditionSet.append(condition)

					accountCondition.set = set
					finalConditionSet.append(accountCondition)

					if reconciledCondition != nil {
						reconciledCondition!.set = set
						finalConditionSet.append(reconciledCondition!)
					}
				}
			} else {
				finalConditionSet.append(accountCondition)
				if reconciledCondition != nil {
					finalConditionSet.append(reconciledCondition!)
				}
			}

			let keys = ALBNoSQLDB.keysInTableForConditions(Table.transactions, sortOrder: "date desc,amount desc", conditions: finalConditionSet)
			if keys == nil {
				// TODO: handle error
				return []
			}
			return keys!
		}

		return []
	}

	class func upcomingTransactionKeys(_ filter: TransactionFilter) -> [String] {
		let futureDate = Date().addDate(years: 0, months: 1, weeks: 0, days: 0)
		let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: futureDate.stringValue() as AnyObject)
		let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .notEqual, value: "" as AnyObject)
		let manualCondition = DBCondition(set: 1, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: "" as AnyObject)

		var searchString = ""
		switch filter {
		case .all(let searchText):
			searchString = searchText
		case .cleared(let searchText):
			searchString = searchText
		case .outstanding(let searchText):
			searchString = searchText
		}

		var finalConditionSet = [DBCondition]()

		if let searchConditions = conditionsForSearchString(searchString) {
			finalConditionSet += searchConditions
		} else {
			finalConditionSet += [dateCondition, recurringCondition, manualCondition]
		}

		let keys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: "date,amount", conditions: finalConditionSet)
		if keys == nil {
			// TODO: handle error
			return []
		}
		return keys!
	}

	class func recurringTransactionCount() -> Int {
		let db = ALBNoSQLDB.sharedInstance
		let sql = "select key from \(Table.recurringTransactions)"
		if let results = db.sqlSelect(sql) {
			return results.count
		}

		return 0
	}

	class func recurringTransactionKeys(_ filter: TransactionFilter) -> [String] {
		var searchString = ""
		switch filter {
		case .all(let searchText):
			searchString = searchText
		case .cleared(let searchText):
			searchString = searchText
		case .outstanding(let searchText):
			searchString = searchText
		}

		var finalConditionSet = [DBCondition]()

		if let searchConditions = conditionsForSearchString(searchString) {
			finalConditionSet += searchConditions
		}

		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.recurringTransactions, sortOrder: nil, conditions: finalConditionSet) {
			return keys
		}

		return []
	}

	class func conditionsForSearchString(_ text: String) -> [DBCondition]? {
		if text == "" || text.characters.count < 2 {
			return nil
		}

		var conditionSet = [DBCondition]()
		var condition: DBCondition

		let amount = CommonDB.instance.amountFromText(text)
		if amount == 0 {
			var set = 0
			let categoryCondition = DBCondition(set: 0, objectKey: "name", conditionOperator: .contains, value: text as AnyObject)
			if let keys = ALBNoSQLDB.keysInTableForConditions(Table.categories, sortOrder: nil, conditions: [categoryCondition]) , keys.count > 0 {
				for key in keys {
					condition = DBCondition(set: set, objectKey: "categoryKey", conditionOperator: .equal, value: key as AnyObject)
					conditionSet.append(condition)
					set += 1
				}
			}

			let locationCondition = DBCondition(set: 0, objectKey: "name", conditionOperator: .contains, value: text as AnyObject)
			if let keys = ALBNoSQLDB.keysInTableForConditions(Table.locations, sortOrder: nil, conditions: [locationCondition]) , keys.count > 0 {
				for key in keys {
					condition = DBCondition(set: set, objectKey: "locationKey", conditionOperator: .equal, value: key as AnyObject)
					conditionSet.append(condition)
					set += 1
				}
			}

			condition = DBCondition(set: set, objectKey: "note", conditionOperator: .contains, value: text as AnyObject)
			conditionSet.append(condition)

			return conditionSet
		} else {
			condition = DBCondition(set: 0, objectKey: "amount", conditionOperator: .equal, value: abs(amount) as AnyObject)
			conditionSet.append(condition)
			condition = DBCondition(set: 1, objectKey: "amount", conditionOperator: .equal, value: -abs(amount) as AnyObject)
			conditionSet.append(condition)

			var checkNumber = Double(amount) / 100.0
			checkNumber = floor(checkNumber)
			if checkNumber > 0 {
				condition = DBCondition(set: 2, objectKey: "checkNumber", conditionOperator: .equal, value: checkNumber as AnyObject)
				conditionSet.append(condition)
			}
		}

		return conditionSet
	}

	class func recalculateAllBalances() {
		var amountAvailable = 0
		let _ = ALBNoSQLDB.dropTable(Table.processedTransactions)

		// clear spending summary cache
		if let summaryKeys = ALBNoSQLDB.keysInTable(Table.monthlySummaryEntries, sortOrder: nil) {
			for key in summaryKeys {
				let _ = ALBNoSQLDB.deleteForKey(table: Table.monthlySummaryEntries, key: key)
			}
		}

		// reset processDate cache
		CommonDB.instance.defaults.setObject(Date().addDate(years: 0, months: 0, weeks: 0, days: -2) as AnyObject?, forKey: .lastCheckDate)

		if let accountKeys = ALBNoSQLDB.keysInTable(Table.accounts, sortOrder: nil) {
			for accountKey in accountKeys {
				let account = Account(key: accountKey)!
				// process transactions to update account balance
				let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key as AnyObject)
				if let transactionKeys = ALBNoSQLDB.keysInTableForConditions(Table.transactions, sortOrder: nil, conditions: [accountCondition]) {
					account.balance = 0
					for transactionKey in transactionKeys {
						let transaction = Transaction(key: transactionKey)!
						account.balance += transaction.amount
					}

					account.save()
				}

				if account.updateTotalAll {
					amountAvailable += account.balance

					// process upcoming transactions
					let processDate = UpcomingTransaction.processDate(account)
					let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key as AnyObject)
					let depositCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: .notEqual, value: "deposit" as AnyObject)
					let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: processDate.stringValue() as AnyObject)

					if let upcomingKeys = ALBNoSQLDB.keysInTableForConditions(Table.upcomingTransactions, sortOrder: "date,amount", conditions: [accountCondition, depositCondition, dateCondition]) {
						for transactionKey in upcomingKeys {
							let transaction = UpcomingTransaction(key: transactionKey)!

							// if this isn't a CC account and it's a payment to a CCAccount that already updates total available
							// then we don't need to adjust amount available
							if account.type != .creditCard && transaction.type == .ccPayment {
								if let ccAccountKey = transaction.ccAccountKey {
									let ccAccount = Account(key: ccAccountKey)!
									if ccAccount.updateTotalAll {
										continue
									}
								}
							}

							amountAvailable += transaction.amount
							let _ = ALBNoSQLDB.setValue(table: Table.processedTransactions, key: transaction.key, value: "{}", autoDeleteAfter: nil)
						}
					}
				}
			}
		}

		CommonDB.instance.defaults.setInteger(amountAvailable, forKey: .amountAvailable)

		NotificationCenter.default.post(name: Notification.Name(rawValue: kUpdateTotalAvailableNotification), object: nil)
	}

	class func sumTransactions(_ transactionKeys: [String], table: String) -> Int {
		var sql = "select sum(amount) from \(table) where key in ("

		for key in transactionKeys {
			sql += "'\(key)',"
		}

		sql = String(sql.characters.dropLast())
		sql += ")"

		let db = ALBNoSQLDB.sharedInstance
		var amount = 0
		if let results = db.sqlSelect(sql) {
			if results.count > 0, let sum = results[0].values[0] as? Int {
				amount = sum
			}
		}

		return amount
	}

	// MARK: - Reconciliations
	class func reconciliationCount() -> Int {
		let db = ALBNoSQLDB.sharedInstance
		let sql = "select key from \(Table.reconciliations)"
		if let results = db.sqlSelect(sql) {
			return results.count
		}

		return 0
	}

	class func accountReconciliations(_ accountKey: String) -> [String] {
		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: accountKey as AnyObject)

		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.reconciliations, sortOrder: "date desc", conditions: [accountCondition]) {
			return keys
		}

		return [String]()
	}

	typealias reconciliationTransactionsFound = (_ transactionKeys: [String]) -> ()
	class func loadTransactionsForReconciliation(_ reconciliation: Reconciliation, searchString: String? = nil, onComplete: @escaping reconciliationTransactionsFound) {
		// if this isn't new, then just use the transactions saved with the reconciliation
		if reconciliation.reconciled {
			let db = ALBNoSQLDB.sharedInstance
			let keys = reconciliation.transactionKeys.map({ "'" + $0 + "'" }).joined(separator: ",")
			let sql = "select key from transactions where key in (\(keys)) order by date desc, amount desc"
			if let results = db.sqlSelect(sql) {
				onComplete(results.map({ $0.values[0] as! String }))
				return
			}

			onComplete(reconciliation.transactionKeys)
			return
		}

		dbProcessingQueue.async(execute: { () -> Void in
			// get unreconciled transactions for this account with a date less than this reconciliation date
			var endDateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: reconciliation.date.midnight().stringValue() as AnyObject)
			var accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: reconciliation.accountKey as AnyObject)
			var reconciledCondition = DBCondition(set: 0, objectKey: "reconciled", conditionOperator: .equal, value: "false" as AnyObject)

			// take searchText into consideration
			var finalConditionSet = [DBCondition]()

			if searchString != nil, let searchConditions = self.conditionsForSearchString(searchString!) {
				for condition in searchConditions {
					let set = condition.set
					finalConditionSet.append(condition)

					endDateCondition.set = set
					finalConditionSet.append(endDateCondition)

					accountCondition.set = set
					finalConditionSet.append(accountCondition)

					reconciledCondition.set = set
					finalConditionSet.append(reconciledCondition)
				}
			} else {
				finalConditionSet.append(endDateCondition)
				finalConditionSet.append(accountCondition)
				finalConditionSet.append(reconciledCondition)
			}

			let transactionKeys = ALBNoSQLDB.keysInTableForConditions(Table.transactions, sortOrder: "date desc,amount desc", conditions: finalConditionSet)!

			onComplete(transactionKeys)
		})
	}

	class func lastReconciliationForAccount(_ accountKey: String, ignoreUnreconciled: Bool = false) -> Reconciliation? {
		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: accountKey as AnyObject)
		var lastReconciliation: Reconciliation?

		if let reconciliationKeys = ALBNoSQLDB.keysInTableForConditions(Table.reconciliations, sortOrder: "date desc", conditions: [accountCondition]), reconciliationKeys.count > 0 {
			for index in 0 ..< reconciliationKeys.count {
				if let reconciliation = Reconciliation(key: reconciliationKeys[index]) {
					if (!ignoreUnreconciled || reconciliation.reconciled) {
						lastReconciliation = reconciliation
						break
					}
				}
			}
		}

		return lastReconciliation
	}

	class func createInitialBalanceTransaction(_ reconciliation: Reconciliation) -> String {
		let account = Account(key: reconciliation.accountKey)!
		let transaction = Transaction()
		transaction.accountKey = reconciliation.accountKey

		if account.type == .creditCard {
			transaction.amount = abs(reconciliation.beginningBalance) * -1
			transaction.type = .purchase
		} else {
			transaction.amount = abs(reconciliation.beginningBalance)
			transaction.type = .deposit
		}

		let sql = "select date from \(Table.transactions) where accountKey = '\(reconciliation.accountKey)' order by date limit 1"
		let db = ALBNoSQLDB.sharedInstance
		var minDate = reconciliation.date
		if let results = db.sqlSelect(sql), results.count > 0 {
			let dateString = results[0].values[0] as! String
			minDate = ALBNoSQLDB.dateValueForString(dateString)!
		}

		minDate = min(minDate, reconciliation.date as Date)

		// set minDate to a month prior
		minDate = minDate.addDate(years: 0, months: -1, weeks: 0, days: 0)

		let calendar = Calendar.current
		let year = calendar.component(.year, from: minDate)
		let month = calendar.component(.month, from: minDate)
		
		var dateComponents = DateComponents()
		dateComponents.year = year
		dateComponents.month = month
		dateComponents.day = 1
		dateComponents.hour = 0
		dateComponents.minute = 0
		dateComponents.second = 0

		minDate = calendar.date(from: dateComponents)!

		let location = locationForName(kInitialBalance)
		transaction.date = minDate
		transaction.locationKey = location.key
		transaction.reconciled = true
		transaction.save()

		return transaction.key
	}

	class func updateInitialBalanceTransaction(_ transactionKey: String, reconciliation: Reconciliation) {
		let transaction = Transaction(key: transactionKey)!
		let account = Account(key: reconciliation.accountKey)!

		if account.type == .creditCard {
			transaction.amount = abs(reconciliation.beginningBalance) * -1
		} else {
			transaction.amount = abs(reconciliation.beginningBalance)
		}

		transaction.save()
	}

	// MARK: - Locations
	class func locationForName(_ name: String) -> Location {
		let location = Location()
		location.name = name

		let condition = DBCondition(set: 0, objectKey: "name", conditionOperator: .equal, value: name as AnyObject)
		let conditionArray = [condition]
		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.locations, sortOrder: nil, conditions: conditionArray) , keys.count > 0 {
			return Location(key: keys[0])!
		}

		location.save()
		return location
	}

	class func locationKeysForString(_ string: String) -> [String] {
		if string == "" {
			return []
		}

		let condition = DBCondition(set: 0, objectKey: "name", conditionOperator: .contains, value: string as AnyObject)
		let conditionArray = [condition]
		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.locations, sortOrder: "name", conditions: conditionArray) {
			return keys
		}

		return []
	}

	class func saveLocationForAddress(_ addressKey: String, locationKey: String) {
		// see if we have this address registered
		var locationAddress = LocationAddress()

		let hasKey = ALBNoSQLDB.tableHasKey(table: Table.locationAddresses, key: addressKey)
		if hasKey != nil && hasKey! {
			locationAddress = LocationAddress(key: addressKey)!
		} else {
			locationAddress.key = addressKey
		}

		locationAddress.locationKey = locationKey
		locationAddress.save()
	}

	class func locationForAddress(_ addressKey: String) -> Location? {
		guard let locationAddress = LocationAddress(key: addressKey), let location = Location(key: locationAddress.locationKey) else { return nil }
		return location
	}

	class func removeUnusedLocations() {
		let latestDate = Date().addDate(years: 0, months: -1, weeks: 0, days: 0)
		let sql = "select l.key from \(Table.locations) l left outer join \(Table.transactions) t on t.locationKey = l.key left outer join \(Table.upcomingTransactions) u on u.locationKey = l.key where t.locationKey is null and u.locationKey is null and l.addedDateTime < '\(latestDate.stringValue())'"

		let db = ALBNoSQLDB.sharedInstance
		guard let results = db.sqlSelect(sql) else { return }

		for row in results {
			guard let key = row.values[0] as? String else { continue }
			let _ = ALBNoSQLDB.deleteForKey(table: Table.locations, key: key)
		}
	}

	class func fixDuplicateNames() {
		let duplicateNamesSQL = "select name from \(Table.locations) group by name having count(*) > 1"

		let db = ALBNoSQLDB.sharedInstance
		guard let nameResults = db.sqlSelect(duplicateNamesSQL) , nameResults.count > 0 else { return }
		for nameRow in nameResults {
			// if there's a problem here, just return
			guard let name = nameRow.values[0] as? String else { return }

			// get keys for locations with this exact name. First one will be keeper, others will be deleted and records changed to use this key
			var keptLocationKey = ""
			var sql = "select key from \(Table.locations) where name = '\(db.esc(name))'"

			guard let results = db.sqlSelect(sql) else { return }
			for row in results {
				// if there's a problem here, just return
				guard let locationKey = row.values[0] as? String else { return }

				if keptLocationKey == "" {
					keptLocationKey = locationKey
					continue
				}

				// convert any transactions, upcoming, or recurring to use keeperKey
				sql = "select key from \(Table.transactions) where locationKey = '\(locationKey)'"
				guard let transactionKeys = db.sqlSelect(sql) else { return }
				for transactionKey in transactionKeys {
					guard let transaction = Transaction(key: transactionKey.values[0] as! String) else { return }
					transaction.locationKey = keptLocationKey
					let _ = ALBNoSQLDB.setValue(table: Table.transactions, key: transaction.key, value: transaction.jsonValue())
				}

				sql = "select key from \(Table.upcomingTransactions) where locationKey = '\(locationKey)'"
				guard let upcomingTransactionKeys = db.sqlSelect(sql) else { return }
				for transactionKey in upcomingTransactionKeys {
					guard let transaction = Transaction(key: transactionKey.values[0] as! String) else { return }
					transaction.locationKey = keptLocationKey
					let _ = ALBNoSQLDB.setValue(table: Table.transactions, key: transaction.key, value: transaction.jsonValue())
				}

				sql = "select key from \(Table.recurringTransactions) where locationKey = '\(locationKey)'"
				guard let recurringTransactionKeys = db.sqlSelect(sql) else { return }
				for transactionKey in recurringTransactionKeys {
					guard let transaction = Transaction(key: transactionKey.values[0] as! String) else { return }
					transaction.locationKey = keptLocationKey
					let _ = ALBNoSQLDB.setValue(table: Table.transactions, key: transaction.key, value: transaction.jsonValue())
				}

				sql = "select key from \(Table.locationAddresses) where locationKey = '\(locationKey)'"
				guard let locationAddressKeys = db.sqlSelect(sql) else { return }
				for addressKey in locationAddressKeys {
					guard let locationAddress = LocationAddress(key: addressKey.values[0] as! String) else { return }
					locationAddress.locationKey = keptLocationKey
					locationAddress.save()
				}

				// delete location
				let _ = ALBNoSQLDB.deleteForKey(table: Table.locations, key: locationKey)
			}
		}

		print("duplications removed")
	}

	// MARK: - Categories
	class func categoryKeys() -> [String] {
		// TODO: break this out by account if necessary
		if let keys = ALBNoSQLDB.keysInTable(Table.categories, sortOrder: "name") {
			return keys
		}

		return []
	}

	class func categoryForName(_ name: String) -> Category {
		let category = Category()
		category.name = name

		let condition = DBCondition(set: 0, objectKey: "name", conditionOperator: .equal, value: name as AnyObject)
		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.categories, sortOrder: nil, conditions: [condition]) , keys.count > 0 {
			return Category(key: keys[0])!
		}

		category.save()
		return category
	}

	// MARK: - Accounts
	class func accountCount() -> Int {
		let db = ALBNoSQLDB.sharedInstance
		let sql = "select key from \(Table.accounts)"
		if let results = db.sqlSelect(sql) {
			return results.count
		}

		return 0
	}

	class func numCCAccounts() -> Int {
		var accounts = 0

		let condition = DBCondition(set: 0, objectKey: "type", conditionOperator: .equal, value: "Credit Card" as AnyObject)
		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.accounts, sortOrder: nil, conditions: [condition]) {
			accounts = keys.count
		}

		return accounts
	}

	class func firstCCAccount() -> Account {
		let condition = DBCondition(set: 0, objectKey: "type", conditionOperator: .equal, value: "Credit Card" as AnyObject)
		if let keys = ALBNoSQLDB.keysInTableForConditions(Table.accounts, sortOrder: nil, conditions: [condition]) {
			var firstAccount = Account(key: keys[0])!
			let balance = 0
			for key in keys {
				let account = Account(key: key)!
				if account.balance < balance {
					firstAccount = Account(key: key)!
				}
			}

			return firstAccount
		}

		return Account()
	}
}
