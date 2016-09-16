//
//  BudgetEntry.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 9/16/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation

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
