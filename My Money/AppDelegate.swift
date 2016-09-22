//
//  AppDelegate.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/07/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import UIKit
import ALBNoSQLDB

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	let OSProcessor = OSSpecific() // this is needed to instantiate the object for local notifications

	var syncEngine: SyncEngine?
	var deviceLinkResponse: DeviceResponse?
	var syncIdentifier: UIBackgroundTaskIdentifier?
	
	func applicationDidFinishLaunching(_ application: UIApplication) {
		if (UIApplication.instancesRespond(to: #selector(UIApplication.registerUserNotificationSettings(_:)))) {
			application.registerUserNotificationSettings(UIUserNotificationSettings(types: [UIUserNotificationType.sound, UIUserNotificationType.alert, UIUserNotificationType.badge], categories: nil))
		}

		ALBNoSQLDB.setAutoCloseTimeout(2)
		guard ALBNoSQLDB.open() else { fatalError("Unable to open DB") }
		
		DispatchQueue.global(qos: .default).async {
			self.syncEngine = SyncEngine(name: UIDevice().name)
			self.syncEngine?.linkDelegate = self
		}
	}

	func applicationWillResignActive(_ application: UIApplication) {
		syncIdentifier = UIBackgroundTaskInvalid
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		syncEngine?.stopBonjour()
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		syncEngine?.startBonjour()
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		let device = UIDevice.current
		if device.isMultitaskingSupported {
			syncIdentifier = application.beginBackgroundTask(expirationHandler: { () -> Void in
				self.syncEngine?.syncAllDevices()
			})
		}
	}

	func applicationWillTerminate(_ application: UIApplication) {
		if let syncIdentifier = syncIdentifier {
			application.endBackgroundTask(syncIdentifier)
		}

		syncIdentifier = UIBackgroundTaskInvalid
	}

	func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
	}
}

extension AppDelegate: SyncEngineLinkDelegate {
	func linkRequested(_ device: SyncDevice, deviceResponse: @escaping DeviceResponse) {
		let alert = UIAlertView(title: "Link Requet", message: "Allow device \(device.name) to link with this one?", delegate: self, cancelButtonTitle: "No", otherButtonTitles: "Link")
		deviceLinkResponse = deviceResponse
		
		alert.show()
	}
	
	
	func linkDenied(_ device: SyncDevice) {
		let alert = UIAlertView(title: "Link Denied", message: "\(device.name) has denied the link request.", delegate: nil, cancelButtonTitle: "Darn")
		
		alert.show()
	}
}

extension AppDelegate: UIAlertViewDelegate {
	func alertView(_ alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
		if let deviceResponse = deviceLinkResponse {
			if buttonIndex == 0 {
				deviceResponse(false)
			} else {
				deviceResponse(true)
			}
		}
	}
}
