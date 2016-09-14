//
//  StringExtensions.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 3/26/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation

extension String {
	func dateValue() -> Date {
		let _dateFormatter = DateFormatter()
		_dateFormatter.calendar = Calendar(identifier:.gregorian)
		_dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.'SSSZZZZZ"

		let date = _dateFormatter.date(from: self)
		return date!
	}
}
