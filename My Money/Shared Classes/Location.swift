//
//  Location.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/21/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

class Location:ALBNoSQLDBObject {
    var name = ""
    var categoryKey:String?
    
    func save() {
        if !ALBNoSQLDB.setValue(table: kLocationsTable, key: key, value: jsonValue()) {
            // TODO: handle error
        }
    }
    
    convenience init?(key:String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kLocationsTable, key: key) {
			self.init(keyValue: key,dictValue: value)
		} else {
			self.init()
			return nil
		}
    }
    
    override init(keyValue: String, dictValue: [String:AnyObject]? = nil) {
		if let dictValue = dictValue {
			name = dictValue["name"] as! String
			if dictValue["categoryKey"] != nil {
				categoryKey = dictValue["categoryKey"] as? String
			}
		}
		
        super.init(keyValue: keyValue)
    }
    
    override func dictionaryValue() ->[String:AnyObject] {
        var dictValue = [String:AnyObject]()
        dictValue["name"] = name as AnyObject?
        if categoryKey != nil {
            dictValue["categoryKey"] = categoryKey! as AnyObject?
        }
        
        return dictValue
    }    
}

class LocationAddress:ALBNoSQLDBObject {
    var locationKey = ""
    
    func  save() {
        if !ALBNoSQLDB.setValue(table: kLocationAddressesTable, key: key, value: jsonValue()) {
            // TODO: handle error
        }
    }
    
	
    convenience init?(key:String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kLocationAddressesTable, key: key) {
			self.init(keyValue:key, dictValue:value)
		} else {
			self.init()
			return nil
		}
    }
    
	override init(keyValue: String,  dictValue: [String:AnyObject]? = nil) {
		if let dictValue = dictValue {
			locationKey = dictValue["locationKey"] as! String
		}
        super.init(keyValue: keyValue)
    }
    
    override func dictionaryValue() ->[String:AnyObject] {
        var dictValue = [String:AnyObject]()
        dictValue["locationKey"] = locationKey as AnyObject?
        
        return dictValue
    }
}
