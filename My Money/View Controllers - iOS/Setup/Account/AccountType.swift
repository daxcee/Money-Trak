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
	
	override func viewWillAppear(_ animated: Bool) {
		selectCell()
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch (indexPath as NSIndexPath).row {
		case 0:
			type = .checking
		case 1:
			type = .savings
		case 2:
			type = .cash
		default:
			type = .creditCard
		}
		
		tableView.deselectRow(at: indexPath, animated: true)
		selectCell()
		delegate?.accountTypeSelected(type)
	}
	
	func selectCell() {
		checkingCell.accessoryType = (type == .checking ? .checkmark : .none)
		savingsCell.accessoryType = (type == .savings ? .checkmark : .none)
		cashCell.accessoryType = (type == .cash ? .checkmark : .none)
		ccCell.accessoryType = (type == .creditCard ? .checkmark : .none)
	}
}
