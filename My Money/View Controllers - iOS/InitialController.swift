//
//  InitialController.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/11/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import iAd

class InitialController: UIViewController, Numbers {
	@IBOutlet weak var totalAvailableView: UIView!
	@IBOutlet weak var totalAvailable: UILabel!
	@IBOutlet weak var bannerView: ADBannerView!
	@IBOutlet weak var bannerBottomConstraint: NSLayoutConstraint!
	@IBOutlet weak var syncButton: UIButton!

	var defaults = DefaultManager()

	var amountAvailable = 0
	private var _userInteractingWithAd = false

	enum Segues: String {
		case Transactions
		case Upcoming
		case Recurring
		case AddTransaction
		case Sync
	}

	override func viewDidLoad() {
		NSNotificationCenter.defaultCenter().addObserverForName(kUpdateTotalAvailableNotification, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				self.showTotalAvailable()
			})
		}

		NSNotificationCenter.defaultCenter().addObserverForName(kSyncComplete, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
			CommonDB.recalculateAllBalances()
		}

		CommonDB.setup()

		super.viewDidLoad()
	}

	override func viewWillAppear(animated: Bool) {
		showTotalAvailable()
		self.bannerBottomConstraint.constant = -self.bannerView.frame.size.height
	}

	override func viewDidAppear(animated: Bool) {
		let checkedForPasscode = defaults.boolForKey(.CheckPasscode)
		if !checkedForPasscode {
			defaults.setBool(true, forKey: .CheckPasscode)
			if !deviceHasPasscode() {
				let alert = UIAlertController(title: "No Passcode", message: "For the safety of the data in this app, this device should have a passcode set.", preferredStyle: .Alert)
				let openSettings = { (action: UIAlertAction!) -> Void in
					UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
				}

				let action = UIAlertAction(title: "Settings", style: UIAlertActionStyle.Default, handler: openSettings)

				alert.addAction(action)
				alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))

				self.presentViewController(alert, animated: true, completion: nil)
			}
		}

		if !ALBNoSQLDB.open() {
			let alert = UIAlertController(title: "Database Error", message: "Unable to open the Money Trak database.", preferredStyle: .Alert)
			let quitAction = { (action: UIAlertAction!) -> Void in
				abort()
			}
			alert.addAction(UIAlertAction(title: "Quit", style: UIAlertActionStyle.Cancel, handler: quitAction))
		}

		super.viewDidAppear(animated)
	}

	override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
		return UIInterfaceOrientation.Portrait
	}

	override func shouldAutorotate() -> Bool {
		return false
	}

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segues(rawValue: segue.identifier!) {
			switch segueName {
			case .Transactions:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! TransactionsController
				controller.upcomingTransactions = false
				controller.recurringTransactions = false

			case .Upcoming:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! TransactionsController
				controller.upcomingTransactions = true
				controller.recurringTransactions = false

			case .Recurring:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! TransactionsController
				controller.upcomingTransactions = false
				controller.recurringTransactions = true

			case .AddTransaction:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! EditEntryController
				controller.title = "Add Transaction"

			case .Sync:
				let controller = segue.destinationViewController.childViewControllers[0] as! SyncViewController
				controller.title = "Sync"
			}
		}
	}

	// MARK: - User actions
	@IBAction func syncTapped(sender: AnyObject) {
		performSegueWithIdentifier(Segues.Sync.rawValue, sender: nil)
	}

	// MARK: - other methods
	func showTotalAvailable() {
		let greenColor = UIColor(red: 0.93333333333333, green: 1, blue: 0.94117647058824, alpha: 1)
		let yellowColor = UIColor(red: 1, green: 0.98823529411765, blue: 0.91764705882353, alpha: 1)
		let redColor = UIColor(red: 1, green: 0.85490196078431, blue: 0.87058823529412, alpha: 1)
		let alertDate = defaults.objectForKey(.UpcomingTransactionsWarning) as? NSDate

		let amountAvailable = CommonFunctions.totalAmountAvailable()
		self.totalAvailable.text = "Total Available: \(intFormatForAmount(amountAvailable))"

		if amountAvailable / 100 <= 100 {
			totalAvailableView.backgroundColor = redColor
		} else {
			if amountAvailable / 100 <= 500 || alertDate != nil {
				totalAvailableView.backgroundColor = yellowColor
			} else {
				totalAvailableView.backgroundColor = greenColor
			}
		}
	}

	func deviceHasPasscode() -> Bool {
		let secret = "Device has passcode set?".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
		let attributes = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "LocalDevicesServices", kSecAttrAccount as String: "NoAccount", kSecValueData as String: secret!, kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly]

		let status = SecItemAdd(attributes, nil)
		if status == 0 {
			SecItemDelete(attributes)
			return true
		}

		return false
	}
}