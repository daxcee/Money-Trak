//
//  PurchaseKit.swift
//  My Money
//
//  Created by Aaron Bratcher on 7/9/15.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import StoreKit

let kProductIdentifierKey = "productIdentifier"

let kCanSync = "Can Sync"
let kMaxSummaryMonths = "Spending Summary Months"
let kMaxRecurringTransactions = "Max Recurring Transactions"
let kMaxAccounts = "Max Accounts"
let kMaxReconciliations = "Max Reconciliations"

// default counts
let kDefaultSummaryMonths = 3
let kDefaultRecurringTransactions = 5
let kDefaultAccounts = 2
let kDefaultReconciliations = 5

// store constants
enum StoreProducts: String {
	case AddSyncing = "MM_Sync"
	case AddReconciliations = "MM_Reconciliations"
	case AddMultipleAccounts = "MM_Accounts"
	case AddSummary = "MM_Summary"
	case AddRecurring = "MM_Recurring"
	case Unknown = ""
}

enum MyMoneyScreen {
	case Sync
	case Accounts
	case Summary
	case Recurring
	case Reconciliations
	case Undefined
}

let kProductsUpdatedNotification = "ProductsUpdatedNotification"
let kPurchaseSuccessfulNotification = "PurchaseSuccessfulNotification"
let allPermissions = true

class PurchaseKit: NSObject {
	var screenProducts = [MyMoneyScreen: [SKProduct]]()
	var pendingRequests = [MyMoneyScreen: SKRequest]()
	var inFlightPurchases = [MyMoneyScreen: String]()
	let defaults = NSUserDefaults.standardUserDefaults()

	class var sharedInstance : PurchaseKit {
		struct Static {
			static let instance = PurchaseKit()
		}
		return Static.instance
	}

	override init() {
		super.init()
		setup()
		SKPaymentQueue.defaultQueue().addTransactionObserver(self)
	}

	func setup() {
		if maxSummaryMonths() == 0 {
			defaults.setInteger(kDefaultSummaryMonths, forKey: kMaxSummaryMonths)
		}

		if maxRecurringTransactions() == 0 {
			defaults.setInteger(kDefaultRecurringTransactions, forKey: kMaxRecurringTransactions)
		}

		if maxAccounts() == 0 {
			defaults.setInteger(kDefaultAccounts, forKey: kMaxAccounts)
		}

		if maxReconciliations() == 0 {
			defaults.setInteger(kDefaultReconciliations, forKey: kMaxReconciliations)
		}
	}

	// MARK: - Existing abilities
	func showAds() -> Bool {
		if allPermissions || canSync() || maxSummaryMonths() > kDefaultSummaryMonths || maxRecurringTransactions() > kDefaultRecurringTransactions || maxAccounts() > kDefaultAccounts || maxReconciliations() > kDefaultReconciliations {
			return false
		}

		return true
	}

	func canSync() -> Bool {
		return allPermissions || defaults.boolForKey(kCanSync)
	}

	func maxSummaryMonths() -> Int {
		let maxCount = (allPermissions ? Int.max : defaults.integerForKey(kMaxSummaryMonths))
		return maxCount
	}

	func maxRecurringTransactions() -> Int {
		let maxCount = (allPermissions ? Int.max : defaults.integerForKey(kMaxRecurringTransactions))
		return maxCount
	}

	func maxAccounts() -> Int {
		let maxCount = (allPermissions ? Int.max : defaults.integerForKey(kMaxAccounts))
		return maxCount
	}

	func maxReconciliations() -> Int {
		let maxCount = (allPermissions ? Int.max : defaults.integerForKey(kMaxReconciliations))
		return maxCount
	}

	// MARK: - Screen Products
	func availableProductsForScreen(screen: MyMoneyScreen) -> [SKProduct] {
		if let products = screenProducts[screen] {
			return products
		}

		return []
	}

