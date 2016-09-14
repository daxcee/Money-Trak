//
//  SelectLocation.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/04/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol LocationDelegate {
	func locationSet(_ location: Location)
}

class SelectLocationController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

	@IBOutlet weak var textField: UITextField!
	@IBOutlet weak var tableView: UITableView!

	var delegate: LocationDelegate?
	var locationKeys = [String]()
	var selectedLocation: Location?
	var searching = false
	let searchQueue: DispatchQueue = DispatchQueue(label: "com.aaronlbratcher.myMoneyLocationSearch")

	override func viewDidAppear(_ animated: Bool) {
		if selectedLocation != nil {
			textField.text = selectedLocation!.name
			selectedLocation = nil
		}

		textField.becomeFirstResponder()
	}

	// MARK: - TableView
	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return locationKeys.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
		let location = Location(key: locationKeys[(indexPath as NSIndexPath).row])!
		cell.textLabel!.text = location.name

		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let location = Location(key: locationKeys[(indexPath as NSIndexPath).row])!
		textField.text = location.name
		selectedLocation = Location(key: locationKeys[(indexPath as NSIndexPath).row])
		save(self)
	}

	// MARK: - TextField
	@IBAction func valueChanged(_ sender: AnyObject) {
		performSearch()
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		save(self)
		return false;
	}

	// MARK: - Other
	@IBAction func save(_ sender: AnyObject) {
		if selectedLocation == nil, let locationText = self.textField.text {
			selectedLocation = CommonDB.locationForName(locationText)
		}

		navigationController!.popViewController(animated: true)
		delay(0.6, closure: { () -> () in
			self.delegate!.locationSet(self.selectedLocation!)
		})
	}

	func performSearch() {
		if searching {
			return
		}

		searchQueue.async(execute: { [weak self]() -> Void in
			guard let controller = self else { return }

			if let locationText = controller.textField.text {
				controller.searching = true
				controller.locationKeys = CommonDB.locationKeysForString(locationText)
				controller.searching = false
				DispatchQueue.main.sync(execute: { () -> Void in
					controller.tableView.reloadData()
				})
			}
		})
	}
}
