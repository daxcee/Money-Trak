//
//  Spending.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/21/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

class Budget: ALBNoSQLDBObject {
	var name = ""
	var accountKey = ""
	var startDate = Date()
	var endDate = Date()
	
	
	func save() {
		if !ALBNoSQLDB.setValue(table: kBudgetsTable, key: key, value: jsonValue()) {
			// TODO: handle error
		}
	}
	
	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kBudgetsTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}
	
	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			name = dictValue["name"] as! String
			accountKey = dictValue["accountKey"] as! String
			startDate = ALBNoSQLDB.dateValueForString(dictValue["startDate"] as! String)!
			endDate = ALBNoSQLDB.dateValueForString(dictValue["endDate"] as! String)!
		}
		
		super.init(keyValue: keyValue)
	}
	
	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()
		dictValue["name"] = name as AnyObject
		dictValue["accountKey"] = accountKey as AnyObject
		dictValue["startDate"] = ALBNoSQLDB.stringValueForDate(startDate) as AnyObject
		dictValue["endDate"] = ALBNoSQLDB.stringValueForDate(endDate) as AnyObject
		
		return dictValue
	}
}

class BudgetEntry: ALBNoSQLDBObject {
	var name = ""
	var budgetKey = ""
	var categoryKey = ""
	var amount = 0
	
	func save() {
		if !ALBNoSQLDB.setValue(table: kBudgetEntriesTable, key: key, value: jsonValue()) {
			// TODO: handle error
		}
	}
	
	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kBudgetEntriesTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}
	
	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			name = dictValue["name"] as! String
			budgetKey = dictValue["budgetKey"] as! String
			categoryKey = dictValue["categoryKey"] as! String
			amount = dictValue["amount"] as! Int
		}
		
		super.init(keyValue: keyValue)
	}
	
	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()
		dictValue["name"] = name as AnyObject
		dictValue["budgetKey"] = budgetKey as AnyObject
		dictValue["categoryKey"] = categoryKey as AnyObject
		dictValue["amount"] = amount as AnyObject
		
		return dictValue
	}
	
}

class MonthlySummaryEntry: ALBNoSQLDBObject {
	var name = ""
	var categoryKey = ""
	var startDate = Date()
	var endDate = Date()
	var amount = 0
	
	func save() {
		if !ALBNoSQLDB.setValue(table: kMonthlySummaryEntriesTable, key: key, value: jsonValue()) {
			// TODO: handle error
		}
	}
	
	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kMonthlySummaryEntriesTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}
	
	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			name = dictValue["name"] as! String
			categoryKey = dictValue["categoryKey"] as! String
			startDate = ALBNoSQLDB.dateValueForString(dictValue["startDate"] as! String)!
			endDate = ALBNoSQLDB.dateValueForString(dictValue["endDate"] as! String)!
			amount = dictValue["amount"] as! Int
		}
		
		super.init(keyValue: keyValue)
	}
	
	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()
		dictValue["name"] = name as AnyObject
		dictValue["categoryKey"] = categoryKey as AnyObject
		dictValue["startDate"] = ALBNoSQLDB.stringValueForDate(startDate) as AnyObject
		dictValue["endDate"] = ALBNoSQLDB.stringValueForDate(endDate) as AnyObject
		dictValue["amount"] = amount as AnyObject
		
		return dictValue
	}
}
