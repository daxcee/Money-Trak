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

class InitialController: UIViewController, UsesCurrency {
	@IBOutlet weak var totalAvailableView: UIView!
	@IBOutlet weak var totalAvailable: UILabel!
	@IBOutlet weak var syncButton: UIButton!

	var defaults = DefaultManager()

	var amountAvailable = 0
	private var _userInteractingWithAd = false

	enum Segue: String {
		case Transactions
		case Upcoming
		case Recurring
		case AddTransaction
		case Sync
	}

	override func viewDidLoad() {
		NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: kUpdateTotalAvailableNotification), object: nil, queue: OperationQueue.main) { (notification) -> Void in
			DispatchQueue.main.async(execute: { () -> Void in
				self.showTotalAvailable()
			})
		}

		NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: kSyncComplete), object: nil, queue: OperationQueue.main) { (notification) -> Void in
			CommonDB.recalculateAllBalances()
		}

		CommonDB.setup()
		super.viewDidLoad()
	}

	override func viewWillAppear(_ animated: Bool) {
		showTotalAvailable()
	}

	override func viewDidAppear(_ animated: Bool) {
		let checkedForPasscode = defaults.boolForKey(.CheckPasscode)
		if !checkedForPasscode {
			defaults.setBool(true, forKey: .CheckPasscode)
			if !deviceHasPasscode() {
				let alert = UIAlertController(title: "No Passcode", message: "For the safety of the data in this app, this device should have a passcode set.", preferredStyle: .alert)
				let openSettings = { (action: UIAlertAction!) -> Void in
					UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
				}

				let action = UIAlertAction(title: "Settings", style: UIAlertActionStyle.default, handler: openSettings)

				alert.addAction(action)
				alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))

				self.present(alert, animated: true, completion: nil)
			}
		}

		if !ALBNoSQLDB.open() {
			let alert = UIAlertController(title: "Database Error", message: "Unable to open the Money Trak database.", preferredStyle: .alert)
			let quitAction = { (action: UIAlertAction!) -> Void in
				abort()
			}
			alert.addAction(UIAlertAction(title: "Quit", style: UIAlertActionStyle.cancel, handler: quitAction))
		}

		super.viewDidAppear(animated)
	}

	override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
		return UIInterfaceOrientation.portrait
	}
	
	override var shouldAutorotate: Bool {
		return false
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier != nil, let segueName = Segue(rawValue: segue.identifier!) {
			switch segueName {
			case .Transactions:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! TransactionsController
				controller.upcomingTransactions = false
				controller.recurringTransactions = false

			case .Upcoming:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! TransactionsController
				controller.upcomingTransactions = true
				controller.recurringTransactions = false

			case .Recurring:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! TransactionsController
				controller.upcomingTransactions = false
				controller.recurringTransactions = true

			case .AddTransaction:
				let navController = segue.destination as! UINavigationController
				let controller = navController.viewControllers[0] as! EditEntryController
				controller.title = "Add Transaction"

			case .Sync:
				let controller = segue.destination.childViewControllers[0] as! SyncViewController
				controller.title = "Sync"
			}
		}
	}

	// MARK: - User actions
	@IBAction func syncTapped(_ sender: AnyObject) {
		performSegue(withIdentifier: Segue.Sync.rawValue, sender: nil)
	}

	// MARK: - other methods
	func showTotalAvailable() {
		let greenColor = UIColor(red: 0.93333333333333, green: 1, blue: 0.94117647058824, alpha: 1)
		let yellowColor = UIColor(red: 1, green: 0.98823529411765, blue: 0.91764705882353, alpha: 1)
		let redColor = UIColor(red: 1, green: 0.85490196078431, blue: 0.87058823529412, alpha: 1)
		let alertDate = defaults.objectForKey(.UpcomingTransactionsWarning) as? Date

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
		let secret = "Device has passcode set?".data(using: String.Encoding.utf8, allowLossyConversion: false)
		let attributes = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "LocalDevicesServices", kSecAttrAccount as String: "NoAccount", kSecValueData as String: secret!, kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly] as [String : Any]

		let status = SecItemAdd(attributes as CFDictionary, nil)
		if status == 0 {
			SecItemDelete(attributes as CFDictionary)
			return true
		}

		return false
	}
}
