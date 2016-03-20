//
//  UIImage.swift
//  DigitalLifeUI
//
//  Created by Aaron Bratcher on 2/4/16.
//  Copyright © 2016 AT&T. All rights reserved.
//

import XCTest
import UIKit

class UIImageTests: XCTestCase {
	func testImagesLoad() {
		let identifiers = UIImage.ImageIdentifier.allIdentifiers

		for identifier in UIImage.ImageIdentifier.allIdentifiers {
			let image = UIImage(named: identifier.rawValue)
			XCTAssert(image != nil, "image doesn't exist")
		}
	}
}
