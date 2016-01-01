//
//  AppDelegate.swift
//  My Money
//
//  Created by Aaron Bratcher on 08/07/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import UIKit
import StoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, SyncEngineLinkDelegate, UIAlertViewDelegate {
	
	var window: UIWindow?
	let OSProcessor = OSSpecific() // this is needed to instantiate the object for local notifications
	
	var syncEngine: SyncEngine?
	var deviceLinkResponse: DeviceResponse?
	var syncIdentifier: UIBackgroundTaskIdentifier?
	var purchaseKit = PurchaseKit.sharedInstance
	
	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		if (UIApplication.instancesRespondToSelector(Selector("registerUserNotificationSettings:"))) {
			application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [UIUserNotificationType.Sound, UIUserNotificationType.Alert, UIUserNotificationType.Badge], categories: nil))
		}
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {[unowned self]() -> Void in
			self.syncEngine = SyncEngine(name: UIDevice().name)
			self.syncEngine?.linkDelegate = self
		}
		
		return true
	}
	
	func linkRequested(device: SyncDevice, deviceResponse: (allow: Bool) -> ()) {
		let alert = UIAlertView(title: "Link Requet", message: "Allow device \(device.name) to link with this one?", delegate: self, cancelButtonTitle: "No", otherButtonTitles: "Link")
		deviceLinkResponse = deviceResponse
		
		alert.show()
	}
	
	func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
		if let deviceResponse = deviceLinkResponse {
			if buttonIndex == 0 {
				deviceResponse(allow: false)
			} else {
				deviceResponse(allow: true)
			}
		}
	}
	
	func linkDenied(device: SyncDevice) {
		let alert = UIAlertView(title: "Link Denied", message: "\(device.name) has denied the link request.", delegate: nil, cancelButtonTitle: "Darn")
		
		alert.show()
	}
	
	
	func applicationWillResignActive(application: UIApplication) {
		syncIdentifier = UIBackgroundTaskInvalid
	}
	
	func applicationDidEnterBackground(application: UIApplication) {
		syncEngine?.stopBonjour()
	}
	
	func applicationWillEnterForeground(application: UIApplication) {
		syncEngine?.startBonjour()
	}
	
	func applicationDidBecomeActive(application: UIApplication) {
		let device = UIDevice.currentDevice()
		if device.multitaskingSupported {
			syncIdentifier = application.beginBackgroundTaskWithExpirationHandler({() -> Void in
					self.syncEngine?.syncAllDevices()
				})
		}
	}
	
	func applicationWillTerminate(application: UIApplication) {
		if let syncIdentifier = syncIdentifier {
			application.endBackgroundTask(syncIdentifier)
		}
		
		syncIdentifier = UIBackgroundTaskInvalid
	}
	
	func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
		
	}
}

extension UIButton {
	func glow() {
		let color = self.currentTitleColor
		self.titleLabel!.layer.shadowColor = color.CGColor
		self.titleLabel!.layer.shadowRadius = 4.0
		self.titleLabel!.layer.shadowOpacity = 0.9
		self.titleLabel!.layer.shadowOffset = CGSizeZero
		self.titleLabel!.layer.masksToBounds = false
	}
}

extension UILabel {
	func glow() {
		let color = self.textColor
		self.layer.shadowColor = color.CGColor
		self.layer.shadowRadius = 4.0
		self.layer.shadowOpacity = 0.9
		self.layer.shadowOffset = CGSizeZero
		self.layer.masksToBounds = false
	}
}