//
//  AccountType.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/05/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class AccountTypeController: UITableViewController {
	@IBOutlet weak var checkingCell: UITableViewCell!
	@IBOutlet weak var savingsCell: UITableViewCell!
	@IBOutlet weak var cashCell: UITableViewCell!
	@IBOutlet weak var ccCell: UITableViewCell!
	
	var type = AccountType.checking
	var delegate: AccountTypeDelegate?
	
	override func viewWillAppear(animated: Bool) {
		selectCell()
	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		switch indexPath.row {
		case 0:
			type = .checking
		case 1:
			type = .savings
		case 2:
			type = .cash
		default:
			type = .creditCard
		}
		
		tableView.deselectRowAtIndexPath(indexPath, animated: true)
		selectCell()
		delegate?.accountTypeSelected(type)
	}
	
	func selectCell() {
		checkingCell.accessoryType = (type == .checking ? .Checkmark : .None)
		savingsCell.accessoryType = (type == .savings ? .Checkmark : .None)
		cashCell.accessoryType = (type == .cash ? .Checkmark : .None)
		ccCell.accessoryType = (type == .creditCard ? .Checkmark : .None)
	}
}
