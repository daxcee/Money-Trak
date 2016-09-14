//
//  AmountField.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/23/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class AmountField: UITextField, UITextFieldDelegate, UsesCurrency {
	override init(frame: CGRect) {
		super.init(frame: frame)
		delegate = self
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		delegate = self
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		if let text = textField.text {
			let newString = NSString(string: text).replacingCharacters(in: range, with: string)
			let expression = "^([0-9]+)?(\\.([0-9]{1,2})?)?$"
			let regex = try? NSRegularExpression(pattern: expression, options: NSRegularExpression.Options.caseInsensitive)
			let numberOfMatches = regex?.numberOfMatches(in: newString, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, newString.characters.count))

			if numberOfMatches == 0 {
				return false
			}
		}

		return true
	}

	func amount() -> Int {
		guard let text = self.text else { return 0 }

		return amountFromText(text)
	}
}
