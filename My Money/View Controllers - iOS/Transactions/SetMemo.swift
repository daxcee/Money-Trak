//
//  SetMemo.swift
//  My Money
//
//  Created by Aaron Bratcher on 11/20/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol MemoDelegate {
	func memoSet()
}

class SetMemoController: UIViewController {
	var transaction: Transaction?
	var delegate: MemoDelegate?
	
	@IBOutlet weak var memoField: UITextView!
	
	override func viewDidLoad() {
		memoField.text = transaction!.note
		memoField.becomeFirstResponder()
	}
	
	@IBAction func saveTapped(sender: AnyObject) {
		transaction!.note = memoField.text
		navigationController?.popViewControllerAnimated(true)
		delay(0.5, closure: {() -> () in
				self.delegate!.memoSet()
			})
	}
}