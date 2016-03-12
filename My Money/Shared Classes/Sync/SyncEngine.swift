//
//  SyncEngine.swift
//  Shopping
//
//  Created by Aaron Bratcher on 3/22/15.
//  Copyright (c) 2015 Aaron Bratcher. All rights reserved.
//

import Foundation

let kSyncComplete = "SyncComplete"

typealias DeviceResponse = (allow: Bool) -> ()
protocol SyncEngineLinkDelegate {
	func linkRequested(device: SyncDevice, deviceResponse: DeviceResponse)
	func linkDenied(device: SyncDevice)
}

protocol SyncEngineDelegate {
	func statusChanged(device: SyncDevice)

	func syncDeviceFound(device: SyncDevice)
	func syncDeviceLost(device: SyncDevice)
}

enum SyncDeviceStatus {
	case idle, linking, unlinking, syncing
}

enum DataType: Int {
	case syncLogRequest = 1
	case syncError = 2
	case unlink = 3
}

class SyncDevice: ALBNoSQLDBObject {
	var name = ""
	var linked = false
	var lastSync: NSDate?
	var lastSequence = 0
	var status = SyncDeviceStatus.idle
	var errorState = false
	var netNode: ALBPeer?

	convenience init?(key: String) {
		if let value = ALBNoSQLDB.dictValueForKey(table: kDevicesTable, key: key) {
			self.init(keyValue: key, dictValue: value)
		} else {
			self.init()
			return nil
		}
	}

	override init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		if let dictValue = dictValue {
			self.name = dictValue["name"] as! String
			self.linked = dictValue["linked"] as! Bool
			self.lastSequence = dictValue["lastSequence"] as! Int
			if let lastSync = dictValue["lastSync"] as? String {
				self.lastSync = ALBNoSQLDB.dateValueForString(lastSync)
			}
		}

		super.init(keyValue: keyValue, dictValue: dictValue)
	}

	func save() {
		ALBNoSQLDB.setValue(table: kDevicesTable, key: key, value: jsonValue(), autoDeleteAfter: nil)
	}

	override func dictionaryValue() -> [String: AnyObject] {
		var dictValue = [String: AnyObject]()

		dictValue["name"] = name
		dictValue["linked"] = linked
		dictValue["lastSequence"] = lastSequence
		if let lastSync = self.lastSync {
			dictValue["lastSync"] = ALBNoSQLDB.stringValueForDate(lastSync)
		}

		return dictValue
	}
}

class SyncEngine: ALBPeerServerDelegate, ALBPeerClientDelegate, ALBPeerConnectionDelegate {
	var delegate: SyncEngineDelegate? {
		didSet {
			for device in nearbyDevices {
				delegate?.syncDeviceFound(device)
			}
		}
	}

	var linkDelegate: SyncEngineLinkDelegate?

	var nearbyDevices = [SyncDevice]()
	var offlineDevices = [SyncDevice]()

	private var _netServer: ALBPeerServer
	private var _netClient: ALBPeerClient
	private var _netConnections = [ALBPeerConnection]()
	private let syncQueue = dispatch_queue_create("com.AaronLBratcher.SyncQueue", nil)
	private var _timer: dispatch_source_t
	private var _identityKey = ""

	init?(name: String) {
		if let deviceKeys = ALBNoSQLDB.keysInTable(kDevicesTable, sortOrder: "name") {
			for deviceKey in deviceKeys {
				if let offlineDevice = SyncDevice(key: deviceKey) {
					offlineDevices.append(offlineDevice)
				}
			}
		}

		_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, syncQueue)

		ALBNoSQLDB.enableSyncing()
		if let dbKey = ALBNoSQLDB.dbInstanceKey() {
			_identityKey = dbKey
		}

		let netNode = ALBPeer(name: name, peerID: _identityKey)
		_netServer = ALBPeerServer(serviceType: "_mymoneysync._tcp.", serverNode: netNode, serverDelegate: nil)
		_netClient = ALBPeerClient(serviceType: "_mymoneysync._tcp.", clientNode: netNode, clientDelegate: nil)
		_netServer.delegate = self

