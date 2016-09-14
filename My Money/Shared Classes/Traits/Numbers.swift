//
//  Numbers.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 3/12/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation
protocol UsesCurrency {
}

extension UsesCurrency {
	func amountFromText(_ text: String) -> Int {
		let decimalSeparator = NSLocale.current.decimalSeparator!
		let groupingSeparator = NSLocale.current.groupingSeparator!

		var inputString = text
		var negative = false

		// remove groupingSeparator from inputString
		let groupingInput = CharacterSet(charactersIn: groupingSeparator)
		var commaRange = inputString.rangeOfCharacter(from: groupingInput)

		while commaRange != nil {
			inputString = inputString.replacingCharacters(in: commaRange!, with: "")
			commaRange = inputString.rangeOfCharacter(from: groupingInput)
		}

		let invalidCharacters = CharacterSet(charactersIn: "0123456789\(decimalSeparator)-").inverted

		if inputString.rangeOfCharacter(from: invalidCharacters) != nil {
			return 0
		}

		let amountParts = inputString.components(separatedBy: decimalSeparator)
		var amountValue = (amountParts[0] as NSString).integerValue * 100
		if amountValue < 0 {
			amountValue *= -1
			negative = true
		}

		if amountParts.count > 1 {
			var decimal = amountParts[1]
			if decimal.characters.count > 2 {
				decimal = (decimal as NSString).substring(to: 2)
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

	func formatForAmount(_ amount: Int, useThousandsSeparator: Bool = true) -> String {
		let decimalSeparator = NSLocale.current.decimalSeparator!
		let groupingSeparator = NSLocale.current.groupingSeparator!

		var amountString = "\(abs(amount))"

		var length = amountString.characters.count
		if length == 1 {
			amountString = "0" + amountString
			length = 2
		}
		var range = NSMakeRange(length - 2, 2)

		var formattedValue = decimalSeparator + (amountString as NSString).substring(with: range)
		if length > 2 {
			if !useThousandsSeparator {
				formattedValue = (amountString as NSString).substring(to: length - 2) + formattedValue
			} else {
				amountString = (amountString as NSString).substring(to: length - 2)
				length = amountString.characters.count
				while length > 0 {
					if length > 3 {
						range = NSMakeRange(length - 3, 3)
						formattedValue = groupingSeparator + (amountString as NSString).substring(with: range) + formattedValue
						amountString = (amountString as NSString).substring(to: length - 3)
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

	func intFormatForAmount(_ amount: Int, useThousandsSeparator: Bool = true) -> String {
		let groupingSeparator = NSLocale.current.groupingSeparator!

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
				formattedValue = (amountString as NSString).substring(to: length - 2) + formattedValue
			} else {
				amountString = (amountString as NSString).substring(to: length - 2)
				length = amountString.characters.count
				while length > 0 {
					if length > 3 {
						range = NSMakeRange(length - 3, 3)
						formattedValue = groupingSeparator + (amountString as NSString).substring(with: range) + formattedValue
						amountString = (amountString as NSString).substring(to: length - 3)
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

	func formatInteger(_ amount: Int, useThousandsSeparator: Bool = true) -> String {
		return intAmountFormatter.string(from: NSNumber(value: amount))!
	}

	private var intAmountFormatter: NumberFormatter {
		let formatter = NumberFormatter()
		formatter.numberStyle = NumberFormatter.Style.currency
		formatter.maximumFractionDigits = 0
		formatter.currencySymbol = ""

		return formatter
	}
}
