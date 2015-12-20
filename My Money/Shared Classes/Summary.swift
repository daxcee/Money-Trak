//
//  Summary.swift
//  My Money
//
//  Created by Aaron Bratcher on 6/18/15.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation

struct NumberTable {
    var rows = 0
    var columnAmounts = [[Int?]]()
    
    mutating func setAmount(amount:Int, column:Int, row:Int) {
        verifySizeForColumn(column, row: row)
        
        var rowAmounts = columnAmounts[column]
        rowAmounts[row] = amount
        columnAmounts[column] = rowAmounts
    }
    
    func amountAtColumn(column:Int, row:Int) -> Int? {
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
    
    mutating func verifySizeForColumn(column:Int, row:Int) {
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

func monthKeyFromDate(monthDate:NSDate) -> String {
    let calendar = NSCalendar.currentCalendar()
    let currentYear = calendar.components(NSCalendarUnit.Year, fromDate: monthDate).year
    let currentMonth = calendar.components(NSCalendarUnit.Month, fromDate: monthDate).month
    let monthKey = "\(currentYear)_\(currentMonth)"

    return monthKey
}

func monthStartFromDate(monthDate:NSDate) -> NSDate {
    let calendar = NSCalendar.currentCalendar()
    
    var monthDate = NSDate().midnight()
    let currentYear = calendar.components(NSCalendarUnit.Year, fromDate: monthDate).year
    let currentMonth = calendar.components(NSCalendarUnit.Month, fromDate: monthDate).month
    
    let components = NSDateComponents()
    components.year = currentYear
    components.month = currentMonth
    components.day = 1
    
    monthDate = calendar.dateFromComponents(components)!.midnight()
    
    return monthDate
}

struct SummaryMatrix {
    var monthStartDates = [NSDate]()
    var monthEndDates = [NSDate]()
    var monthNames = [String]()
    var categoryNames = [String]()
    var amounts = NumberTable()
    var percents = NumberTable()
    var maxMonths = 3
	
    class MonthSummary:ALBNoSQLDBObject {
        var startDate = NSDate()
        var endDate = NSDate()
        var categories = [String]()
        var amounts = [Int]()
        
        func save() {
            if !ALBNoSQLDB.setValue(table: kMonthlySummaryEntriesTable, key: key, value: jsonValue()) {
                // TODO: handle error
            }
        }
        
        convenience init?(key:String) {
            if let value = ALBNoSQLDB.dictValueForKey(table: kMonthlySummaryEntriesTable, key: key) {
                self.init(keyValue:key, dictValue: value)
            } else {
                self.init()
                return nil
            }
        }

        override init(keyValue: String,  dictValue: [String:AnyObject]? = nil) {
            if let dictValue = dictValue {
                categories = dictValue["categories"] as! [String]
                amounts = dictValue["amounts"] as! [Int]
                startDate = ALBNoSQLDB.dateValueForString(dictValue["startDate"] as! String)!
                endDate = ALBNoSQLDB.dateValueForString(dictValue["endDate"] as! String)!
            }
            
            super.init(keyValue: keyValue)
        }

        override func dictionaryValue() ->[String:AnyObject] {
            var dictValue = [String:AnyObject]()
            dictValue["categories"] = categories
            dictValue["amounts"] = amounts
            dictValue["startDate"] = startDate.stringValue()
            dictValue["endDate"] = endDate.stringValue()
            
            return dictValue
        }
    }
    
    init () {
        maxMonths = PurchaseKit.sharedInstance.maxSummaryMonths()
		
        let db = ALBNoSQLDB.sharedInstance
        var sql = "select distinct name from categories c inner join transactions t on t.categoryKey = c.key where c.inSummary = '1' order by name"
        if let rows = db.sqlSelect(sql) where rows.count > 0 {
            for row in rows {
                categoryNames.append(row.values[0] as! String)
            }
        } else {
            return
        }
        
        if let rows = db.sqlSelect("select min(date) from transactions") where rows.count > 0 {
            if let minTransactionDate = ALBNoSQLDB.dateValueForString(rows[0].values[0] as! String) {
                let (finalDate,_) = gregorianMonthForDate(minTransactionDate.addDate(years: 0, months: -1, weeks: 0, days: 0))
                
                var monthDate = monthStartFromDate(NSDate())
                var monthColumn = 0
                
                repeat {
                    var monthEntries:MonthSummary
                    let monthKey = monthKeyFromDate(monthDate)
                    
                    if let entry = MonthSummary(key: monthKey) {
                        monthEntries = entry
                    } else {
                        // get entries for month
                        monthEntries = MonthSummary()
                        monthEntries.key = monthKey
                        
                        let (startDate,endDate) = gregorianMonthForDate(monthDate)
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
                        ALBNoSQLDB.setValue(table: kMonthlySummaryEntriesTable, key: monthKey, value: monthEntries.jsonValue(), autoDeleteAfter: nil)
                    }
                    
                    monthStartDates.append(monthEntries.startDate)
                    monthEndDates.append(monthEntries.endDate)
                    monthNames.append(monthFormatter.stringFromDate(monthDate))
                    
                    for index in 0..<monthEntries.categories.count {
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
                for column in 0..<monthNames.count {
                    var amount = 0
                    for row in 0..<categoryNames.count {
                        if let cellValue = amounts.amountAtColumn(column, row: row) {
                            amount = amount + cellValue
                        }
                    }
                    amounts.setAmount(amount, column: column, row: categoryNames.count-1)
                }
                
                // calculate percents
                for column in 0..<monthNames.count {
                    let row = categoryNames.count-1
                    if let amount = amounts.amountAtColumn(column, row: row) where amount != 0 {
                        for row in 0..<categoryNames.count {
                            if let cellValue = amounts.amountAtColumn(column, row: row) {
                                let percent = Int(ceil(Double(cellValue)/Double(amount)*100.0))
                                percents.setAmount(percent, column: column, row: row)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func indexOfCategory(category:String) -> Int? {
        for index in 0..<categoryNames.count {
            if categoryNames[index] == category {
                return index
            }
        }
        
        return nil
    }
    
    func sortByColumn(column:Int) {
        
    }
    
    func transactionKeysForRow(row:Int) -> [String] {
        let db = ALBNoSQLDB.sharedInstance
        let sql = "select t.key from transactions t inner join categories c on c.key = t.categoryKey and c.name = '\(categoryNames[row])'"
        
        if let transactions = db.sqlSelect(sql) {
            return transactions.map({$0.values[0] as! String})
        }
        
        return []
    }
    
    func transactionKeysForColumn(column:Int, row:Int) -> [String] {
        let db = ALBNoSQLDB.sharedInstance
        
        
        let sql = "select t.key from transactions t inner join categories c on c.key = t.categoryKey and c.name = '\(categoryNames[row])' where t.date >= '\(monthStartDates[column])' and t.date < '\(monthEndDates[column])'"
        
        if let transactions = db.sqlSelect(sql) {
            return transactions.map({$0.values[0] as! String})
        }
        
        return []
    }
    
}


