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
    func categorySet(category:Category)
}

class SelectCategoryController:UITableViewController,UIAlertViewDelegate {
    var delegate:CategoryDelegate?
    var selectedCategory:Category?
    var categoryKeys = [String]()
    
    
    //MARK: - View
    override func viewDidLoad() {
        categoryKeys = CommonDB.categoryKeys()
        super.viewDidLoad()
    }
    
    // MARK: - TableView
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 1 ? 1 : categoryKeys.count)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:UITableViewCell
        
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) 
            let category = Category(key: categoryKeys[indexPath.row])!
            cell.textLabel!.text = category.name
            
            var showCheck = false
            if selectedCategory != nil {
                if selectedCategory!.key == category.key {
                    showCheck = true
                }
            }
            
            if showCheck {
                cell.accessoryType = .Checkmark
            } else {
                cell.accessoryType = .None
            }
            
        } else {
            cell = tableView.dequeueReusableCellWithIdentifier("AddCategoryCell", forIndexPath: indexPath) 
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            selectedCategory = Category(key:categoryKeys[indexPath.row])
            save()
        } else {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
            let alert = UIAlertView(title: "New Category", message: "Enter category name below", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Add")
            alert.alertViewStyle = .PlainTextInput
            alert.show()
        }
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 1 {
            let name = alertView.textFieldAtIndex(0)?.text
            if name == nil {
                return
            }
            
            addCategory(CommonDB.categoryForName(name!))
        }
    }
    
    //MARK: - Other
    func save() {
        navigationController!.popViewControllerAnimated(true)
        delay(0.6, closure: { () -> () in
            self.delegate!.categorySet(self.selectedCategory!)
        })
    }
    
    func addCategory(category:Category) {
        // first see if catgory already existed
        var index = 0
        for categoryKey in categoryKeys {
            if categoryKey == category.key {
                selectedCategory = category
                let indexPath = NSIndexPath(forRow: index, inSection: 0)
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .Middle, animated: true)
                return
            } else {
                index++
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
                index++
            }
        }
        
        // scroll to insertion point
        let path = NSIndexPath(forRow: index, inSection: 0)
        self.tableView.scrollToRowAtIndexPath(path, atScrollPosition: .Middle, animated: true)
        
        // insert category
        delay(0.25, closure: { () -> () in
            self.categoryKeys.insert(category.key, atIndex: index)
            self.tableView.insertRowsAtIndexPaths([path], withRowAnimation: .None)
            self.tableView.selectRowAtIndexPath(path, animated: true, scrollPosition: .None)
            delay(0.5, closure: { () -> () in
//                self.tableView(self.tableView, didSelectRowAtIndexPath: path)
                self.tableView.deselectRowAtIndexPath(path, animated: true)
            })
        })
    }
}