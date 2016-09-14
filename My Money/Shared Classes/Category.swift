//
//  Category.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/21/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

class Category: ALBNoSQLDBObject {
	var accountKey = ""
	var name = ""
	var inSummary = true
	
	func save() {
		if !ALBNoSQLDB.setValue(table: kCategoryTable, key: key, value: jsonValue()) {
			// TODO: handle error
		}
	}
	
	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kCategoryTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			self.init()
			return nil
		}
	}
	
	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			name = dictValue["name"] as! String
			accountKey = dictValue["accountKey"] as! String
			if let summaryValue = dictValue["inSummary"] as? String {
				inSummary = (summaryValue == "1" ? true : false)
			} else {
				inSummary = true
			}
			
		}
		
		super.init(keyValue: keyValue)
	}
	
	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()
		dictValue["name"] = name as AnyObject?
		dictValue["accountKey"] = accountKey as AnyObject
		dictValue["inSummary"] = (inSummary ? "1": "0") as AnyObject
		
		return dictValue
	}
}
