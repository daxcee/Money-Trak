//
//  NSDateExtensions.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 3/26/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation

let dateFormatter = getDateFormatter()
let dayFormatter = getDayFormatter()
let monthFormatter = getMonthFormatter()
let yearFormatter = getYearFormatter()
let mediumDateFormatter = getMediumDateFormatter()
let fullDateFormatter = getFullDateFormatter()

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

func getFullDateFormatter() -> NSDateFormatter {
	let _dateFormatter = NSDateFormatter()
	_dateFormatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
	_dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.'SSSZZZZZ"
	return _dateFormatter
}

func gregorianMonthForDate(monthDate: NSDate) -> (start: NSDate, end: NSDate) {
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

	return (start!, end!)
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

	func relativeTimeFrom(date: NSDate) -> String {
		let interval = abs(self.timeIntervalSinceDate(date))
		if interval < 60 {
			return "less than a minute ago"
		}

		if interval < 3600 {
			return "\(floor(interval / 60)) minutes ago"
		}

		return "\(floor(interval / 60 / 60)) hours ago"
	}

	func addDate(years years: Int, months: Int, weeks: Int, days: Int) -> NSDate {
		let calendar = NSCalendar.currentCalendar()
		let components = NSDateComponents()
		components.year = years
		components.month = months
		components.weekOfYear = weeks
		components.day = days

		let nextDate = calendar.dateByAddingComponents(components, toDate: self, options: [])
		return nextDate!
	}

	func addTime(hours hours: Int, minutes: Int, seconds: Int) -> NSDate {
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
