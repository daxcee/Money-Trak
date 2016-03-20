//
// CommonDB.swift
// My Money
//
// Created by Aaron Bratcher on 08/24/2014.
// Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

// table constants
let kAccountsTable = "Accounts"
let kCategoryTable = "Categories"
let kLocationsTable = "Locations"
let kLocationAddressesTable = "LocationAddresses"
let kTransactionsTable = "Transactions"
let kProcessedTransactionsTable = "ProcessedTransactions"
let kNotifiedTransactionsTable = "NotifiedTransactions"
let kBudgetsTable = "Budgets"
let kBudgetEntriesTable = "BudgetEntries"
let kUpcomingTransactionsTable = "UpcomingTransactions"
let kRecurringTransactionsTable = "RecurringTransactions"
let kMonthlySummaryEntriesTable = "MonthlySummaryEntries"
let kReconcilationsTable = "Reconciliations"
let kDevicesTable = "Devices"

// user notification constants
let kNegativeBalanceWarning = "NegativeBalanceWarning"
let kNegativeBalanceGone = "NegativeBalanceGone"

// program notification constants
let kUpdateTotalAvailableNotification = "UpdateTotalAvailable"
let kUpdateUpcomingTransactionsNotification = "UpdateUpcomingTransactions"

let kInitialBalance = "Initial Balance"
let defaultPrefix = "MMDefault:"

let dbProcessingQueue = dispatch_queue_create("com.AaronLBratcher.processingQueue", DISPATCH_QUEUE_CONCURRENT)

enum TransactionFilter {
	case all(String)
	case outstanding(String)
	case cleared(String)
}

enum DefaultCategory: String {
	case AutoMaintenance = "Auto Maintenance"
	case AutoTransportation = "Auto/Transportation"
	case Clothing = "Clothing"
	case Debt = "Debt"
	case Education = "Education/Day Care"
	case EatingOut = "Eating Out"
	case Entertainment = "Entertainment"
	case Food = "Food"
	case Gas = "Gas"
	case HealthBeauty = "Health/Beauty"
	case HomeFurnishings = "Home Furnishings"
	case HomeMaintenance = "Home Maintenance"
	case Insurance = "Insurance"
	case Interest
	case MedicalDental = "Medical/Dental"
	case Miscellaneous = "Miscellaneous"
	case Payroll = "Payroll"
	case RentMortgage = "Rent/Mortgage"
	case SavingsInvestment = "Saving/Investment"
	case Taxes = "Taxes"
	case TithingCharity = "Tithing/Charity"
	case Utilities = "Utilities"
	case Vacation = "Vacation"

	static func allCategories() -> [DefaultCategory] {
		return [.AutoMaintenance
			, .AutoTransportation
			, .Clothing
			, .Debt
			, .Education
			, .EatingOut
			, .Entertainment
			, .Food
			, .Gas
			, .HealthBeauty
			, .HomeFurnishings
			, .HomeMaintenance
			, .Insurance
			, .Interest
			, .MedicalDental
			, .Miscellaneous
			, .Payroll
			, .RentMortgage
			, .SavingsInvestment
			, .Taxes
			, .TithingCharity
			, .Utilities
			, .Vacation
		]
	}
}

class CommonDB: Numbers {
	static let instance = CommonDB()
	var defaults = DefaultManager()

	class func setup() {
		if !ALBNoSQLDB.syncingEnabled()! {
			if !ALBNoSQLDB.enableSyncing() {
				// TODO: handle error
			}
		}

		if !ALBNoSQLDB.setUnsyncedTables([kDevicesTable, kProcessedTransactionsTable, kNotifiedTransactionsTable, kMonthlySummaryEntriesTable]) {
			print("unable to set unsyncedTables")
		}

		for category in DefaultCategory.allCategories() {
			addCategory(category)
		}

		// setup default account
		if let accountKeys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder: nil) where accountKeys.count == 0 {
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

		ALBNoSQLDB.setTableIndexes(table: kTransactionsTable, indexes: ["accountKey", "date"])
		ALBNoSQLDB.setTableIndexes(table: kUpcomingTransactionsTable, indexes: ["date"])

		dispatch_async(dbProcessingQueue, { () -> Void in
			self.processUpcomingTransactions(false)
			self.checkForNegativeUpcoming(nil)
			self.removeUnusedLocations()
			self.fixDuplicateNames()
		})
	}

