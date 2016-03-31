//
//  StringExtensions.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 3/26/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation

extension String {
	func doubleValue() -> Double {
		let minusAscii: UInt8 = 45
		let dotAscii: UInt8 = 46
		let zeroAscii: UInt8 = 48

		var res = 0.0
		let ascii = self.utf8

		var whole = [Double]()
		var current = ascii.startIndex

		let negative = current != ascii.endIndex && ascii[current] == minusAscii
		if (negative) {
			current = current.successor()
		}

		while current != ascii.endIndex && ascii[current] != dotAscii {
			whole.append(Double(ascii[current] - zeroAscii))
			current = current.successor()
		}

		// whole number
		var factor = 1.0
		for i in(1 ..< whole.count).reverse() {
			res += Double(whole[i]) * factor
			factor *= 10
		}

		// mantissa
		if current != ascii.endIndex {
			factor = 0.1
			current = current.successor()
			while current != ascii.endIndex
			{
				res += Double(ascii[current] - zeroAscii) * factor
				factor *= 0.1
				current = current.successor()
			}
		}

		if (negative) {
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
