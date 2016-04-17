//
//  TransactionCell.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 4/17/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class TransactionCell: UITableViewCell, Numbers, Reusable {
	@IBOutlet weak var transactionDate: UILabel!
	@IBOutlet weak var transactionYear: UILabel!
	@IBOutlet weak var amount: UILabel!
	@IBOutlet weak var location: UILabel!
	@IBOutlet weak var recurringBadge: UIImageView!
	@IBOutlet weak var reconciledBadge: UIImageView!
	@IBOutlet weak var dateConstraint: NSLayoutConstraint!
	@IBOutlet weak var checkNumber: UILabel?

	var upcomingTransaction = false
	var recurringTransaction = false

	var transactionKey: String {
		get {
			return ""
		}

		set(key) {
			var transaction: Transaction
			if upcomingTransaction {
				transaction = UpcomingTransaction(key: key)!
			} else {
				if recurringTransaction {
					transaction = RecurringTransaction(key: key)!
				} else {
					transaction = Transaction(key: key)!
				}
			}

			reconciledBadge.hidden = !transaction.reconciled

			if recurringTransaction {
				transactionDate.hidden = true
				transactionYear.hidden = true
				recurringBadge.hidden = true
				dateConstraint.constant = -76
			} else {
				transactionDate.hidden = false
				transactionYear.hidden = false
				recurringBadge.hidden = transaction.recurringTransactionKey == ""
				transactionDate.text = dayFormatter.stringFromDate(transaction.date)
				transactionYear.text = yearFormatter.stringFromDate(transaction.date)
			}
			amount.text = formatForAmount(transaction.amount, useThousandsSeparator: true)
			if transaction.amount < 0 {
				amount.textColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
			} else {
				amount.textColor = UIColor(red: 0, green: 0.29019607843137, blue: 0, alpha: 1)
			}

			location.text = transaction.locationName()

			if let checkNumber = self.checkNumber {
				checkNumber.text = "\(transaction.checkNumber!)"
			}
		}
	}

	var reconciled = false {
		didSet {
			let color: UIColor

			if reconciled {
				reconciledBadge.hidden = false
				color = UIColor(red: 0, green: 0, blue: 255, alpha: 0.15)
			} else {
				reconciledBadge.hidden = true
				color = UIColor.whiteColor()
			}

			self.backgroundColor = color
		}
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
}
