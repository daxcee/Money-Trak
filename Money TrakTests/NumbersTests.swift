//
//  My_MoneyTests.swift
//  My MoneyTests
//
//  Created by Aaron Bratcher on 08/07/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import UIKit
import XCTest

class My_MoneyTests: XCTestCase, Numbers {

	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}

	func testAmountDisplay() {
		var amount = 1
		var testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "0.01", "Penny")

		amount = 10
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "0.10", "Dime")

		amount = 100
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "1.00", "Dollar")

		amount = 10000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "100.00", "Hundred Dollars")

		amount = 100000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "1000.00", "Thousand Dollars")

		amount = 1000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "10000.00", "Ten Thousand Dollars")

		amount = 10000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "100000.00", "Hundred Thousand Dollars")

		amount = 100000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "1000000.00", "1 Million Dollars")

		amount = 1000000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "10000000.00", "10 Million Dollars")

		amount = 10000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "100.00", "Hundred Dollars")

		amount = 100000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "1,000.00", "Thousand Dollars")

		amount = 1000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "10,000.00", "Ten Thousand Dollars")

		amount = 10000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "100,000.00", "Hundred Thousand Dollars")

		amount = 100000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "1,000,000.00", "1 Million Dollars")

		amount = 1000000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "10,000,000.00", "10 Million Dollars")
	}

	func testNegativeAmountDisplay() {
		var amount = -1
		var testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-0.01", "Penny")

		amount = -10
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-0.10", "Dime")

		amount = -100
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-1.00", "Dollar")

		amount = -10000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-100.00", "Hundred Dollars")

		amount = -100000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-1000.00", "Thousand Dollars")

		amount = -1000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-10000.00", "Ten Thousand Dollars")

		amount = -10000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-100000.00", "Hundred Thousand Dollars")

		amount = -100000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-1000000.00", "1 Million Dollars")

		amount = -1000000000
		testString = formatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-10000000.00", "10 Million Dollars")

		amount = -10000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-100.00", "Hundred Dollars")

		amount = -100000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-1,000.00", "Thousand Dollars")

		amount = -1000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-10,000.00", "Ten Thousand Dollars")

		amount = -10000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-100,000.00", "Hundred Thousand Dollars")

		amount = -100000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-1,000,000.00", "1 Million Dollars")

		amount = -1000000000
		testString = formatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-10,000,000.00", "10 Million Dollars")
	}

	func testAmountFromText() {
		var input = ".01"
		var testValue = amountFromText(input)
		XCTAssert(testValue == 1, ".01")

		input = ".011"
		testValue = amountFromText(input)
		XCTAssert(testValue == 1, ".011")

		input = ".1"
		testValue = amountFromText(input)
		XCTAssert(testValue == 10, ".1")

		input = "1"
		testValue = amountFromText(input)
		XCTAssert(testValue == 100, "1")

		input = "1.1"
		testValue = amountFromText(input)
		XCTAssert(testValue == 110, "1.1")

		input = "23.14"
		testValue = amountFromText(input)
		XCTAssert(testValue == 2314, "23.14")

		input = "-23.14"
		testValue = amountFromText(input)
		XCTAssert(testValue == -2314, "-23.14")
	}

	func testAmountFromString() {
		var input = "test"
		var testValue = amountFromText(input)
		XCTAssert(testValue == 0, input)

		input = "01test"
		testValue = amountFromText(input)
		XCTAssert(testValue == 0, "results:\(testValue)")

		input = "test.01"
		testValue = amountFromText(input)
		XCTAssert(testValue == 0, "results:\(testValue)")

		input = ".01t"
		testValue = amountFromText(input)
		XCTAssert(testValue == 0, "results:\(testValue)")
	}

	func testIntAmountDisplay() {
		var amount = 1
		var testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "0", "Penny")

		amount = 10
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "0", "Dime")

		amount = 100
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "1", "Dollar")

		amount = 10000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "100", "Hundred Dollars")

		amount = 100000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "1000", "Thousand Dollars")

		amount = 1000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "10000", "Ten Thousand Dollars")

		amount = 10000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "100000", "Hundred Thousand Dollars")

		amount = 100000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "1000000", "1 Million Dollars")

		amount = 1000000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "10000000", "10 Million Dollars")

		amount = 10000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "100", "Hundred Dollars")

		amount = 100000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "1,000", "Thousand Dollars")

		amount = 1000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "10,000", "Ten Thousand Dollars")

		amount = 10000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "100,000", "Hundred Thousand Dollars")

		amount = 100000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "1,000,000", "1 Million Dollars")

		amount = 1000000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "10,000,000", "10 Million Dollars")
	}

	func testIntNegativeAmountDisplay() {
		var amount = -1
		var testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "0", "Penny")

		amount = 1 - 0
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "0", "Dime")

		amount = -100
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-1", "Dollar")

		amount = -10000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-100", "Hundred Dollars")

		amount = -100000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-1000", "Thousand Dollars")

		amount = -1000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-10000", "Ten Thousand Dollars")

		amount = -10000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-100000", "Hundred Thousand Dollars")

		amount = -100000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-1000000", "1 Million Dollars")

		amount = -1000000000
		testString = intFormatForAmount(amount, useThousandsSeparator: false)
		XCTAssert(testString == "-10000000", "10 Million Dollars")

		amount = -10000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-100", "Hundred Dollars")

		amount = -100000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-1,000", "Thousand Dollars")

		amount = -1000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-10,000", "Ten Thousand Dollars")

		amount = -10000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-100,000", "Hundred Thousand Dollars")

		amount = -100000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-1,000,000", "1 Million Dollars")

		amount = -1000000000
		testString = intFormatForAmount(amount, useThousandsSeparator: true)
		XCTAssert(testString == "-10,000,000", "10 Million Dollars")
	}
}
