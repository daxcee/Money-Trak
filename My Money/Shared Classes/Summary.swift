//
//  Summary.swift
//  My Money
//
//  Created by Aaron Bratcher on 6/18/15.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import ALBNoSQLDB

struct NumberTable {
	var rows = 0
	var columnAmounts = [[Int?]]()

	mutating func setAmount(_ amount: Int, column: Int, row: Int) {
		verifySizeForColumn(column, row: row)

		var rowAmounts = columnAmounts[column]
		rowAmounts[row] = amount
		columnAmounts[column] = rowAmounts
	}

	func amountAtColumn(_ column: Int, row: Int) -> Int? {
		if columnAmounts.count >= column + 1 {
			var rowAmounts = columnAmounts[column]

			if rowAmounts.count >= row + 1 {
				let amount = rowAmounts[row]
				return amount
			} else {
				return nil
			}
		}

		return nil
	}

	mutating func verifySizeForColumn(_ column: Int, row: Int) {
		while columnAmounts.count < column + 1 {
			let rows = [Int?]()
			columnAmounts.append(rows)
		}

		var rowAmounts = columnAmounts[column]
		var rowsAdded = false
		while rowAmounts.count < row + 1 {
			rowsAdded = true
			rowAmounts.append(nil)
		}

		if rowsAdded {
			columnAmounts[column] = rowAmounts
			rows = row
		}
	}
}

func monthKeyFromDate(_ monthDate: Date) -> String {
	let calendar = NSCalendar.current
	let year = calendar.component(.year, from: monthDate)
	let month = calendar.component(.month, from: monthDate)
	let monthKey = "\(year)_\(month)"

	return monthKey
}

func monthStartFromDate(_ monthDate: Date) -> Date {
	let calendar = NSCalendar.current

	var monthDate = Date().midnight()
	let year = calendar.component(.year, from: monthDate)
	let month = calendar.component(.month, from: monthDate)

	var components = DateComponents()
	components.year = year
	components.month = month
	components.day = 1

	monthDate = calendar.date(from: components)!.midnight()

	return monthDate
}

struct SummaryMatrix {
	var monthStartDates = [Date]()
	var monthEndDates = [Date]()
	var monthNames = [String]()
	var categoryNames = [String]()
	var amounts = NumberTable()
	var percents = NumberTable()
	var maxMonths = 3

	class MonthSummary: ALBNoSQLDBObject {
		var startDate = Date()
		var endDate = Date()
		var categories = [String]()
		var amounts = [Int]()

		func save() {
			if !ALBNoSQLDB.setValue(table: Table.monthlySummaryEntries, key: key, value: jsonValue()) {
				// TODO: handle error
			}
		}

		convenience init?(key: String) {
			if let value = ALBNoSQLDB.dictValueForKey(table: Table.monthlySummaryEntries, key: key) {
				self.init(keyValue: key, dictValue: value)
			} else {
				return nil
			}
		}

		override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
			if let dictValue = dictValue {
				categories = dictValue["categories"] as! [String]
				amounts = dictValue["amounts"] as! [Int]
				startDate = ALBNoSQLDB.dateValueForString(dictValue["startDate"] as! String)!
				endDate = ALBNoSQLDB.dateValueForString(dictValue["endDate"] as! String)!
			}

			super.init(keyValue: keyValue)
		}

