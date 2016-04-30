//
//  TransactionAccountCell.swift
//  Money Trak
//
//  Created by Aaron Bratcher on 4/30/16.
//  Copyright © 2016 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class TransactionsAccountCell: UITableViewCell, Numbers {

	@IBOutlet weak var accountName: UILabel!
	@IBOutlet weak var currentBalance: UILabel!

	var accountKey: String {
		get {
			return ""
		}

		set(key) {
			let account = Account(key: key)!
			accountName.text = account.name
			currentBalance.text = formatForAmount(account.balance, useThousandsSeparator: true)
		}
	}
}