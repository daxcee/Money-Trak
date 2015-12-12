//
//  File.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/04/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol AlertDelegate {
    func alertSet()
}

class AlertController:UIViewController,UITableViewDelegate,UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    
    var transaction = UpcomingTransaction()
    var helper:TableViewHelper?
    var delegate:AlertDelegate?
    
    override func viewDidLoad() {
        helper = TableViewHelper(tableView: tableView!)
        helper!.addCell(0, cell: tableView.dequeueReusableCellWithIdentifier("None")!, name: "None")
        helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier("1d")!, name: "1d")
        helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier("2d")!, name: "2d")
        helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier("1w")!, name: "1w")
        helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier("2w")!, name: "2w")
        helper!.addCell(1, cell: tableView.dequeueReusableCellWithIdentifier("1m")!, name: "1m")
    }
    
    override func viewDidDisappear(animated: Bool) {
        if let delegate = delegate {
            delegate.alertSet()
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (section == 0 ? 1 : 5)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let name = helper!.cellNameAtIndexPath(indexPath)!
        let cell = helper!.cellForRowAtIndexPath(indexPath)
        var checkmark = false
        switch name {
        case "None":
            if transaction.alerts == nil {
                checkmark = true
            }
        default:
            if let alerts = transaction.alerts {
                if alerts.contains(name) {
                    checkmark = true
                }
            }
        }
        
        cell.accessoryType = (checkmark ? .Checkmark : .None)
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            transaction.alerts = nil
        } else {
            if transaction.alerts == nil {
                transaction.alerts = []
            }
            
            var identifier = ""
            switch indexPath.row {
            case 0:
                identifier = "1d"
            case 1:
                identifier = "2d"
            case 2:
                identifier = "1w"
            case 3:
                identifier = "2w"
            case 4:
                identifier = "1m"
            default:
                break
            }
            
            var alerts = transaction.alerts!
            
            if alerts.contains(identifier) {
                alerts = alerts.filter({$0 != identifier})
            } else {
                alerts.append(identifier)
            }
            
            if alerts.count == 0 {
                transaction.alerts = nil
            } else {
                transaction.alerts = alerts
            }
        }
        
        tableView.reloadData()
    }
}