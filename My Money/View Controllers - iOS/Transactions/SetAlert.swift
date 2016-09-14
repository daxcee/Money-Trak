//
//  File.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/04/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol AlertDelegate {
	func alertSet()
}

class AlertController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	@IBOutlet weak var tableView: UITableView!
	
	var transaction = UpcomingTransaction()
	var helper: TableViewHelper?
	var delegate: AlertDelegate?
	
	override func viewDidLoad() {
		helper = TableViewHelper(tableView: tableView!)
		helper!.addCell(0, cell: tableView.dequeueReusableCell(withIdentifier: "None")!, name: "None")
		helper!.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "1d")!, name: "1d")
		helper!.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "2d")!, name: "2d")
		helper!.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "1w")!, name: "1w")
		helper!.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "2w")!, name: "2w")
		helper!.addCell(1, cell: tableView.dequeueReusableCell(withIdentifier: "1m")!, name: "1m")
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		if let delegate = delegate {
			delegate.alertSet()
		}
	}
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return (section == 0 ? 1 : 5)
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let name = helper!.cellNameAtIndexPath(indexPath)!
		let cell = helper!.cellForRowAtIndexPath(indexPath)
		var checkmark = false
		switch name {
		case "None":
			if transaction.alerts == nil {
				checkmark = true
			}
		default:
			if let alerts = transaction.alerts {
				if alerts.contains(name) {
					checkmark = true
				}
			}
		}
		
		cell.accessoryType = (checkmark ? .checkmark : .none)
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if (indexPath as NSIndexPath).section == 0 {
			transaction.alerts = nil
		} else {
			if transaction.alerts == nil {
				transaction.alerts = []
			}
			
			var identifier = ""
			switch (indexPath as NSIndexPath).row {
			case 0:
				identifier = "1d"
			case 1:
				identifier = "2d"
			case 2:
				identifier = "1w"
			case 3:
				identifier = "2w"
			case 4:
				identifier = "1m"
			default:
				break
			}
			
			var alerts = transaction.alerts!
			
			if alerts.contains(identifier) {
				alerts = alerts.filter({$0 != identifier})
			} else {
				alerts.append(identifier)
			}
			
			if alerts.count == 0 {
				transaction.alerts = nil
			} else {
				transaction.alerts = alerts
			}
		}
		
		tableView.reloadData()
	}
}
