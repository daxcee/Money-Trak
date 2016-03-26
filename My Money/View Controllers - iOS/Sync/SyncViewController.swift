//
//  SyncViewController.swift
//  My Money
//
//  Created by Aaron Bratcher on 4/13/15.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol SyncDeviceCellDelegate {
	func linkTappedForDevice(device: SyncDevice)
}

class SyncViewController: UITableViewController, UIAlertViewDelegate {
	var syncEngine: SyncEngine?
	var unlinkDevice: SyncDevice?
	var nearbyDevices = [SyncDevice]()
	var offlineDevices = [SyncDevice]()

	enum CellType: String {
		case UnknownCell = "UnknownCell"
		case KnownCell = "KnownCell"
		case EnableSyncCell = "EnableSyncCell"
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillDisappear(animated)
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		syncEngine = appDelegate.syncEngine
		if let syncEngine = syncEngine {
			syncEngine.stopBonjour()
			syncEngine.startBonjour()
			syncEngine.delegate = self

			nearbyDevices = syncEngine.nearbyDevices
			offlineDevices = syncEngine.offlineDevices
		}
	}

	override func viewWillDisappear(animated: Bool) {
		syncEngine?.delegate = nil
	}

	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		var sections = 1

		if offlineDevices.count > 0 {
			sections = 2
		}

		return sections
	}

	override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return "Nearby Devices"
		case 1:
			return "Offline Devices"
		default:
			return nil
		}
	}

	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if syncEngine != nil {
			switch section {

			case 0:
				return nearbyDevices.count
			case 1:
				return offlineDevices.count
			default:
				return 1
			}
		}

		return 0
	}

	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		var cell = UITableViewCell()
		var device: SyncDevice

		switch indexPath.section {
		case 0:
			device = nearbyDevices[indexPath.row]
			if device.linked {
				let knownCell = tableView.dequeueReusableCellWithIdentifier(CellType.KnownCell.rawValue) as! KnownDeviceCell
				knownCell.device = device
				knownCell.delegate = self
				cell = knownCell
			} else {
				let unknownCell = tableView.dequeueReusableCellWithIdentifier(CellType.UnknownCell.rawValue) as! UnknownDeviceCell
				unknownCell.device = device
				unknownCell.delegate = self
				cell = unknownCell
			}

		default:
			device = offlineDevices[indexPath.row]
			let offlineCell = tableView.dequeueReusableCellWithIdentifier(CellType.KnownCell.rawValue) as! KnownDeviceCell
			offlineCell.device = device
			offlineCell.delegate = self
			cell = offlineCell
		}

		return cell
	}

	override func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
		return "Unlink"
	}

	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		if indexPath.section == 0 {
			let device = nearbyDevices[indexPath.row]
			return device.linked
		}

		return true
	}

	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == UITableViewCellEditingStyle.Delete {
			let device: SyncDevice
			if indexPath.section == 0 {
				device = nearbyDevices[indexPath.row]
			} else {
				device = offlineDevices[indexPath.row]
			}

			unlinkDevice(device)
		}
	}

	@IBAction func doneTapped(sender: AnyObject) {
		dismissViewControllerAnimated(true, completion: nil)
	}
}

//MARK: - Sync Cell Delegate
extension SyncViewController: SyncDeviceCellDelegate {

	func linkTappedForDevice(device: SyncDevice) {
		syncEngine?.linkDevice(device)
	}

	func unlinkDevice(device: SyncDevice) {
		unlinkDevice = device
		let alert = UIAlertView(title: "Unlink", message: "Unlink from \(device.name)?", delegate: self, cancelButtonTitle: "No", otherButtonTitles: "Unlink")
		alert.show()
	}

	func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
		tableView.setEditing(false, animated: true)

		if let device = unlinkDevice {
			if buttonIndex == 1 {
				syncEngine?.forgetDevice(device)
				tableView.reloadData()
			}
		}
	}

	func syncTappedForDevice(device: SyncDevice) {
		syncEngine?.syncWithDevice(device)
	}
}

//MARK: - Snyc Engine Delegate
extension SyncViewController: SyncEngineDelegate {
	func statusChanged(device: SyncDevice) {
		if offlineDevices.filter({ $0.key == device.key }).count > 0 {
			if let syncEngine = syncEngine {
				nearbyDevices = syncEngine.nearbyDevices
				offlineDevices = syncEngine.offlineDevices
			}
		}

		tableView.reloadData()
	}

	func syncDeviceFound(device: SyncDevice) {
		if let syncEngine = syncEngine {
			nearbyDevices = syncEngine.nearbyDevices
			offlineDevices = syncEngine.offlineDevices
		}

		tableView.reloadData()
	}

	func syncDeviceLost(device: SyncDevice) {
		if let syncEngine = syncEngine {
			nearbyDevices = syncEngine.nearbyDevices
			offlineDevices = syncEngine.offlineDevices
		}

		tableView.reloadData()
	}
}