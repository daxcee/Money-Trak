//
//  Account.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/21/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

enum AccountType:String {
    case checking = "Checking"
    case savings = "Savings"
    case cash = "Cash"
    case creditCard = "Credit Card"
}

class Account:ALBNoSQLDBObject {
    var name = "Checking"
    var type = AccountType.checking
    var balance = 0
    var maxBalance = 0
	var isNew = true

	var updateTotalAll = true
    var updateUpcomingDays = 14
	var stopUpdatingAtDeposit = true
	
    func save() {
		var recalcAvailable = false
		if !isNew {
			let oldAccount = Account(key: key)!
			if updateTotalAll != oldAccount.updateTotalAll || updateUpcomingDays != oldAccount.updateUpcomingDays || stopUpdatingAtDeposit != oldAccount.stopUpdatingAtDeposit {
				recalcAvailable = true
			}
		}
		
        if !updateTotalAll {
            updateUpcomingDays = 0
        }

        if !ALBNoSQLDB.setValue(table: kAccountsTable, key: key, value: jsonValue()) {
            //TODO: handle error
        }
		
		if recalcAvailable {
			CommonDB.recalculateAllBalances()
		}
    }
	
    convenience init?(key:String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kAccountsTable, key: key) {
			self.init(keyValue: key,dictValue: value)
		} else {
			self.init()
			return nil
		}
    }
    
	override init(keyValue: String, dictValue: [String:AnyObject]? = nil) {
		if let dictValue = dictValue {
			isNew = false
			name = dictValue["name"] as! String
			type = AccountType(rawValue: (dictValue["type"] as! String))!
			balance = dictValue["balance"] as! Int
			maxBalance = dictValue["maxBalance"] as! Int
			updateTotalAll = (dictValue["updateTotalAll"] as! String == "1" ? true : false)
			if dictValue["updateUpcomingDays"] != nil {
				updateUpcomingDays = dictValue["updateUpcomingDays"] as! Int
			}
			
			if dictValue["stopUpdatingAtDeposit"] != nil {
				stopUpdatingAtDeposit = (dictValue["stopUpdatingAtDeposit"] as! String == "1" ? true : false)
			}
		}
		
        super.init(keyValue: keyValue)
    }
    
    override func dictionaryValue() -> [String:AnyObject] {
        var dictValue = [String:AnyObject]()
        dictValue["name"] = name
        dictValue["type"] = type.rawValue
        dictValue["balance"] = balance
        dictValue["maxBalance"] = maxBalance
        dictValue["updateTotalAll"] = (updateTotalAll ? "1" : "0")
		dictValue["updateUpcomingDays"] = updateUpcomingDays
		dictValue["stopUpdatingAtDeposit"] = (stopUpdatingAtDeposit ? "1" : "0")
		
        return dictValue
    }
    
    func updateString() -> String {
        var updateTime = (updateTotalAll ? "Yes" : "No")
		if updateUpcomingDays > 0 {
			updateTime += ", \(updateUpcomingDays) days"
        }
        
        return updateTime
    }
}