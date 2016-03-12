//
//  Numbers.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 3/12/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation
protocol Numbers {
}

extension Numbers {
	func amountFromText(text: String) -> Int {
		let decimalSeparator = NSLocale.currentLocale().objectForKey(NSLocaleDecimalSeparator) as! String
		let groupingSeparator = NSLocale.currentLocale().objectForKey(NSLocaleGroupingSeparator) as! String

		var inputString = text
		var negative = false

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
		var amountValue = (amountParts[0] as NSString).integerValue * 100
		if amountValue < 0 {
			amountValue *= -1
			negative = true
		}

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

		if negative {
			amountValue *= -1
		}

		return amountValue
	}

	func formatForAmount(amount: Int, useThousandsSeparator: Bool = true) -> String {
		let decimalSeparator = NSLocale.currentLocale().objectForKey(NSLocaleDecimalSeparator) as! String
		let groupingSeparator = NSLocale.currentLocale().objectForKey(NSLocaleGroupingSeparator) as! String

		var amountString = "\(abs(amount))"

		var length = amountString.characters.count
		if length == 1 {
			amountString = "0" + amountString
			length = 2
		}
		var range = NSMakeRange(length - 2, 2)

		var formattedValue = decimalSeparator + (amountString as NSString).substringWithRange(range)
		if length > 2 {
			if !useThousandsSeparator {
				formattedValue = (amountString as NSString).substringToIndex(length - 2) + formattedValue
			} else {
				amountString = (amountString as NSString).substringToIndex(length - 2)
				length = amountString.characters.count
				while length > 0 {
					if length > 3 {
						range = NSMakeRange(length - 3, 3)
						formattedValue = groupingSeparator + (amountString as NSString).substringWithRange(range) + formattedValue
						amountString = (amountString as NSString).substringToIndex(length - 3)
					} else {
						formattedValue = amountString + formattedValue
						amountString = ""
					}

					length = amountString.characters.count
				}
			}
		} else {
			formattedValue = "0" + formattedValue
		}

		if amount < 0 {
			formattedValue = "-" + formattedValue
		}

		return formattedValue
	}

	func intFormatForAmount(amount: Int, useThousandsSeparator: Bool = true) -> String {
		let groupingSeparator = NSLocale.currentLocale().objectForKey(NSLocaleGroupingSeparator) as! String

		var amountString = "\(abs(amount))"

		var length = amountString.characters.count
		if length == 1 {
			amountString = "0" + amountString
			length = 2
		}
		var range = NSMakeRange(length - 2, 2)

		var formattedValue = ""
		if length > 2 {
			if !useThousandsSeparator {
				formattedValue = (amountString as NSString).substringToIndex(length - 2) + formattedValue
			} else {
				amountString = (amountString as NSString).substringToIndex(length - 2)
				length = amountString.characters.count
				while length > 0 {
					if length > 3 {
						range = NSMakeRange(length - 3, 3)
						formattedValue = groupingSeparator + (amountString as NSString).substringWithRange(range) + formattedValue
						amountString = (amountString as NSString).substringToIndex(length - 3)
					} else {
						formattedValue = amountString + formattedValue
						amountString = ""
					}

					length = amountString.characters.count
				}
			}

			if amount < 0 {
				formattedValue = "-" + formattedValue
			}
		} else {
			formattedValue = "0"
		}

		return formattedValue
	}

	func formatInteger(amount: Int, useThousandsSeparator: Bool = true) -> String {
		return intAmountFormatter.stringFromNumber(amount)!
	}

	private var intAmountFormatter: NSNumberFormatter {
		let formatter = NSNumberFormatter()
		formatter.numberStyle = NSNumberFormatterStyle.CurrencyStyle
		formatter.maximumFractionDigits = 0
		formatter.currencySymbol = ""

		return formatter
	}
}