//
//  EditAccount.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/05/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class EditAccountController:UITableViewController,AccountTypeDelegate,UpdateDelegate {
    @IBOutlet weak var typeCell: UITableViewCell!
    @IBOutlet weak var accountName: UITextField!
    @IBOutlet weak var balanceCell: UITableViewCell!
    @IBOutlet weak var totalCredit: UITextField!
    @IBOutlet weak var creditAvailableCell: UITableViewCell!
    @IBOutlet weak var updateTotalCell: UITableViewCell!
    
    
    
    var delegate:EditAccountDelegate?
    var account:Account? {
        get {
            return _account
        }
        
        set(newAccount) {
            _account = newAccount
        }
    }

    
    private var _account:Account?
    private var _newAccount = false
	
	enum Segues:String {
		case SetType = "SetType"
		case SetUpdateTotal = "SetUpdateTotal"
	}
   
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        if let account = _account {
            typeCell.detailTextLabel?.text = account.type.rawValue
            accountName.text = account.name
            balanceCell.detailTextLabel?.text = CommonFunctions.formatForAmount(account.balance,useThousandsSeparator: true)
            if account.type == .creditCard {
                totalCredit.text = CommonFunctions.intFormatForAmount(account.maxBalance)
            }
            
            self.navigationItem.leftBarButtonItem = nil
        } else {
            _newAccount = true
            _account = Account()
        }

        updateTotalCell.detailTextLabel?.text = _account!.updateString()

        creditAvailableCell.clipsToBounds = true
        totalCredit.keyboardType = .NumberPad
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        let keys = ALBNoSQLDB.keysInTable(kAccountsTable, sortOrder:nil)
        if keys != nil && keys?.count == 0 {
            navigationItem.leftBarButtonItem = nil
            // TODO: Show alert?
        }
        
        if _account == nil {
            _newAccount = true
            _account = Account()
        }
        
        balanceCell.detailTextLabel?.text = CommonFunctions.formatForAmount(_account!.balance,useThousandsSeparator:true)
        totalCredit.text = (_account!.maxBalance/100).description
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segues(rawValue: segue.identifier!) {
			switch segueName {
				
			case .SetType:
				let controller = segue.destinationViewController as! AccountTypeController
				controller.delegate = self
				
			case .SetUpdateTotal:
				let controller = segue.destinationViewController as! SetUpdateController
				controller.delegate = self
				controller.account = _account!
			}
		}
    }
	
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 1 && indexPath.row == 2 {
            let height = (_account!.type != .creditCard ? 0 : 44) as CGFloat
            return height
        }
        
        return 44
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    @IBAction func cancelTapped(sender: AnyObject) {
        if _newAccount {
            dismissViewControllerAnimated(true, completion: nil)
        } else {
            self.navigationController?.popViewControllerAnimated(true)
        }
    }
    
    @IBAction func saveTapped(sender: AnyObject) {
		if let account = _account {
            if accountName.text == nil || accountName.text == "" {
                accountName.text = account.type.rawValue
            }
            
            account.name = accountName.text!
            
            if account.type == .creditCard {
                account.maxBalance = Int(totalCredit.text!)!*100
            }
            
            account.save()
        }
        
        if _newAccount {
            dismissViewControllerAnimated(true, completion: { () -> Void in
                let account = self._account
                self.delegate?.accountCreated(account!)
            })
        } else {
            self.navigationController?.popViewControllerAnimated(true)
            self.delegate?.accountUpdated(self._account!)
        }
        
    }
    
    func accountTypeSelected(type: AccountType) {
        _account!.type = type
        self.typeCell.detailTextLabel?.text = type.rawValue
        
        UIView.animateWithDuration(0.5, animations: {
            self.tableView.reloadData()
        })
    }
    
    func updateTotalSelected() {
        updateTotalCell.detailTextLabel?.text = _account!.updateString()
        tableView.reloadData()
        // TODO: Regenerate total available from selection
    }
}