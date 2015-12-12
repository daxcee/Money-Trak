//
//  PurchaseSegue.swift
//  My Money
//
//  Created by Aaron Bratcher on 7/29/15.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

func purchaseSegue(view:UIViewController, screen:MyMoneyScreen, segue:String, purchaseSegue:String) {
	let compareCount:Int
	let maxCount:Int
	
	switch screen {
	case .Accounts:
		compareCount = CommonDB.accountCount()
		maxCount = PurchaseKit.sharedInstance.maxAccounts()
	case .Recurring:
		compareCount = CommonDB.recurringTransactionCount()
		maxCount = PurchaseKit.sharedInstance.maxRecurringTransactions()
	case .Reconciliations:
		compareCount = CommonDB.reconciliationCount()
		maxCount = PurchaseKit.sharedInstance.maxReconciliations()
	default:
		compareCount = 0
		maxCount = 0
	}
	
	if compareCount < maxCount {
		view.performSegueWithIdentifier(segue, sender: nil)
	} else {
		if PurchaseKit.sharedInstance.availableProductsForScreen(screen).count > 0 {
			if PurchaseKit.sharedInstance.purchaseInFlightForScreen(screen) {
				let alert = UIAlertView(title: "Purchasing", message: "Your in-app purchase is still processing.", delegate: nil, cancelButtonTitle: "OK")
				alert.show()
			} else {
				view.performSegueWithIdentifier(purchaseSegue, sender: nil)
			}
		} else {
			PurchaseKit.sharedInstance.loadProductsForScreen(screen)
			
			let alert = UIAlertView(title: "Purchase Unavailable", message: "Additional items unavailable. Make sure you're connected to the internet and try again.", delegate: nil, cancelButtonTitle: "Thanks")
			alert.show()
		}
	}

}