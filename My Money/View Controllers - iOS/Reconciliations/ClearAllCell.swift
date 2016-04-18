//
//  ClearAllCell.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 4/16/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol ClearAllProtocol: class {
	func clearAllTapped()
}

class ClearAllCell: UITableViewCell, Reusable {
	@IBOutlet weak var clearButton: UIButton!

	weak var delegate: ClearAllProtocol?

	@IBAction func clearTapped(sender: AnyObject) {
		delegate?.clearAllTapped()
	}
}