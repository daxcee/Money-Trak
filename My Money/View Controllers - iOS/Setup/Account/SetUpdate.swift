//
//  SetUpdate.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/05/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol UpdateAllDelegate {
	func updateAllTransactions(updateAll: Bool)
}

class SetUpdateController: UIViewController, UITableViewDelegate, UITableViewDataSource, UpdateAllDelegate {
	@IBOutlet weak var tableView: UITableView!
	
	var helper: TableViewHelper?
	var delegate: UpdateDelegate?
	var account: Account?
	
	override func viewDidLoad() {
		helper = TableViewHelper(tableView: tableView!)
		helper!.addCell(0, cell: tableView.dequeueReusableCellWithIdentifier("All")!, name: "All")
		helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier("StopOnDeposit")!, name: "StopOnDeposit")
		helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier("UpcomingDays")!, name: "UpcomingDays")
		
		let cell = helper!.visibleCellsWithName("All") [0] as! UpdateAllCell
		cell.updateSwitch.on = account!.updateTotalAll
		cell.delegate = self
		
		let dayCell = helper!.visibleCellsWithName("UpcomingDays") [0] as! UpcomingDaysCell
		dayCell.account = account
		dayCell.slider.value = Float(account!.updateUpcomingDays)
		dayCell.days.text = "\(account!.updateUpcomingDays)"
		
		let stopCell = helper!.visibleCellsWithName("StopOnDeposit") [0] as! StopOnDepositCell
		stopCell.account = account
		stopCell.stopSwitch.on = account!.stopUpdatingAtDeposit
		
		updateAllTransactions(account!.updateTotalAll)
	}
	
	override func viewDidDisappear(animated: Bool) {
		delegate?.updateTotalSelected()
		super.viewDidDisappear(animated)
	}
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return helper!.numberOfSections()
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return helper!.numberOfRowsInSection(section)
	}
	
	func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 1:
			return "Upcoming Transactions"
		default:
			return "Transactions"
		}
	}
	
	func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 1 {
			return "Select maximum number of days that are to be considered for upcoming purchases."
		}
		
		return nil
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = helper!.cellForRowAtIndexPath(indexPath)
		
		
		return cell
	}
	
	
	func updateAllTransactions(updateAll: Bool) {
		account!.updateTotalAll = updateAll
		
		if updateAll {
			helper!.showCell("UpcomingDays")
		} else {
			helper!.hideCell("UpcomingDays")
		}
	}
}


class UpdateAllCell: UITableViewCell {
	@IBOutlet weak var updateSwitch: UISwitch!
	var delegate: UpdateAllDelegate?
	
	@IBAction func valueChanged(sender: AnyObject) {
		delegate?.updateAllTransactions(updateSwitch.on)
	}
}

class UpcomingDaysCell: UITableViewCell {
	var account: Account?
	@IBOutlet weak var slider: UISlider!
	@IBOutlet weak var days: UILabel!
	
	
	@IBAction func valueChanged(sender: AnyObject) {
		account!.updateUpcomingDays = Int(slider.value)
		days.text = "\(account!.updateUpcomingDays)"
	}
}

class StopOnDepositCell: UITableViewCell {
	var account: Account?
	@IBOutlet weak var stopSwitch: UISwitch!
	
	
	@IBAction func valueChanged(sender: AnyObject) {
		account!.stopUpdatingAtDeposit = stopSwitch.on
	}
	
	
}