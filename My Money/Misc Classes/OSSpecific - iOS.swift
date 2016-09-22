//
//  OSSpecific - iOS.swift
//  My Money
//
//  Created by Aaron Bratcher on 11/26/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import ALBNoSQLDB

class OSSpecific {

	init() {
		let mainQueue = OperationQueue.main

		NotificationCenter.default.addObserver(forName: NSNotification.Name("CreateLocalNotification"), object: nil, queue: mainQueue) { (notification: Notification) -> Void in
			self.createNotificationForTransaction(notification)
		}

		NotificationCenter.default.addObserver(forName: NSNotification.Name("LastRecurringProcessed"), object: nil, queue: mainQueue) { (notification: Notification) -> Void in
			self.lastRecurringProcessed(notification)
		}
	}

	func createNotificationForTransaction(_ notification: Notification) {
		if let dict = notification.userInfo as? [String: UpcomingTransaction] {
			let transaction = dict["transaction"]!

			let hasKey = ALBNoSQLDB.tableHasKey(table: kNotifiedTransactionsTable, key: transaction.key)
			if hasKey != nil && hasKey! {
				return
			}

			if let alerts = transaction.alerts {
				for alertTime in alerts {
					let notification = UILocalNotification()
					notification.hasAction = false
					notification.alertBody = "\(transaction.locationName()) will be processed on \(transaction.date.mediumDateString())"

					switch alertTime {
					case "1m":
						notification.fireDate = transaction.date.addDate(years: 0, months: -1, weeks: 0, days: 0) as Date
					case "2w":
						notification.fireDate = transaction.date.addDate(years: 0, months: 0, weeks: -2, days: 0) as Date
					case "1w":
						notification.fireDate = transaction.date.addDate(years: 0, months: 0, weeks: -1, days: 0) as Date
					case "2d":
						notification.fireDate = transaction.date.addDate(years: 0, months: 0, weeks: 0, days: -2) as Date
					case "1d":
						notification.fireDate = transaction.date.addDate(years: 0, months: 0, weeks: 0, days: -1) as Date
					default:
						break
					}

					UIApplication.shared.scheduleLocalNotification(notification)
				}

				let _ = ALBNoSQLDB.setValue(table: kNotifiedTransactionsTable, key: transaction.key, value: "{}", autoDeleteAfter: nil)
			}
		}
	}

	func lastRecurringProcessed(_ notification: Notification) {
		if (notification as NSNotification).userInfo != nil {
			let _ = SweetAlert().showAlert("Complete", subTitle: "At least one recurring transaction has finsihed.", style: AlertStyle.success)
		}
	}
}
