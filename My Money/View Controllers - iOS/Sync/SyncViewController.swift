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
	func linkTappedForDevice(_ device: SyncDevice)
}

class SyncViewController: UITableViewController, UIAlertViewDelegate {
	var syncEngine: SyncEngine?
	var unlinkDevice: SyncDevice?
	var nearbyDevices = [SyncDevice]()
	var offlineDevices = [SyncDevice]()

	enum CellType: String {
		case UnknownCell
		case KnownCell
		case EnableSyncCell
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		let appDelegate = UIApplication.shared.delegate as! AppDelegate
		syncEngine = appDelegate.syncEngine
		if let syncEngine = syncEngine {
			syncEngine.stopBonjour()
			syncEngine.startBonjour()
			syncEngine.delegate = self

			nearbyDevices = syncEngine.nearbyDevices
			offlineDevices = syncEngine.offlineDevices
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		syncEngine?.delegate = nil
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		var sections = 1

		if offlineDevices.count > 0 {
			sections = 2
		}

		return sections
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return "Nearby Devices"
		case 1:
			return "Offline Devices"
		default:
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		var cell = UITableViewCell()
		var device: SyncDevice

		switch (indexPath as NSIndexPath).section {
		case 0:
			device = nearbyDevices[(indexPath as NSIndexPath).row]
			if device.linked {
				let knownCell = tableView.dequeueReusableCell(withIdentifier: CellType.KnownCell.rawValue) as! KnownDeviceCell
				knownCell.device = device
				knownCell.delegate = self
				cell = knownCell
			} else {
				let unknownCell = tableView.dequeueReusableCell(withIdentifier: CellType.UnknownCell.rawValue) as! UnknownDeviceCell
				unknownCell.device = device
				unknownCell.delegate = self
				cell = unknownCell
			}

		default:
			device = offlineDevices[(indexPath as NSIndexPath).row]
			let offlineCell = tableView.dequeueReusableCell(withIdentifier: CellType.KnownCell.rawValue) as! KnownDeviceCell
			offlineCell.device = device
			offlineCell.delegate = self
			cell = offlineCell
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
		return "Unlink"
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		if (indexPath as NSIndexPath).section == 0 {
			let device = nearbyDevices[(indexPath as NSIndexPath).row]
			return device.linked
		}

		return true
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == UITableViewCellEditingStyle.delete {
			let device: SyncDevice
			if (indexPath as NSIndexPath).section == 0 {
				device = nearbyDevices[(indexPath as NSIndexPath).row]
			} else {
				device = offlineDevices[(indexPath as NSIndexPath).row]
			}

			unlinkDevice(device)
		}
	}

	@IBAction func doneTapped(_ sender: AnyObject) {
		dismiss(animated: true, completion: nil)
	}
}

//MARK: - Sync Cell Delegate
extension SyncViewController: SyncDeviceCellDelegate {

	func linkTappedForDevice(_ device: SyncDevice) {
		syncEngine?.linkDevice(device)
	}

	func unlinkDevice(_ device: SyncDevice) {
		unlinkDevice = device
		let alert = UIAlertView(title: "Unlink", message: "Unlink from \(device.name)?", delegate: self, cancelButtonTitle: "No", otherButtonTitles: "Unlink")
		alert.show()
	}

	func alertView(_ alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
		tableView.setEditing(false, animated: true)

		if let device = unlinkDevice {
			if buttonIndex == 1 {
				syncEngine?.forgetDevice(device)
				tableView.reloadData()
			}
		}
	}

	func syncTappedForDevice(_ device: SyncDevice) {
		syncEngine?.syncWithDevice(device)
	}
}

//MARK: - Snyc Engine Delegate
extension SyncViewController: SyncEngineDelegate {
	func statusChanged(_ device: SyncDevice) {
		if offlineDevices.filter({ $0.key == device.key }).count > 0 {
			if let syncEngine = syncEngine {
				nearbyDevices = syncEngine.nearbyDevices
				offlineDevices = syncEngine.offlineDevices
			}
		}

		tableView.reloadData()
	}

	func syncDeviceFound(_ device: SyncDevice) {
		if let syncEngine = syncEngine {
			nearbyDevices = syncEngine.nearbyDevices
			offlineDevices = syncEngine.offlineDevices
		}

		tableView.reloadData()
	}

	func syncDeviceLost(_ device: SyncDevice) {
		if let syncEngine = syncEngine {
			nearbyDevices = syncEngine.nearbyDevices
			offlineDevices = syncEngine.offlineDevices
		}

		tableView.reloadData()
	}
}
