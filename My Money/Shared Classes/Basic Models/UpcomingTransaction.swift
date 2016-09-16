//
//  UpcomingTransaction.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 9/15/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation

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
