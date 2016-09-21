//
//  SetUpdate.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/05/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import TableViewHelper

protocol UpdateAllDelegate {
	func updateAllTransactions(_ updateAll: Bool)
}

class SetUpdateController: UIViewController, UITableViewDelegate, UITableViewDataSource, UpdateAllDelegate {
	@IBOutlet weak var tableView: UITableView!
	
	var delegate: UpdateDelegate?
	var account: Account?
	fileprivate var _helper: TableViewHelper!
	
	override func viewDidLoad() {
		_helper = TableViewHelper(tableView: tableView!)
		_helper.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "All")!, name: "All")
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "StopOnDeposit")!, name: "StopOnDeposit")
		_helper.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "UpcomingDays")!, name: "UpcomingDays")
		
		let cell = _helper.visibleCellsWithName("All") [0] as! UpdateAllCell
		cell.updateSwitch.isOn = account!.updateTotalAll
		cell.delegate = self
		
		let dayCell = _helper.visibleCellsWithName("UpcomingDays") [0] as! UpcomingDaysCell
		dayCell.account = account
		dayCell.slider.value = Float(account!.updateUpcomingDays)
		dayCell.days.text = "\(account!.updateUpcomingDays)"
		
		let stopCell = _helper.visibleCellsWithName("StopOnDeposit") [0] as! StopOnDepositCell
		stopCell.account = account
		stopCell.stopSwitch.isOn = account!.stopUpdatingAtDeposit
		
		updateAllTransactions(account!.updateTotalAll)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		delegate?.updateTotalSelected()
		super.viewDidDisappear(animated)
	}
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return _helper.numberOfSections()
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return _helper.numberOfRowsInSection(section)
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 1:
			return "Upcoming Transactions"
		default:
			return "Transactions"
		}
	}
	
	func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 1 {
			return "Select maximum number of days that are to be considered for upcoming purchases."
		}
		
		return nil
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = _helper.cellForRowAtIndexPath(indexPath)
		
		
		return cell
	}
	
	
	func updateAllTransactions(_ updateAll: Bool) {
		account!.updateTotalAll = updateAll
		
		if updateAll {
			_helper.showCell("UpcomingDays")
		} else {
			_helper.hideCell("UpcomingDays")
		}
	}
}


class UpdateAllCell: UITableViewCell {
	@IBOutlet weak var updateSwitch: UISwitch!
	var delegate: UpdateAllDelegate?
	
	@IBAction func valueChanged(_ sender: AnyObject) {
		delegate?.updateAllTransactions(updateSwitch.isOn)
	}
}

class UpcomingDaysCell: UITableViewCell {
	var account: Account?
	@IBOutlet weak var slider: UISlider!
	@IBOutlet weak var days: UILabel!
	
	
	@IBAction func valueChanged(_ sender: AnyObject) {
		account!.updateUpcomingDays = Int(slider.value)
		days.text = "\(account!.updateUpcomingDays)"
	}
}

class StopOnDepositCell: UITableViewCell {
	var account: Account?
	@IBOutlet weak var stopSwitch: UISwitch!
	
	
	@IBAction func valueChanged(_ sender: AnyObject) {
		account!.stopUpdatingAtDeposit = stopSwitch.isOn
	}
	
	
}
