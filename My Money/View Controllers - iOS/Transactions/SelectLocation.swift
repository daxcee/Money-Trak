//
//  SelectLocation.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/04/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol  LocationDelegate {
    func locationSet(location:Location)
}

class SelectLocationController:UIViewController,UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    var delegate:LocationDelegate?
    var locationKeys = [String]()
    var selectedLocation:Location?
    var searching = false
    let searchQueue:dispatch_queue_t = dispatch_queue_create("com.aaronlbratcher.myMoneyLocationSearch", DISPATCH_QUEUE_SERIAL)
    
    
    override func viewDidAppear(animated: Bool) {
        if selectedLocation != nil {
            textField.text = selectedLocation!.name
            selectedLocation = nil
        }
        
        textField.becomeFirstResponder()
    }
    
    // MARK: - TableView
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationKeys.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("LocationCell", forIndexPath: indexPath) 
        let location = Location(key: locationKeys[indexPath.row])!
        cell.textLabel!.text = location.name
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let location = Location(key: locationKeys[indexPath.row])!
        textField.text = location.name
        selectedLocation = Location(key: locationKeys[indexPath.row])
        save(self)
    }
    
    // MARK: - TextField
    @IBAction func valueChanged(sender: AnyObject) {
        performSearch()
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        save(self)
        return false;
    }
    
    // MARK: - Other
    @IBAction func save(sender: AnyObject) {
        if selectedLocation == nil, let locationText = self.textField.text {
            selectedLocation = CommonDB.locationForName(locationText)
        }
        
        navigationController!.popViewControllerAnimated(true)
        delay(0.6, closure: { () -> () in
            self.delegate!.locationSet(self.selectedLocation!)
        })
    }
    
    func performSearch() {
        if searching {
            return
        }
        
        dispatch_async(searchQueue, { () -> Void in
			if let locationText = self.textField.text {
				self.searching = true
				self.locationKeys = CommonDB.locationKeysForString(locationText)
				self.searching = false
				dispatch_sync(dispatch_get_main_queue(), { () -> Void in
					self.tableView.reloadData()
				})
			}
        })
    }
}