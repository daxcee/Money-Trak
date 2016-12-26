//
//  LogEntry.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/20/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import ALBNoSQLDB

enum TransactionType: String {
	case purchase
	case deposit
	case ccPayment = "payment"
}

// MARK: - Log Entry

class Transaction: ALBNoSQLDBObject {
	var accountKey = CommonFunctions.currentAccountKey
	var ccAccountKey: String?
	var recurringTransactionKey = ""
	var date = Date()
	var checkNumber: Int?
	var locationKey: String?
	var addressKey: String?
	var categoryKey: String?
	var note: String?
	var amount = 0
	var type = TransactionType.purchase
	var isNew = true
	var reconciled = false
	var defaults = DefaultManager()

	func save() {
		var ccAccount: Account?
		var sameAmount = false
		let account = Account(key: accountKey)!
		var sameAccount = false

		if type == .ccPayment {
			ccAccount = Account(key: ccAccountKey!)
			if let ccAccount = ccAccount {
				locationKey = CommonDB.locationForName(ccAccount.name).key
				// create new transaction against the CC account for the same amount
				let transaction = Transaction()
				transaction.accountKey = ccAccount.key
				transaction.amount = abs(amount)
				transaction.type = TransactionType.deposit
				transaction.locationKey = CommonDB.locationForName("Paid with \(Account(key: accountKey)!.name)").key
				transaction.date = date
				transaction.categoryKey = defaultPrefix + DefaultCategory.debt.rawValue
				let _ = ALBNoSQLDB.setValue(table: kTransactionsTable, key: transaction.key, value: transaction.jsonValue())
				let ccAccount = Account(key: ccAccountKey!)!
				ccAccount.balance += abs(amount)
				ccAccount.save()
			}
		}

		if !isNew {
			let oldTransaction = Transaction(key: key)!
			sameAmount = (amount == oldTransaction.amount)
			sameAccount = (accountKey == oldTransaction.accountKey)

			if !sameAccount {
				delete()
				isNew = true
			} else if !sameAmount {
				if ccAccount == nil || !ccAccount!.updateTotalAll {
					deleteAmountFromAvailable(oldTransaction)
				}
				deleteAmountFromBalances(oldTransaction)
			}
		}

		if locationKey != nil && categoryKey != nil {
			let location = Location(key: locationKey!)!
			location.categoryKey = categoryKey!
			location.save()
		}

		if (!sameAmount || !sameAccount) && account.updateTotalAll {
			if ccAccount == nil || !ccAccount!.updateTotalAll {
				addAmountToAvailable()
			}

			addAmountToBalances()
		}

		// this must be done last to ensure proper reversals above
		if !ALBNoSQLDB.setValue(table: kTransactionsTable, key: key, value: jsonValue()) {
			// TODO: Handle Error
		}

		let monthKey = monthKeyFromDate(date)
		let _ = ALBNoSQLDB.deleteForKey(table: kMonthlySummaryEntriesTable, key: monthKey)
	}

	func delete() {
		deleteAmountFromAvailable(self)
		deleteAmountFromBalances(self)
		let _ = ALBNoSQLDB.deleteForKey(table: kTransactionsTable, key: key)
	}

	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kTransactionsTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			return nil
		}
	}

	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			isNew = false

			accountKey = dictValue["accountKey"] as! String
			date = ALBNoSQLDB.dateValueForString(dictValue["date"] as! String)!
			amount = dictValue["amount"] as! Int
			type = TransactionType(rawValue: dictValue["type"] as! String)!
			recurringTransactionKey = dictValue["recurringTransactionKey"] as! String

			if dictValue["locationKey"] != nil {
				locationKey = dictValue["locationKey"] as? String
			}

			if dictValue["categoryKey"] != nil {
				categoryKey = dictValue["categoryKey"] as? String
			}

			if dictValue["note"] != nil {
				note = dictValue["note"] as? String
			}

			if dictValue["checkNumber"] != nil {
				checkNumber = dictValue["checkNumber"] as? Int
			}

			if dictValue["ccAccountKey"] != nil {
				ccAccountKey = dictValue["ccAccountKey"] as? String
			}

			if dictValue["addressKey"] != nil {
				addressKey = dictValue["addressKey"] as? String
			}

			if dictValue["reconciled"] != nil {
				reconciled = (dictValue["reconciled"] as? String) == "true" ? true : false
			}
		}

		super.init(keyValue: keyValue)
	}

	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()
		dictValue["accountKey"] = accountKey as AnyObject
		dictValue["date"] = date.midnight().stringValue() as AnyObject
		dictValue["amount"] = amount as AnyObject
		dictValue["type"] = type.rawValue as AnyObject
		dictValue["recurringTransactionKey"] = recurringTransactionKey as AnyObject
		dictValue["reconciled"] = (reconciled ? "true" : "false") as AnyObject

		if locationKey != nil {
			dictValue["locationKey"] = locationKey! as AnyObject
		}

		if categoryKey != nil {
			dictValue["categoryKey"] = categoryKey! as AnyObject
		}

		if note != nil {
			dictValue["note"] = note! as AnyObject
		}

		if checkNumber != nil {
			dictValue["checkNumber"] = checkNumber! as AnyObject
		}

		if ccAccountKey != nil {
			dictValue["ccAccountKey"] = ccAccountKey! as AnyObject
		}

		if addressKey != nil {
			dictValue["addressKey"] = addressKey! as AnyObject
		}

		return dictValue
	}

	func locationName() -> String {
		var lName = ""
		if let locationKey = locationKey {
			let location = Location(key: locationKey)
			lName = location!.name
		}

		return lName
	}

	func categoryName() -> String {
		var cName = ""
		if let categoryKey = categoryKey {
			let category = Category(key: categoryKey)
			cName = category!.name
		}

		return cName
	}

	func addAmountToAvailable() {
		let amountAvailable = defaults.integerForKey(.amountAvailable) + amount
		defaults.setInteger(amountAvailable, forKey: .amountAvailable)

		let _ = ALBNoSQLDB.setValue(table: kProcessedTransactionsTable, key: key, value: "{}", autoDeleteAfter: nil)
	}

	func addAmountToBalances() {
		let account = Account(key: accountKey)!
		account.balance += amount
		account.save()
		// TODO: budget balances
		// TODO: monthly summary balances
	}

	func deleteAmountFromAvailable(_ transaction: Transaction) {
		let amountAvailable = defaults.integerForKey(.amountAvailable) - transaction.amount
		defaults.setInteger(amountAvailable, forKey: .amountAvailable)

		let _ = ALBNoSQLDB.deleteForKey(table: kProcessedTransactionsTable, key: key)
	}

	func deleteAmountFromBalances(_ transaction: Transaction) {
		let account = Account(key: accountKey)!
		account.balance -= transaction.amount
		account.save()
		// TODO: budget balances
		// TODO: monthly summary balances
	}
}
