//
//  Reconciliation.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/10/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import ALBNoSQLDB

class Reconciliation: ALBNoSQLDBObject {
	var accountKey = CommonFunctions.currentAccountKey
	var beginningBalance = 0
	var endingBalance = 0
	var difference: Int {
		get {
			let expectedEnding = beginningBalance + _transactionSum
			return endingBalance - expectedEnding
		}
	}
	
	var date = Date()
	var transactionKeys = [String]()
	var reconciled = false
	var isNew = true;
	
	private var _transactionSum = 0
	
	func save() {
		if !ALBNoSQLDB.setValue(table: kReconcilationsTable, key: key, value: jsonValue()) {
			// TODO: Handle Error
		}
	}
	
	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kReconcilationsTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}
	
	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			isNew = false
			accountKey = dictValue["accountKey"] as! String
			beginningBalance = dictValue["beginningBalance"] as! Int
			endingBalance = dictValue["endingBalance"] as! Int
			date = ALBNoSQLDB.dateValueForString(dictValue["date"] as! String)!
			transactionKeys = dictValue["transactionKeys"] as! [String]
			reconciled = (dictValue["reconciled"] as! String) == "true" ? true : false
			
			if !reconciled {
				for transactionKey in transactionKeys {
					if let transaction = Transaction(key: transactionKey) {
						_transactionSum += transaction.amount
					} else {
						transactionKeys = transactionKeys.filter({$0 != transactionKey})
					}
				}
			}
		}
		
		super.init(keyValue: keyValue)
	}
	
	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()
		dictValue["accountKey"] = accountKey as AnyObject
		dictValue["beginningBalance"] = beginningBalance as AnyObject
		dictValue["endingBalance"] = endingBalance as AnyObject
		dictValue["date"] = ALBNoSQLDB.stringValueForDate(date) as AnyObject
		dictValue["transactionKeys"] = transactionKeys as AnyObject
		dictValue["reconciled"] = (reconciled ? "true" : "false") as AnyObject
		
		return dictValue
	}
	
	func addTransactionKey(_ transactionKey: String) {
		if !hasTransactionKey(transactionKey) {
			transactionKeys.append(transactionKey)
			let transaction = Transaction(key: transactionKey)!
			_transactionSum += transaction.amount
		}
	}
	
	func removeTransactionKey(_ transactionKey: String) {
		transactionKeys = transactionKeys.filter({$0 != transactionKey})
		
		let transaction = Transaction(key: transactionKey)!
		_transactionSum -= transaction.amount
	}
	
	func hasTransactionKey(_ transactionKey: String) -> Bool {
		return transactionKeys.filter({$0 == transactionKey}).count > 0
	}
}
