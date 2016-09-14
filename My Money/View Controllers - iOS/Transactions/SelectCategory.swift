//
//  SelectCategory.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/04/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol CategoryDelegate {
	func categorySet(_ category: Category)
}

class SelectCategoryController: UITableViewController, UIAlertViewDelegate {
	var delegate: CategoryDelegate?
	var selectedCategory: Category?
	var categoryKeys = [String]()

	// MARK: - View
	override func viewDidLoad() {
		categoryKeys = CommonDB.categoryKeys()
		super.viewDidLoad()
	}

	// MARK: - TableView
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return (section == 1 ? 1 : categoryKeys.count)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		var cell: UITableViewCell

		if (indexPath as NSIndexPath).section == 0 {
			cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
			let category = Category(key: categoryKeys[(indexPath as NSIndexPath).row])!
			cell.textLabel!.text = category.name

			var showCheck = false
			if selectedCategory != nil {
				if selectedCategory!.key == category.key {
					showCheck = true
				}
			}

			if showCheck {
				cell.accessoryType = .checkmark
			} else {
				cell.accessoryType = .none
			}
		} else {
			cell = tableView.dequeueReusableCell(withIdentifier: "AddCategoryCell", for: indexPath)
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if (indexPath as NSIndexPath).section == 0 {
			selectedCategory = Category(key: categoryKeys[(indexPath as NSIndexPath).row])
			save()
		} else {
			tableView.deselectRow(at: indexPath, animated: true)
			let alert = UIAlertView(title: "New Category", message: "Enter category name below", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Add")
			alert.alertViewStyle = .plainTextInput
			alert.show()
		}
	}

	func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
		if buttonIndex == 1 {
			let name = alertView.textField(at: 0)?.text
			if name == nil {
				return
			}

			addCategory(CommonDB.categoryForName(name!))
		}
	}

	// MARK: - Other
	func save() {
		navigationController!.popViewController(animated: true)
		delay(0.6, closure: { () -> () in
			self.delegate!.categorySet(self.selectedCategory!)
		})
	}

	func addCategory(_ category: Category) {
		// first see if catgory already existed
		var index = 0
		for categoryKey in categoryKeys {
			if categoryKey == category.key {
				selectedCategory = category
				let indexPath = IndexPath(row: index, section: 0)
				tableView.reloadRows(at: [indexPath], with: .automatic)
				tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
				return
			} else {
				index += 1
			}
		}

		// determine insertion point. Default to end
		var insertIndex = categoryKeys.count
		index = 0
		for key in categoryKeys {
			let testCategory = Category(key: key)!
			if category.name < testCategory.name {
				insertIndex = index
				break
			} else {
				index += 1
			}
		}

		// scroll to insertion point
		let path = IndexPath(row: insertIndex, section: 0)
		self.tableView.scrollToRow(at: path, at: .middle, animated: true)

		// insert category
		delay(0.25, closure: { () -> () in
			self.categoryKeys.insert(category.key, at: index)
			self.tableView.insertRows(at: [path], with: .none)
			self.tableView.selectRow(at: path, animated: true, scrollPosition: .none)
			delay(0.5, closure: { () -> () in
//                self.tableView(self.tableView, didSelectRowAtIndexPath: path)
				self.tableView.deselectRow(at: path, animated: true)
			})
		})
	}
}
