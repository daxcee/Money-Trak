//
//  UIImage.swift
//  DigitalLifeUI
//
//  Created by Aaron Bratcher on 1/29/16.
//  Copyright © 2016 AT&T. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
	public enum ImageIdentifier: String {
		// when adding identifiers, add a case, and add to the allIdentifiers variable

		case Negative

		static let allIdentifiers = [
			Negative
		]
	}

	convenience init!(imageIdentifier: ImageIdentifier) {
		self.init(named: imageIdentifier.rawValue)
	}

	convenience init!(imageName: String) {
		guard let imageIdentifier = UIImage.ImageIdentifier(rawValue: imageName) else { fatalError("Unknown image name") }

		self.init(imageIdentifier: imageIdentifier)
	}
}