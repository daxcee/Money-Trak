//
//  CommonFunctions.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/24/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation

extension String {
    func doubleValue() -> Double
    {
        let minusAscii: UInt8 = 45
        let dotAscii: UInt8 = 46
        let zeroAscii: UInt8 = 48
        
        var res = 0.0
        let ascii = self.utf8
        
        var whole = [Double]()
        var current = ascii.startIndex
        
        let negative = current != ascii.endIndex && ascii[current] == minusAscii
        if (negative)
        {
            current = current.successor()
        }
        
        while current != ascii.endIndex && ascii[current] != dotAscii
        {
            whole.append(Double(ascii[current] - zeroAscii))
            current = current.successor()
        }
        
        //whole number
        var factor = 1.0
        for var i = whole.count - 1; i >= 0; i--
        {
            res += Double(whole[i]) * factor
            factor *= 10
        }
        
        //mantissa
        if current != ascii.endIndex
        {
            factor = 0.1
            current = current.successor()
            while current != ascii.endIndex
            {
                res += Double(ascii[current] - zeroAscii) * factor
                factor *= 0.1
                current = current.successor()
            }
        }
        
        if (negative)
        {
            res *= -1;
        }
        
        return res
    }
    
    func dateValue() -> NSDate {
        let _dateFormatter = NSDateFormatter()
        _dateFormatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
        _dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.'SSSZZZZZ"
        
        let date = _dateFormatter.dateFromString(self)
        return date!
    }   
}

let intAmountFormatter = IntNumberFormatter()
let dateFormatter = getDateFormatter()
let dayFormatter = getDayFormatter()
let monthFormatter = getMonthFormatter()
let yearFormatter = getYearFormatter()
let mediumDateFormatter = getMediumDateFormatter()
let fullDateFormatter = getFullDateFormatter()

func IntNumberFormatter() -> NSNumberFormatter {
    let formatter =  NSNumberFormatter()
    formatter.numberStyle = NSNumberFormatterStyle.CurrencyStyle
    formatter.maximumFractionDigits = 0
    formatter.currencySymbol = ""
    
    return formatter
}

func getDateFormatter() -> NSDateFormatter {
    let format = NSDateFormatter.dateFormatFromTemplate("MMM d yyyy", options: 0, locale: NSLocale.currentLocale())
    let formatter = NSDateFormatter()
    formatter.dateFormat = format
    
    return formatter
}

func getDayFormatter() -> NSDateFormatter {
    let format = NSDateFormatter.dateFormatFromTemplate("MMM d", options: 0, locale: NSLocale.currentLocale())
    let formatter = NSDateFormatter()
    formatter.dateFormat = format
    
    return formatter
}

func getMonthFormatter() -> NSDateFormatter {
	let format = NSDateFormatter.dateFormatFromTemplate("MMM yyyy", options: 0, locale: NSLocale.currentLocale())
	let formatter = NSDateFormatter()
	formatter.dateFormat = format
	
	return formatter
}

func getYearFormatter() -> NSDateFormatter {
    let format = NSDateFormatter.dateFormatFromTemplate("yyyy", options: 0, locale: NSLocale.currentLocale())
    let formatter = NSDateFormatter()
    formatter.dateFormat = format
    
    return formatter
}

func getMediumDateFormatter() -> NSDateFormatter {
    let formatter = NSDateFormatter()
    formatter.dateStyle = NSDateFormatterStyle.MediumStyle
    
    return formatter
}

