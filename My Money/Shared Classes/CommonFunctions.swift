//
//  CommonFunctions.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/24/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

func delay(seconds: Double, closure: () -> ()) {
	dispatch_after(
		dispatch_time(
			DISPATCH_TIME_NOW,
			Int64(seconds * Double(NSEC_PER_SEC))
		),
		dispatch_get_main_queue(), closure)
}

class CommonFunctions {
	private var defaults = DefaultManager()
	private var currentAccountKey: String?

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
					if let keys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder: nil) where keys.filter({ $0 == defaultAccount }).count == 0 {
						// assign first in list
						defaultAccount = keys[0]
						CommonFunctions.instance.defaults.setObject(defaultAccount, forKey: .DefaultAccount)
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
				CommonFunctions.instance.defaults.setObject(accountKey, forKey: .DefaultAccount)
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