		override func dictionaryValue() -> [String: AnyObject] {
			var dictValue = [String: AnyObject]()
			dictValue["categories"] = categories as AnyObject
			dictValue["amounts"] = amounts as AnyObject
			dictValue["startDate"] = startDate.stringValue() as AnyObject
			dictValue["endDate"] = endDate.stringValue() as AnyObject

			return dictValue
		}
	}

	init() {
		maxMonths = Int.max

		let db = ALBNoSQLDB.sharedInstance
		var sql = "select distinct name from categories c inner join transactions t on t.categoryKey = c.key where c.inSummary = '1' order by name"
		if let rows = db.sqlSelect(sql), rows.count > 0 {
			for row in rows {
				categoryNames.append(row.values[0] as! String)
			}
		} else {
			return
		}

		if let rows = db.sqlSelect("select min(date) from transactions"), rows.count > 0 {
			if let minTransactionDate = ALBNoSQLDB.dateValueForString(rows[0].values[0] as! String) {
				let (finalDate, _) = gregorianMonthForDate(minTransactionDate.addDate(years: 0, months: -1, weeks: 0, days: 0))

				var monthDate = monthStartFromDate(Date())
				var monthColumn = 0

				repeat {
					var monthEntries: MonthSummary
					let monthKey = monthKeyFromDate(monthDate)

					if let entry = MonthSummary(key: monthKey) {
						monthEntries = entry
					} else {
						// get entries for month
						monthEntries = MonthSummary()
						monthEntries.key = monthKey

						let (startDate, endDate) = gregorianMonthForDate(monthDate)
						monthEntries.startDate = startDate
						monthEntries.endDate = endDate

						sql = "select sum(t.amount) as amount, c.name as category from transactions t inner join categories c on c.key = t.categoryKey and c.inSummary = '1' where date between '\(startDate)' and '\(endDate)' group by c.name"
						let transactions = db.sqlSelect(sql)!

						for transaction in transactions {
							let amount = transaction.values[0] as! Int
							let category = transaction.values[1] as! String

							monthEntries.categories.append(category)
							monthEntries.amounts.append(amount)
						}

						// save month to table
						let _ = ALBNoSQLDB.setValue(table: Table.monthlySummaryEntries, key: monthKey, value: monthEntries.jsonValue(), autoDeleteAfter: nil)
					}

					monthStartDates.append(monthEntries.startDate)
					monthEndDates.append(monthEntries.endDate)
					monthNames.append(monthFormatter.string(from: monthDate))

					for index in 0 ..< monthEntries.categories.count {
						var amount = monthEntries.amounts[index]
						let category = monthEntries.categories[index]
						if amount > 0 {
							var adjustedAmount = Double(amount) / 100.0
							adjustedAmount = ceil(adjustedAmount)
							amount = Int(adjustedAmount * 100)
						} else {
							var adjustedAmount = Double(amount) / 100.0
							adjustedAmount = floor(adjustedAmount)
							amount = Int(adjustedAmount * 100)
						}

						if let row = indexOfCategory(category) {
							amounts.setAmount(amount, column: monthColumn, row: row)
						}
					}

					// move to prior month
					monthDate = monthDate.addDate(years: 0, months: -1, weeks: 0, days: 0)
					monthColumn += 1
				} while monthDate.stringValue() > finalDate.stringValue() && monthColumn < maxMonths

				// calculate total row
				categoryNames.append("Total")
				for column in 0 ..< monthNames.count {
					var amount = 0
					for row in 0 ..< categoryNames.count {
						if let cellValue = amounts.amountAtColumn(column, row: row) {
							amount = amount + cellValue
						}
					}
					amounts.setAmount(amount, column: column, row: categoryNames.count - 1)
				}

				// calculate percents
				for column in 0 ..< monthNames.count {
					let row = categoryNames.count - 1
					if let amount = amounts.amountAtColumn(column, row: row), amount != 0 {
						for row in 0 ..< categoryNames.count {
							if let cellValue = amounts.amountAtColumn(column, row: row) {
								let percent = Int(ceil(Double(cellValue) / Double(amount) * 100.0))
								percents.setAmount(percent, column: column, row: row)
							}
						}
					}
				}
			}
		}
	}

	func indexOfCategory(_ category: String) -> Int? {
		for index in 0 ..< categoryNames.count {
			if categoryNames[index] == category {
				return index
			}
		}

		return nil
	}

	func sortByColumn(_ column: Int) {
	}

	func transactionKeysForRow(_ row: Int) -> [String] {
		let db = ALBNoSQLDB.sharedInstance
		let sql = "select t.key from transactions t inner join categories c on c.key = t.categoryKey and c.name = '\(categoryNames[row])'"

		if let transactions = db.sqlSelect(sql) {
			return transactions.map({ $0.values[0] as! String })
		}

		return []
	}

	func transactionKeysForColumn(_ column: Int, row: Int) -> [String] {
		let db = ALBNoSQLDB.sharedInstance

		let sql = "select t.key from transactions t inner join categories c on c.key = t.categoryKey and c.name = '\(categoryNames[row])' where t.date >= '\(monthStartDates[column])' and t.date < '\(monthEndDates[column])'"

		if let transactions = db.sqlSelect(sql) {
			return transactions.map({ $0.values[0] as! String })
		}

		return []
	}
}
