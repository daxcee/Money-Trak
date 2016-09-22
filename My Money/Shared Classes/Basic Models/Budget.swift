//
//  Budget.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 9/16/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import ALBNoSQLDB

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
