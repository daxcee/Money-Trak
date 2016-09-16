//
//  RecurringTransaction.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 9/15/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation

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
