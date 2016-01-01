//
//  Setup.swift
//  My Money
//
//  Created by Aaron Bratcher on 11/11/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class SetupViewController: UITableViewController {
	@IBAction func doneTapped(sender: AnyObject) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func recalcTapped(sender: AnyObject) {
		CommonDB.recalculateAllBalances()
	}
}