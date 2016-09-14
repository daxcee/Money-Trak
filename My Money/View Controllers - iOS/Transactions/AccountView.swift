//
//  AccountView.swift
//  My Money
//
//  Created by Aaron Bratcher on 11/19/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol AccountCellDelegate {
	func accountCellTapped()
}

class AccountView: UIView, UsesCurrency {
	var delegate: AccountCellDelegate?
	var account: Account {
		get {
			return _account
		}
		
		set(newAccount) {
			_account = newAccount
			accountName.text = _account.name
			accountBalance.text = formatForAmount(account.balance, useThousandsSeparator: true)
		}
	}
	
	@IBOutlet private weak var accountName: UILabel!
	@IBOutlet private weak var accountBalance: UILabel!
	
	@IBOutlet private weak var arrowConstraint: NSLayoutConstraint!
	@IBOutlet private weak var accountButton: UIButton!
	
	private var _account: Account = Account()
	
	func allowTap(_ allow: Bool) {
		if allow {
			arrowConstraint.constant = 8
			accountButton.isHidden = false
		} else {
			arrowConstraint.constant = -10
			accountButton.isHidden = true
		}
	}
	
	@IBAction private func buttonTapped(_ sender: AnyObject) {
		delegate?.accountCellTapped()
	}
}