func delay(seconds:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(seconds * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

func getFullDateFormatter() -> NSDateFormatter {
    let _dateFormatter = NSDateFormatter()
    _dateFormatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
    _dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.'SSSZZZZZ"
    return _dateFormatter
}

func gregorianMonthForDate(monthDate:NSDate) -> (start:NSDate, end:NSDate) {
    let calendar = NSCalendar.currentCalendar()
    let year = calendar.components(NSCalendarUnit.Year, fromDate: monthDate).year
    let month = calendar.components(NSCalendarUnit.Month, fromDate: monthDate).month
    
    let components = NSDateComponents()
    components.year = year
    components.month = month
    components.day = 1
    
    let start = calendar.dateFromComponents(components)?.midnight()
    
    let days = calendar.rangeOfUnit(NSCalendarUnit.Day, inUnit: NSCalendarUnit.Month, forDate: start!)
    
    components.day = days.length
    let end = calendar.dateFromComponents(components)?.addDate(years: 0, months: 0, weeks: 0, days: 1).midnight()
    
    return (start!,end!)
}

extension NSDate {
    func stringValue() -> String {
        let strDate = fullDateFormatter.stringFromDate(self)
        return strDate
    }
    
    func mediumDateString() -> String {
        mediumDateFormatter.doesRelativeDateFormatting = false
        let strDate = mediumDateFormatter.stringFromDate(self)
        return strDate
    }
    
    func relativeDateString() -> String {
        mediumDateFormatter.doesRelativeDateFormatting = true
        let strDate = mediumDateFormatter.stringFromDate(self)
        return strDate
    }
    
    func relativeTimeFrom(date:NSDate) -> String {
        let interval = abs(self.timeIntervalSinceDate(date))
        if interval < 60 {
            return "less than a minute ago"
        }
        
        if interval < 3600 {
            return "\(floor(interval / 60)) minutes ago"
        }
        
        return "\(floor(interval / 60 / 60)) hours ago"
    }
    
    func addDate(years years:Int, months:Int, weeks: Int, days:Int) -> NSDate {
        let calendar = NSCalendar.currentCalendar()
        let components = NSDateComponents()
        components.year = years
        components.month = months
        components.weekOfYear = weeks
        components.day = days
        
        let nextDate = calendar.dateByAddingComponents(components, toDate: self, options: [])
        return nextDate!
    }
    
    func addTime(hours hours:Int, minutes:Int, seconds:Int) -> NSDate {
        let calendar = NSCalendar.currentCalendar()
        let components = NSDateComponents()
        components.hour = hours
        components.minute = minutes
        components.second = seconds
        
        let nextDate = calendar.dateByAddingComponents(components, toDate: self, options: [])
        return nextDate!
    }
    
    func midnight() -> NSDate {
        let calendar = NSCalendar.currentCalendar()
        let dateComponents = calendar.components([NSCalendarUnit.Year, NSCalendarUnit.Month, NSCalendarUnit.Day], fromDate: self)
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
    
        let midnight = calendar.dateFromComponents(dateComponents)!
        return midnight;
    }

    
    func calendarYear() -> Int {
        let calendar = NSCalendar.currentCalendar()
        let year = calendar.components(NSCalendarUnit.Year, fromDate: self).year
        
        return year
    }
}


class CommonFunctions {
	class func amountFromText(text:String) -> Int {
		let decimalSeparator = NSLocale.currentLocale().objectForKey(NSLocaleDecimalSeparator) as! String
        let groupingSeparator = NSLocale.currentLocale().objectForKey(NSLocaleGroupingSeparator) as! String
        
        var inputString = text
        
        // remove groupingSeparator from inputString
        let groupingInput = NSCharacterSet(charactersInString: groupingSeparator)
        var commaRange = inputString.rangeOfCharacterFromSet(groupingInput)
        
        while commaRange != nil {
            inputString = inputString.stringByReplacingCharactersInRange(commaRange!, withString: "")
            commaRange = inputString.rangeOfCharacterFromSet(groupingInput)
        }
        
        let invalidCharacters = NSCharacterSet(charactersInString: "0123456789\(decimalSeparator)-").invertedSet
		
		if inputString.rangeOfCharacterFromSet(invalidCharacters) != nil {
            return 0
        }
        
		let amountParts = inputString.componentsSeparatedByString(decimalSeparator)
		var amountValue = (amountParts[0] as NSString).integerValue*100
		if amountParts.count > 1 {
			var decimal = amountParts[1]
			if decimal.characters.count > 2 {
				decimal = (decimal as NSString).substringToIndex(2)
			}
			if decimal.characters.count == 1 {
				decimal += "0"
			}
			
			amountValue += (decimal as NSString).integerValue
		}
		
		return amountValue
	}
	
    class func formatForAmount(amount:Int, useThousandsSeparator:Bool = true) -> String {
		let decimalSeparator = NSLocale.currentLocale().objectForKey(NSLocaleDecimalSeparator) as! String
		let groupingSeparator = NSLocale.currentLocale().objectForKey(NSLocaleGroupingSeparator) as! String
		
		var amountString = "\(abs(amount))"
		
		var length = amountString.characters.count
		if length == 1 {
			amountString = "0"+amountString
			length = 2
		}
		var range = NSMakeRange(length-2,2)
		
		var formattedValue = decimalSeparator + (amountString as NSString).substringWithRange(range)
		if length > 2 {
			if !useThousandsSeparator {
				formattedValue = (amountString as NSString).substringToIndex(length-2)+formattedValue
			} else {
				amountString = (amountString as NSString).substringToIndex(length-2)
				length = amountString.characters.count
				while length > 0 {
					if length > 3 {
						range = NSMakeRange(length-3,3)
						formattedValue = groupingSeparator+(amountString as NSString).substringWithRange(range)+formattedValue
						amountString = (amountString as NSString).substringToIndex(length-3)
					} else {
						formattedValue = amountString + formattedValue
						amountString = ""
					}
					
					length = amountString.characters.count
				}
			}
		} else {
			formattedValue = "0"+formattedValue
		}
		
		if amount < 0 {
			formattedValue = "-"+formattedValue
		}
		
        return formattedValue
    }
    
    class func intFormatForAmount(amount:Int, useThousandsSeparator:Bool = true) -> String {
		let groupingSeparator = NSLocale.currentLocale().objectForKey(NSLocaleGroupingSeparator) as! String
		
		var amountString = "\(abs(amount))"
		
		var length = amountString.characters.count
		if length == 1 {
			amountString = "0"+amountString
			length = 2
		}
		var range = NSMakeRange(length-2,2)
		
		var formattedValue = ""
		if length > 2 {
			if !useThousandsSeparator {
				formattedValue = (amountString as NSString).substringToIndex(length-2)+formattedValue
			} else {
				amountString = (amountString as NSString).substringToIndex(length-2)
				length = amountString.characters.count
				while length > 0 {
					if length > 3 {
						range = NSMakeRange(length-3,3)
						formattedValue = groupingSeparator+(amountString as NSString).substringWithRange(range)+formattedValue
						amountString = (amountString as NSString).substringToIndex(length-3)
					} else {
						formattedValue = amountString + formattedValue
						amountString = ""
					}
					
					length = amountString.characters.count
				}
			}

            if amount < 0 {
                formattedValue = "-"+formattedValue
            }
        } else {
            formattedValue = "0"
        }
				
		
		return formattedValue
	}
	
	class func formatInteger(amount:Int, useThousandsSeparator:Bool = true) -> String {
		return intAmountFormatter.stringFromNumber(amount)!
	}
	
    class func totalAmountAvailable()->Int {
        let defaults = NSUserDefaults.standardUserDefaults()
        let amountAvailable = defaults.integerForKey(kAmountAvailableKey)
        return amountAvailable
    }
    
    class var currentAccountKey:String {
        get {
            let cf = CommonFunctions.sharedInstance
            if cf._currentAccountKey == nil {
                let defaults = NSUserDefaults.standardUserDefaults()
                var defaultAccount = defaults.stringForKey(kDefaultAccount)
                
                if defaultAccount == nil || !ALBNoSQLDB.tableHasKey(table: kAccountsTable, key: defaultAccount!)! {
                    if let keys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder:nil) where keys.filter({$0 == defaultAccount}).count == 0 {
                        // assign first in list
                        defaultAccount = keys[0]
                        defaults.setObject(defaultAccount, forKey: kDefaultAccount)
                        NSUserDefaults.resetStandardUserDefaults()
                    }
                }
                
                cf._currentAccountKey = defaultAccount!
            }
            
            return cf._currentAccountKey!
        }
        
        set(accountKey) {
            let cf = CommonFunctions.sharedInstance
            if accountKey != cf._currentAccountKey {
                cf._currentAccountKey = accountKey
                let defaults = NSUserDefaults.standardUserDefaults()
                defaults.setObject(accountKey, forKey: kDefaultAccount)
                NSUserDefaults.resetStandardUserDefaults()
            }
        }
    }
    
    class var sharedInstance : CommonFunctions {
        struct Static {
            static let instance = CommonFunctions()
        }
        return Static.instance
    }

    
    var _currentAccountKey:String?
}