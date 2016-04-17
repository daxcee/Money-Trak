//
//  Segues.swift
//  DigitalLifeUI
//
//  Created by Aaron Bratcher on 3/16/16.
//  Copyright © 2016 AT&T. All rights reserved.
//

import Foundation

protocol Segues {
	associatedtype SegueIdentifier: RawRepresentable
}

extension Segues where Self: UIViewController, SegueIdentifier.RawValue == String {
	func performSegueWithIdentifier(segueIdentifier: SegueIdentifier, sender: AnyObject?) {
		performSegueWithIdentifier(segueIdentifier.rawValue, sender: sender)
	}

	func segueIdentifierForSegue(segue: UIStoryboardSegue) -> SegueIdentifier {
		guard let identifier = segue.identifier, segueIdentifier = SegueIdentifier(rawValue: identifier) else { fatalError("Invalid segue identifier \(segue.identifier).") }

		return segueIdentifier
	}
}