	class func addCategory(category: DefaultCategory) {
		let categoryKey = defaultPrefix + category.rawValue
		let condition = DBCondition(set: 0, objectKey: "key", conditionOperator: .equal, value: categoryKey)
		if let keys = ALBNoSQLDB.keysInTableForConditions(kCategoryTable, sortOrder: nil, conditions: [condition]) where keys.count > 0 {
			// category already exists
			return
		}

		let newCategory = Category()
		newCategory.key = categoryKey
		newCategory.name = category.rawValue
		if category == .Payroll {
			newCategory.inSummary = false
		}

		newCategory.save()
	}

	class func calcAmountAvailable() {
		dispatch_async(dbProcessingQueue) { () -> Void in
			var amountAvailable = 0

			let updateCondition = DBCondition(set: 0, objectKey: "updateTotalAll", conditionOperator: .equal, value: 1)
			if let accountKeys = ALBNoSQLDB.keysInTableForConditions(kAccountsTable, sortOrder: nil, conditions: [updateCondition]) {
				for accountKey in accountKeys {
					let account = Account(key: accountKey)!
					// process transactions to update account balance

					amountAvailable += account.balance

					// process upcoming transactions
					let processDate = UpcomingTransaction.processDate(account)
					let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key)
					let depositCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: .notEqual, value: "deposit")
					let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: processDate.stringValue())