		// this is here instead of above because all stored properties of a class must be populated first
		if _identityKey == "" {
			return nil
		}

		if !_netServer.startPublishing() {
			return nil
		}

		_netClient.delegate = self
		_netClient.startBrowsing()

		// auto-sync with linked nearby devices every minute
		dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC, 1 * NSEC_PER_SEC); // about every 60 seconds
		dispatch_source_set_event_handler(_timer) {
			self.syncAllDevices()
		}
		dispatch_resume(_timer)

		return
	}

	func stopBonjour() {
		_netServer.stopPublishing()
		_netClient.stopBrowsing()
	}

	func startBonjour() {
		_netServer.startPublishing()
		_netClient.startBrowsing()
	}

	func linkDevice(device: SyncDevice) {
		device.status = .linking
		_netClient.connectToServer(device.netNode!)
		notifyStatusChanged(device)
	}

	func forgetDevice(device: SyncDevice) {
		if nearbyDevices.filter({ $0.key == device.key}).count > 0 {
			device.status = .unlinking
			_netClient.connectToServer(device.netNode!)
			notifyStatusChanged(device)
		}

		completeDeviceUnlink(device)
	}

	func completeDeviceUnlink(device: SyncDevice) {
		ALBNoSQLDB.deleteForKey(table: kDevicesTable, key: device.key)
		device.linked = false
		if offlineDevices.filter({ $0.key == device.key}).count > 0 {
			offlineDevices = offlineDevices.filter({ $0.key != device.key})
		}

		notifyStatusChanged(device)
	}

	private func deviceForNode(node: ALBPeer) -> SyncDevice {
		let devices = nearbyDevices.filter({ $0.key == node.peerID})
		if devices.count > 0 {
			return devices[0]
		}

		let syncDevice: SyncDevice
		if let device = SyncDevice(key: node.peerID) {
			syncDevice = device
		} else {
			let device = SyncDevice()
			device.key = node.peerID
			device.name = node.name

			syncDevice = device
		}
		syncDevice.netNode = node

		return syncDevice
	}

	func syncAllDevices() {
		for device in nearbyDevices {
			syncWithDevice(device)
		}
	}

	func syncWithDevice(device: SyncDevice) {
		if !device.linked || device.status != .idle || !PurchaseKit.sharedInstance.canSync() {
			return
		}

		device.status = .syncing
		notifyStatusChanged(device)
		_netClient.connectToServer(device.netNode!)
	}

	private func notifyStatusChanged(device: SyncDevice) {
		dispatch_async(dispatch_get_main_queue(), { () -> Void in
			self.delegate?.statusChanged(device)
		})
	}

	// MARK: - Server delegate calls
	func serverPublishingError(errorDict: [NSObject : AnyObject]) {
		print("publishing error: \(errorDict)")
	}

	func allowConnectionRequest(remoteNode: ALBPeer, requestResponse: (allow: Bool) -> ()) {
		let device = deviceForNode(remoteNode)
		if device.linked {
			requestResponse(allow: true)
		} else {
			if let linkDelegate = linkDelegate {
				linkDelegate.linkRequested(device, deviceResponse: { (allow) -> () in
					requestResponse(allow: allow)
				})
			} else {
				requestResponse(allow: false)
			}
		}
	}

	func clientDidConnect(connection: ALBPeerConnection) {
		// connection delegate must be made to get read and write calls
		connection.delegate = self

		// strong reference must be kept of the connection
		_netConnections.append(connection)

		// client connected to link or sync. if connection was allowed, we're now linked.
		let device = deviceForNode(connection.remotNode)
		if !device.linked {
			device.linked = true
			device.save()
		}

		device.status = .idle
	}

	// MARK: - Client delegate calls
	func clientBrowsingError(errorDict: [NSObject: AnyObject]) {
		print("browsing error: \(errorDict)")
	}

	func serverFound(server: ALBPeer) {
		dispatch_sync(syncQueue, { () -> Void in
			let device = self.deviceForNode(server)
			if self.nearbyDevices.filter({ $0.key == device.key}).count > 0 || device.key == self._identityKey {
				return
			}

			self.nearbyDevices.append(device)
			self.offlineDevices = self.offlineDevices.filter({ $0.key != device.key})
			self.syncWithDevice(device)

			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				self.delegate?.syncDeviceFound(device)
			})
		})
	}

	func serverLost(server: ALBPeer) {
		dispatch_sync(syncQueue, { () -> Void in
			let device = self.deviceForNode(server)
			if device.status != .idle {
				return
			}

			self.nearbyDevices = self.nearbyDevices.filter({ $0.key != device.key})
			if let offlineDevice = SyncDevice(key: device.key) {
				self.offlineDevices.append(offlineDevice)
			}

			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				self.delegate?.syncDeviceLost(device)
			})
		})
	}

	func unableToConnect(server: ALBPeer) {
		let device = deviceForNode(server)

		switch device.status {
		case .linking:
			device.errorState = true
		case .syncing:
			device.errorState = true
		default:
			break
		}

		device.status = .idle
		notifyStatusChanged(device)
	}

	func connectionDenied(server: ALBPeer) {
		let device = deviceForNode(server)
		device.errorState = false
		device.status = .idle
		notifyStatusChanged(device)
		linkDelegate?.linkDenied(device)
	}

	func connected(connection: ALBPeerConnection) {
		// connection delegate must be made to get read and write calls
		connection.delegate = self

		// strong reference must be kept of the connection
		_netConnections.append(connection)

		let device = deviceForNode(connection.remotNode)

		// connection was initiatied to link, unlink or sync. An allowed connection says we should now be linked.
		if !device.linked {
			device.linked = true
			device.save()
			device.errorState = false
		}

		if device.status == .unlinking {
			let dict = ["dataType": DataType.unlink.rawValue]
			let data = NSKeyedArchiver.archivedDataWithRootObject(dict)
			connection.sendData(data)
			connection.disconnect()

			ALBNoSQLDB.deleteForKey(table: kDevicesTable, key: device.key)
			device.linked = false
			device.status = .idle
			notifyStatusChanged(device)
		} else {
			let dict = ["dataType": DataType.syncLogRequest.rawValue, "lastSequence": device.lastSequence]
			let data = NSKeyedArchiver.archivedDataWithRootObject(dict)
			connection.sendData(data)
		}
	}

	// MARK: - Connection delegate calls
	func disconnected(connection: ALBPeerConnection, byRequest: Bool) {
		let device = deviceForNode(connection.remotNode)

		if !byRequest {
			switch device.status {
			case .linking:
				device.errorState = true
			case .syncing:
				device.errorState = true
			default:
				break
			}

			device.status = .idle
			notifyStatusChanged(device)
		}

		_netConnections = _netConnections.filter({ $0 != connection})
	}

	func textReceived(connection: ALBPeerConnection, text: String) {
		// not used
	}

	func dataReceived(connection: ALBPeerConnection, data: NSData) {
		let device = deviceForNode(connection.remotNode)
		// data packet is only sent to ask for sync file giving lastSequence or failure status of sync request

		if let dataDict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [String: Int], dataType = DataType(rawValue: dataDict["dataType"]!) {
			switch dataType {
			case .syncLogRequest: // server gets this
				let lastSequence = dataDict["lastSequence"]!

				dispatch_async(syncQueue, { () -> Void in
					let searchPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
					let documentFolderPath = searchPaths[0]
					let fileName = ALBNoSQLDB.guid()
					let logFilePath = "\(documentFolderPath)/\(fileName).txt"
					let url = NSURL(fileURLWithPath: logFilePath)

					let (success, _): (Bool, Int) = ALBNoSQLDB.createSyncFileAtURL(url, lastSequence: lastSequence, targetDBInstanceKey: connection.remotNode.peerID)

					if success, let zipURL = self.zipFile(logFilePath) {
						connection.sendResourceAtURL(zipURL, name: "\(fileName).zip", resourceID: fileName, onCompletion: { (sent) -> () in
							connection.disconnect()
							do {
								try NSFileManager.defaultManager().removeItemAtURL(zipURL)
							} catch _ {
							}

							device.errorState = !sent
							device.status = .idle
							self.notifyStatusChanged(device)
						})
					} else {
						// send sync error message
						let dict = ["dataType": DataType.syncError.rawValue]
						let data = NSKeyedArchiver.archivedDataWithRootObject(dict)
						connection.sendData(data)
						connection.disconnect()
					}
				})

			case .unlink:
				completeDeviceUnlink(device)

			default: // client side gets this
				device.errorState = true
				device.status = .idle
				notifyStatusChanged(device)
			}
		} else { // could not parse data packet so don't know message... close connection
			connection.disconnect()
		}
	}

	func startedReceivingResource(connection: ALBPeerConnection, atURL: NSURL, name: String, resourceID: String, progress: NSProgress) {
		print("started to receive \(atURL)")
	}

	func resourceReceived(connection: ALBPeerConnection, atURL: NSURL, name: String, resourceID: String) {
		let device = deviceForNode(connection.remotNode)
		connection.disconnect()

		dispatch_async(syncQueue, { () -> Void in
			if let summaryKeys = ALBNoSQLDB.keysInTable(kMonthlySummaryEntriesTable, sortOrder: nil) {
				for key in summaryKeys {
					ALBNoSQLDB.deleteForKey(table: kMonthlySummaryEntriesTable, key: key)
				}
			}

			let logURL = self.unzipFile(atURL)

			let (successful, _, lastSequence): (Bool, String, Int) = ALBNoSQLDB.processSyncFileAtURL(logURL, syncProgress: nil)
			if successful {
				device.lastSequence = lastSequence
				device.lastSync = NSDate()
				device.save()
				device.errorState = false
			} else {
				device.errorState = true
			}

			do {
				try NSFileManager.defaultManager().removeItemAtURL(logURL)
			} catch _ {
			}

			device.status = .idle
			self.notifyStatusChanged(device)

			NSNotificationCenter.defaultCenter().postNotificationName(kSyncComplete, object: nil)
		})
	}

	func zipFile(filePath: String) -> NSURL? {
		// get path components
		let url = NSURL(fileURLWithPath: filePath)
		guard let fullPath = url.URLByDeletingLastPathComponent, path = fullPath.path else {
			return nil
		}

		var parts = filePath.componentsSeparatedByString("/")
		var fileName = parts[parts.count - 1]
		parts = fileName.componentsSeparatedByString(".")
		fileName = parts[0]
		let zipPath = "\(path)/\(fileName).zip"
		SSZipArchive.createZipFileAtPath(zipPath, withFilesAtPaths: [filePath])

		do {
			try NSFileManager.defaultManager().removeItemAtURL(NSURL(fileURLWithPath: filePath))
		} catch _ {
		}

		if NSFileManager.defaultManager().fileExistsAtPath(zipPath) {
			return NSURL(fileURLWithPath: zipPath)
		} else {
			return nil
		}
	}

	func unzipFile(zipURL: NSURL) -> NSURL {
		let path = zipURL.URLByDeletingLastPathComponent!.path!
		let zipPath = zipURL.path!

		var parts = zipPath.componentsSeparatedByString("/")
		var fileName = parts[parts.count - 1]
		parts = fileName.componentsSeparatedByString(".")
		fileName = parts[0]
		let filePath = "\(path)/\(fileName).txt"

		SSZipArchive.unzipFileAtPath(zipPath, toDestination: path)

		do {
			try NSFileManager.defaultManager().removeItemAtURL(zipURL)
		} catch _ {
		}

		return NSURL(fileURLWithPath: filePath)
	}
}