	func loadProductsForScreen(screen: MyMoneyScreen) {
		let products = availableProductsForScreen(screen)

		if !SKPaymentQueue.canMakePayments() || products.count > 0 {
			return
		}

		var productCodes = Set<String>()
		switch screen {
		case .Sync:
			productCodes.insert(StoreProducts.AddSyncing.rawValue)
		case .Accounts:
			productCodes.insert(StoreProducts.AddMultipleAccounts.rawValue)
		case .Summary:
			productCodes.insert(StoreProducts.AddSummary.rawValue)
		case .Recurring:
			productCodes.insert(StoreProducts.AddRecurring.rawValue)
		case .Reconciliations:
			productCodes.insert(StoreProducts.AddReconciliations.rawValue)
		default:
			assert(false, "Unknown Screen")
		}

		let request = SKProductsRequest(productIdentifiers: productCodes)
		pendingRequests[screen] = request
		request.delegate = self
		request.start()
	}

	// MARK: - Purchase
	func purchaseInFlightForScreen(screen: MyMoneyScreen) -> Bool {
		if let _ = inFlightPurchases[screen] {
			return true
		}

		return false
	}

	func purchaseProduct(product: SKProduct) {
		let payment = SKPayment(product: product)
		SKPaymentQueue.defaultQueue().addPayment(payment)
	}

	func restorePurchases() {
		SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
	}
}

extension PurchaseKit: SKPaymentTransactionObserver {
	func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			let screen = screenForProductcode(transaction.payment.productIdentifier)

			switch transaction.transactionState {
			case .Purchasing:
				inFlightPurchases[screen] = transaction.payment.productIdentifier

			case .Deferred:
				break

			case .Failed:
				inFlightPurchases.removeValueForKey(screen)
				print(transaction.payment.productIdentifier)
				print(transaction.error)

			case .Purchased:
				NSNotificationCenter.defaultCenter().postNotificationName(kPurchaseSuccessfulNotification, object: nil, userInfo: [kProductIdentifierKey: transaction.payment.productIdentifier])
				fallthrough

			case .Restored:
				processTransaction(transaction)
				queue.finishTransaction(transaction)
				inFlightPurchases.removeValueForKey(screen)
				break
			}
		}
	}

	private func screenForProductcode(productCode: String) -> MyMoneyScreen {
		if let product = StoreProducts(rawValue: productCode) {
			switch product {
			case .AddSyncing:
				return .Sync

			case .AddMultipleAccounts:
				return .Accounts

			case .AddSummary:
				return .Summary

			case .AddRecurring:
				return .Recurring

			case .AddReconciliations:
				return .Reconciliations

			case .Unknown:
				assert(false, "Unknown Product")
			}
		}

		return .Undefined
	}

	func processTransaction(transaction: SKPaymentTransaction) {
		if let product = StoreProducts(rawValue: transaction.payment.productIdentifier) {
			switch product {
			case .AddSyncing:
				defaults.setBool(true, forKey: kCanSync)

			case .AddReconciliations:
				defaults.setInteger(Int.max, forKey: kMaxReconciliations)

			case .AddMultipleAccounts:
				defaults.setInteger(Int.max, forKey: kMaxAccounts)

			case .AddSummary:
				defaults.setInteger(48, forKey: kMaxSummaryMonths)

			case .AddRecurring:
				defaults.setInteger(Int.max, forKey: kMaxRecurringTransactions)

			case .Unknown:
				break
			}

			NSUserDefaults.resetStandardUserDefaults()
		}
	}

	func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
	}

	func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
	}

	func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
	}

	func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
	}
}

extension PurchaseKit: SKProductsRequestDelegate {
	func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
		var requestScreen = MyMoneyScreen.Undefined

		for (screen, pendingRequest) in pendingRequests {
			if pendingRequest == request {
				requestScreen = screen
			}
		}

		pendingRequests.removeValueForKey(requestScreen)

		let products = response.products
		screenProducts[requestScreen] = products
		NSNotificationCenter.defaultCenter().postNotificationName(kProductsUpdatedNotification, object: nil)
	}

	func request(request: SKRequest, didFailWithError error: NSError) {
	}
}