					if let upcomingKeys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: "date,amount", conditions: [accountCondition, depositCondition, dateCondition]) {
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
							ALBNoSQLDB.setValue(table: kProcessedTransactionsTable, key: transaction.key, value: "{}", autoDeleteAfter: nil)
						}
					}
				}
			}

			CommonDB.instance.defaults.setInteger(amountAvailable, forKey: .AmountAvailable)
			NSNotificationCenter.defaultCenter().postNotificationName(kUpdateTotalAvailableNotification, object: nil)
		}
	}

	// MARK: - Transactions
	class func processUpcomingTransactions(force: Bool) {
		let now = NSDate()

		if !force {
			// only do this twice a day
			if let processDate = CommonDB.instance.defaults.objectForKey(.UpcomingTransactionScan) as? NSDate {
				let checkDate = processDate.addTime(hours: 12, minutes: 0, seconds: 0)
				if checkDate.earlierDate(now) == now {
					return
				}
			}
		}

		if let instanceKey = ALBNoSQLDB.dbInstanceKey() {
			let deviceCondition = DBCondition(set: 0, objectKey: "dbInstanceKey", conditionOperator: .equal, value: instanceKey)
			let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThan, value: ALBNoSQLDB.stringValueForDate(NSDate().addDate(years: 0, months: 2, weeks: 0, days: 0)))
			let today = NSDate().midnight()
			var accountProcessDates = [String: NSDate]()

			if let keys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: "date", conditions: [deviceCondition, dateCondition]) {
				var finalRecurringKeys = [String]()
				for key in keys {
					let upcomingTransaction = UpcomingTransaction(key: key)!
					let account = Account(key: upcomingTransaction.accountKey)!

					// move from upcoming into standard transaction if necessary
					if today.laterDate(upcomingTransaction.date) == today {
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
						var processDate: NSDate

						if accountProcessDates[account.key] == nil {
							let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key)
							let depositCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: .equal, value: "deposit")
							let updateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: NSDate().midnight().addDate(years: 0, months: 0, weeks: 0, days: account.updateUpcomingDays).stringValue())

							processDate = NSDate().midnight().addDate(years: 0, months: 0, weeks: 0, days: account.updateUpcomingDays)

							if account.stopUpdatingAtDeposit {
								let depositKeys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: "date", conditions: [accountCondition, depositCondition, updateCondition])
								if depositKeys != nil && depositKeys!.count > 0 {
									let deposit = UpcomingTransaction(key: depositKeys![0])!
									if deposit.date.laterDate(processDate) == processDate {
										processDate = deposit.date
									}
								}
							}

							accountProcessDates[account.key] = processDate
						} else {
							processDate = accountProcessDates[account.key]!
						}

						if upcomingTransaction.type != .deposit && upcomingTransaction.date.earlierDate(processDate) == upcomingTransaction.date {
							// see if need to adjust total available
							let hasKey = ALBNoSQLDB.tableHasKey(table: kProcessedTransactionsTable, key: key)
							if !hasKey! {
								upcomingTransaction.processAmountAvailable()
							}
						}

						// see if an alert notification needs to be made
						let userInfo = ["transaction": upcomingTransaction]
						NSNotificationCenter.defaultCenter().postNotificationName("CreateLocalNotification", object: nil, userInfo: userInfo)
					}
				}

				if finalRecurringKeys.count > 0 {
					let userInfo = ["keys": finalRecurringKeys]
					NSNotificationCenter.defaultCenter().postNotificationName("LastRecurringProcessed", object: nil, userInfo: userInfo)
				}
			} else {
				// error opening DB, couldn't get keys
				return
			}

			CommonDB.instance.defaults.setObject(now.midnight(), forKey: .UpcomingTransactionScan)

			NSNotificationCenter.defaultCenter().postNotificationName(kUpdateTotalAvailableNotification, object: nil)
		}

		calcAmountAvailable()
	}

	class func checkForNegativeUpcoming(accountKey: String?) {
		let now = NSDate()

		if accountKey == nil {
			let processDate: NSDate? = CommonDB.instance.defaults.objectForKey(.UpcomingBalanceScan) as? NSDate
			if processDate != nil {
				let checkDate = processDate!.addTime(hours: 24, minutes: 0, seconds: 0)
				if checkDate.earlierDate(now) == now {
					return
				}
			}
		}

		CommonDB.instance.defaults.setObject(now, forKey: .UpcomingBalanceScan)

		let keys = upcomingTransactionKeys(.all(""))
		var accountKeys = [String]()
		if accountKey == nil {
			// get accounts
			for key in keys {
				let transaction = UpcomingTransaction(key: key)!
				if accountKeys.filter({ $0 == transaction.accountKey}).count == 0 {
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
				let transaction = UpcomingTransaction(key: key)!
				if transaction.accountKey != accountKey {
					continue
				}

				balance += transaction.amount
				if balance < 0 {
					showAlert = true
				}
			}
		}

		let alertDate = CommonDB.instance.defaults.objectForKey(.UpcomingTransactionsWarning) as? NSDate

		if showAlert {
			if alertDate != nil {
				let newShowDate = alertDate!.addTime(hours: 24, minutes: 0, seconds: 0)
				// alert was previously shown. Wait 24 hours before showing it again.
				if NSDate().laterDate(newShowDate) == newShowDate {
					return
				}
			}

			CommonDB.instance.defaults.setObject(now, forKey: .UpcomingTransactionsWarning)

			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				NSNotificationCenter.defaultCenter().postNotificationName(kNegativeBalanceWarning, object: nil)
			})
		} else {
			CommonDB.instance.defaults.removeObjectForKey(.UpcomingTransactionsWarning)

			if alertDate != nil {
				// alert was previously shown and now we're okay
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					NSNotificationCenter.defaultCenter().postNotificationName(kNegativeBalanceGone, object: nil)
				})
			}
		}
	}

	class func generateUpcomingFromRecurring(recurringTransaction: RecurringTransaction) {
		// delete all pending upcoming transactions
		dispatch_async(dbProcessingQueue, { () -> Void in
			let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: recurringTransaction.recurringTransactionKey)
			let keys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: nil, conditions: [recurringCondition])
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
					if recurringTransaction.endDate!.laterDate(date) == date {
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

			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				NSNotificationCenter.defaultCenter().postNotificationName(kUpdateUpcomingTransactionsNotification, object: nil)
				NSNotificationCenter.defaultCenter().postNotificationName(kUpdateTotalAvailableNotification, object: nil)
			})
		})
	}

	class func transactionKeys(filter: TransactionFilter) -> [String] {
		let account = CommonFunctions.currentAccountKey
		if account != "" {
			var accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account)
			var searchString = ""
			var reconciledCondition: DBCondition?

			switch filter {
			case .all(let searchText):
				searchString = searchText
			case .cleared(let searchText):
				searchString = searchText
				reconciledCondition = DBCondition(set: 0, objectKey: "reconciled", conditionOperator: .equal, value: "true")
			case .outstanding(let searchText):
				searchString = searchText
				reconciledCondition = DBCondition(set: 0, objectKey: "reconciled", conditionOperator: .equal, value: "false")
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

			let keys = ALBNoSQLDB.keysInTableForConditions(kTransactionsTable, sortOrder: "date desc,amount desc", conditions: finalConditionSet)
			if keys == nil {
				// TODO: handle error
				return []
			}
			return keys!
		}

		return []
	}

	class func upcomingTransactionKeys(filter: TransactionFilter) -> [String] {
		let futureDate = NSDate().addDate(years: 0, months: 1, weeks: 0, days: 0)
		let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: futureDate.stringValue())
		let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .notEqual, value: "")
		let manualCondition = DBCondition(set: 1, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: "")

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

		let keys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: "date,amount", conditions: finalConditionSet)
		if keys == nil {
			// TODO: handle error
			return []
		}
		return keys!
	}

	class func recurringTransactionCount() -> Int {
		let db = ALBNoSQLDB.sharedInstance
		let sql = "select key from \(kRecurringTransactionsTable)"
		if let results = db.sqlSelect(sql) {
			return results.count
		}

		return 0
	}

	class func recurringTransactionKeys(filter: TransactionFilter) -> [String] {
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

		if let keys = ALBNoSQLDB.keysInTableForConditions(kRecurringTransactionsTable, sortOrder: nil, conditions: finalConditionSet) {
			return keys
		}

		return []
	}

	class func conditionsForSearchString(text: String) -> [DBCondition]? {
		if text == "" || text.characters.count < 2 {
			return nil
		}

		var conditionSet = [DBCondition]()
		var condition: DBCondition

		let amount = CommonDB.instance.amountFromText(text)
		if amount == 0 {
			var set = 0
			let categoryCondition = DBCondition(set: 0, objectKey: "name", conditionOperator: .contains, value: text)
			if let keys = ALBNoSQLDB.keysInTableForConditions(kCategoryTable, sortOrder: nil, conditions: [categoryCondition]) where keys.count > 0 {
				for key in keys {
					condition = DBCondition(set: set, objectKey: "categoryKey", conditionOperator: .equal, value: key)
					conditionSet.append(condition)
					set += 1
				}
			}

			let locationCondition = DBCondition(set: 0, objectKey: "name", conditionOperator: .contains, value: text)
			if let keys = ALBNoSQLDB.keysInTableForConditions(kLocationsTable, sortOrder: nil, conditions: [locationCondition]) where keys.count > 0 {
				for key in keys {
					condition = DBCondition(set: set, objectKey: "locationKey", conditionOperator: .equal, value: key)
					conditionSet.append(condition)
					set += 1
				}
			}

			condition = DBCondition(set: set, objectKey: "note", conditionOperator: .contains, value: text)
			conditionSet.append(condition)

			return conditionSet
		} else {
			condition = DBCondition(set: 0, objectKey: "amount", conditionOperator: .equal, value: abs(amount))
			conditionSet.append(condition)
			condition = DBCondition(set: 1, objectKey: "amount", conditionOperator: .equal, value: -abs(amount))
			conditionSet.append(condition)

			var checkNumber = Double(amount) / 100.0
			checkNumber = floor(checkNumber)
			if checkNumber > 0 {
				condition = DBCondition(set: 2, objectKey: "checkNumber", conditionOperator: .equal, value: checkNumber)
				conditionSet.append(condition)
			}
		}

		return conditionSet
	}

	class func recalculateAllBalances() {
		var amountAvailable = 0
		ALBNoSQLDB.dropTable(kProcessedTransactionsTable)

		// clear spending summary cache
		if let summaryKeys = ALBNoSQLDB.keysInTable(kMonthlySummaryEntriesTable, sortOrder: nil) {
			for key in summaryKeys {
				ALBNoSQLDB.deleteForKey(table: kMonthlySummaryEntriesTable, key: key)
			}
		}

		// reset processDate cache
		CommonDB.instance.defaults.setObject(NSDate().addDate(years: 0, months: 0, weeks: 0, days: -2), forKey: .LastCheckDate)

		if let accountKeys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder: nil) {
			for accountKey in accountKeys {
				let account = Account(key: accountKey)!
				// process transactions to update account balance
				let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key)
				if let transactionKeys = ALBNoSQLDB.keysInTableForConditions(kTransactionsTable, sortOrder: nil, conditions: [accountCondition]) {
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
					let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: account.key)
					let depositCondition = DBCondition(set: 0, objectKey: "type", conditionOperator: .notEqual, value: "deposit")
					let dateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: processDate.stringValue())

					if let upcomingKeys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder: "date,amount", conditions: [accountCondition, depositCondition, dateCondition]) {
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
							ALBNoSQLDB.setValue(table: kProcessedTransactionsTable, key: transaction.key, value: "{}", autoDeleteAfter: nil)
						}
					}
				}
			}
		}

		CommonDB.instance.defaults.setInteger(amountAvailable, forKey: .AmountAvailable)

		NSNotificationCenter.defaultCenter().postNotificationName(kUpdateTotalAvailableNotification, object: nil)
	}

	// MARK: - Reconciliations
	class func reconciliationCount() -> Int {
		let db = ALBNoSQLDB.sharedInstance
		let sql = "select key from \(kReconcilationsTable)"
		if let results = db.sqlSelect(sql) {
			return results.count
		}

		return 0
	}

	class func accountReconciliations(accountKey: String) -> [String] {
		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: accountKey)

		if let keys = ALBNoSQLDB.keysInTableForConditions(kReconcilationsTable, sortOrder: "date desc", conditions: [accountCondition]) {
			return keys
		}

		return [String]()
	}

	typealias reconciliationTransactionsFound = (transactionKeys: [String]) -> ()
	class func loadTransactionsForReconciliation(reconciliation: Reconciliation, searchString: String? = nil, onComplete: reconciliationTransactionsFound) {
		// if this isn't new, then just use the transactions saved with the reconciliation
		if reconciliation.reconciled {
			let db = ALBNoSQLDB.sharedInstance
			let keys = reconciliation.transactionKeys.map({ "'" + $0 + "'"}).joinWithSeparator(",")
			let sql = "select key from transactions where key in (\(keys)) order by date desc, amount desc"
			if let results = db.sqlSelect(sql) {
				onComplete(transactionKeys: results.map({ $0.values[0] as! String}))
				return
			}

			onComplete(transactionKeys: reconciliation.transactionKeys)
			return
		}

		dispatch_async(dbProcessingQueue, { () -> Void in
			// get unreconciled transactions for this account with a date less than this reconciliation date
			var endDateCondition = DBCondition(set: 0, objectKey: "date", conditionOperator: .lessThanOrEqual, value: reconciliation.date.midnight().stringValue())
			var accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: reconciliation.accountKey)
			var reconciledCondition = DBCondition(set: 0, objectKey: "reconciled", conditionOperator: .equal, value: "false")

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

			let transactionKeys = ALBNoSQLDB.keysInTableForConditions(kTransactionsTable, sortOrder: "date desc,amount desc", conditions: finalConditionSet)!

			onComplete(transactionKeys: transactionKeys)
		})
	}

	class func lastReconciliationForAccount(accountKey: String, ignoreUnreconciled: Bool = false) -> Reconciliation? {
		let accountCondition = DBCondition(set: 0, objectKey: "accountKey", conditionOperator: .equal, value: accountKey)
		var lastReconciliation: Reconciliation?

		if let reconciliationKeys = ALBNoSQLDB.keysInTableForConditions(kReconcilationsTable, sortOrder: "date desc", conditions: [accountCondition]) where reconciliationKeys.count > 0 {
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

	class func createInitialBalanceTransaction(reconciliation: Reconciliation) -> String {
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

		let sql = "select date from \(kTransactionsTable) where accountKey = '\(reconciliation.accountKey)' order by date limit 1"
		let db = ALBNoSQLDB.sharedInstance
		var minDate = reconciliation.date
		if let results = db.sqlSelect(sql) where results.count > 0 {
			let dateString = results[0].values[0] as! String
			minDate = ALBNoSQLDB.dateValueForString(dateString)!
		}

		minDate = minDate.earlierDate(reconciliation.date)

		// set minDate to a month prior
		minDate = minDate.addDate(years: 0, months: -1, weeks: 0, days: 0)

		let calendar = NSCalendar.currentCalendar()
		let dateComponents = calendar.components([NSCalendarUnit.Year, NSCalendarUnit.Month, NSCalendarUnit.Day], fromDate: minDate)

		dateComponents.day = 1
		dateComponents.hour = 0
		dateComponents.minute = 0
		dateComponents.second = 0

		minDate = calendar.dateFromComponents(dateComponents)!

		let location = locationForName(kInitialBalance)
		transaction.date = minDate
		transaction.locationKey = location.key
		transaction.reconciled = true
		transaction.save()

		return transaction.key
	}

	class func updateInitialBalanceTransaction(transactionKey: String, reconciliation: Reconciliation) {
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
	class func locationForName(name: String) -> Location {
		let location = Location()
		location.name = name

		let condition = DBCondition(set: 0, objectKey: "name", conditionOperator: .equal, value: name)
		let conditionArray = [condition]
		if let keys = ALBNoSQLDB.keysInTableForConditions(kLocationsTable, sortOrder: nil, conditions: conditionArray) where keys.count > 0 {
			return Location(key: keys[0])!
		}

		location.save()
		return location
	}

	class func locationKeysForString(string: String) -> [String] {
		if string == "" {
			return []
		}

		let condition = DBCondition(set: 0, objectKey: "name", conditionOperator: .contains, value: string)
		let conditionArray = [condition]
		if let keys = ALBNoSQLDB.keysInTableForConditions(kLocationsTable, sortOrder: "name", conditions: conditionArray) {
			return keys
		}

		return []
	}

	class func saveLocationForAddress(addressKey: String, locationKey: String) {
		// see if we have this address registered
		var locationAddress = LocationAddress()

		let hasKey = ALBNoSQLDB.tableHasKey(table: kLocationAddressesTable, key: addressKey)
		if hasKey != nil && hasKey! {
			locationAddress = LocationAddress(key: addressKey)!
		} else {
			locationAddress.key = addressKey
		}

		locationAddress.locationKey = locationKey
		locationAddress.save()
	}

	class func locationForAddress(addressKey: String) -> Location? {
		guard let locationAddress = LocationAddress(key: addressKey), location = Location(key: locationAddress.locationKey) else { return nil }
		return location
	}

	class func removeUnusedLocations() {
		let latestDate = NSDate().addDate(years: 0, months: -1, weeks: 0, days: 0)
		let sql = "select l.key from \(kLocationsTable) l left outer join \(kTransactionsTable) t on t.locationKey = l.key left outer join \(kUpcomingTransactionsTable) u on u.locationKey = l.key where t.locationKey is null and u.locationKey is null and l.addedDateTime < '\(latestDate.stringValue())'"

		let db = ALBNoSQLDB.sharedInstance
		guard let results = db.sqlSelect(sql) else { return }

		for row in results {
			guard let key = row.values[0] as? String else { continue }
			ALBNoSQLDB.deleteForKey(table: kLocationsTable, key: key)
		}
	}

	class func fixDuplicateNames() {
		let duplicateNamesSQL = "select name from \(kLocationsTable) group by name having count(*) > 1"

		let db = ALBNoSQLDB.sharedInstance
		guard let nameResults = db.sqlSelect(duplicateNamesSQL) where nameResults.count > 0 else { return }
		for nameRow in nameResults {
			// if there's a problem here, just return
			guard let name = nameRow.values[0] as? String else { return }

			// get keys for locations with this exact name. First one will be keeper, others will be deleted and records changed to use this key
			var keptLocationKey = ""
			var sql = "select key from \(kLocationsTable) where name = '\(db.esc(name))'"

			guard let results = db.sqlSelect(sql) else { return }
			for row in results {
				// if there's a problem here, just return
				guard let locationKey = row.values[0] as? String else { return }

				if keptLocationKey == "" {
					keptLocationKey = locationKey
					continue
				}

				// convert any transactions, upcoming, or recurring to use keeperKey
				sql = "select key from \(kTransactionsTable) where locationKey = '\(locationKey)'"
				guard let transactionKeys = db.sqlSelect(sql) else { return }
				for transactionKey in transactionKeys {
					guard let transaction = Transaction(key: transactionKey.values[0] as! String) else { return }
					transaction.locationKey = keptLocationKey
					ALBNoSQLDB.setValue(table: kTransactionsTable, key: transaction.key, value: transaction.jsonValue())
				}

				sql = "select key from \(kUpcomingTransactionsTable) where locationKey = '\(locationKey)'"
				guard let upcomingTransactionKeys = db.sqlSelect(sql) else { return }
				for transactionKey in upcomingTransactionKeys {
					guard let transaction = Transaction(key: transactionKey.values[0] as! String) else { return }
					transaction.locationKey = keptLocationKey
					ALBNoSQLDB.setValue(table: kTransactionsTable, key: transaction.key, value: transaction.jsonValue())
				}

				sql = "select key from \(kRecurringTransactionsTable) where locationKey = '\(locationKey)'"
				guard let recurringTransactionKeys = db.sqlSelect(sql) else { return }
				for transactionKey in recurringTransactionKeys {
					guard let transaction = Transaction(key: transactionKey.values[0] as! String) else { return }
					transaction.locationKey = keptLocationKey
					ALBNoSQLDB.setValue(table: kTransactionsTable, key: transaction.key, value: transaction.jsonValue())
				}

				sql = "select key from \(kLocationAddressesTable) where locationKey = '\(locationKey)'"
				guard let locationAddressKeys = db.sqlSelect(sql) else { return }
				for addressKey in locationAddressKeys {
					guard let locationAddress = LocationAddress(key: addressKey.values[0] as! String) else { return }
					locationAddress.locationKey = keptLocationKey
					locationAddress.save()
				}

				// delete location
				ALBNoSQLDB.deleteForKey(table: kLocationsTable, key: locationKey)
			}
		}

		print("duplications removed")
	}

	// MARK: - Categories
	class func categoryKeys() -> [String] {
		// TODO: break this out by account if necessary
		if let keys = ALBNoSQLDB.keysInTable(kCategoryTable, sortOrder: "name") {
			return keys
		}

		return []
	}

	class func categoryForName(name: String) -> Category {
		let category = Category()
		category.name = name

		let condition = DBCondition(set: 0, objectKey: "name", conditionOperator: .equal, value: name)
		if let keys = ALBNoSQLDB.keysInTableForConditions(kCategoryTable, sortOrder: nil, conditions: [condition]) where keys.count > 0 {
			return Category(key: keys[0])!
		}

		category.save()
		return category
	}

	// MARK: - Accounts
	class func accountCount() -> Int {
		let db = ALBNoSQLDB.sharedInstance
		let sql = "select key from \(kAccountsTable)"
		if let results = db.sqlSelect(sql) {
			return results.count
		}

		return 0
	}

	class func numCCAccounts() -> Int {
		var accounts = 0

		let condition = DBCondition(set: 0, objectKey: "type", conditionOperator: .equal, value: "Credit Card")
		if let keys = ALBNoSQLDB.keysInTableForConditions(kAccountsTable, sortOrder: nil, conditions: [condition]) {
			accounts = keys.count
		}

		return accounts
	}

	class func firstCCAccount() -> Account {
		let condition = DBCondition(set: 0, objectKey: "type", conditionOperator: .equal, value: "Credit Card")
		if let keys = ALBNoSQLDB.keysInTableForConditions(kAccountsTable, sortOrder: nil, conditions: [condition]) {
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