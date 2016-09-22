//
//  CommonFunctions.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/24/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import ALBNoSQLDB

func delay(_ seconds: Double, closure: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(
		deadline: DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

class CommonFunctions {
	fileprivate var defaults = DefaultManager()
	fileprivate var currentAccountKey: String?

	static let instance = CommonFunctions()

	class func totalAmountAvailable() -> Int {
		let amountAvailable = CommonFunctions.instance.defaults.integerForKey(.AmountAvailable)
		return amountAvailable
	}

	class var currentAccountKey: String {
		get {
			let commonFunctions = CommonFunctions.sharedInstance
			if commonFunctions.currentAccountKey == nil {
				var defaultAccount = CommonFunctions.instance.defaults.stringForKey(.DefaultAccount)

				if defaultAccount == nil || !ALBNoSQLDB.tableHasKey(table: kAccountsTable, key: defaultAccount!)! {
					if let keys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder: nil), keys.filter({ $0 == defaultAccount }).count == 0 {
						// assign first in list
						defaultAccount = keys[0]
						CommonFunctions.instance.defaults.setObject(defaultAccount as AnyObject?, forKey: .DefaultAccount)
					}
				}

				commonFunctions.currentAccountKey = defaultAccount!
			}

			return commonFunctions.currentAccountKey!
		}

		set(accountKey) {
			let cf = CommonFunctions.sharedInstance
			if accountKey != cf.currentAccountKey {
				cf.currentAccountKey = accountKey
				CommonFunctions.instance.defaults.setObject(accountKey as AnyObject?, forKey: .DefaultAccount)
			}
		}
	}

	class var sharedInstance: CommonFunctions {
		struct Static {
			static let instance = CommonFunctions()
		}
		return Static.instance
	}
}
