//
//  Transactions.swift
//  My Money
//
//  Created by Aaron Bratcher on 09/01/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

let _searchQueue = dispatch_queue_create("com.AaronLBratcher.MyMoneySearch", DISPATCH_QUEUE_SERIAL)

final class TransactionsController: UITableViewController,EditTransactionProtocol,AccountCellDelegate,AccountDelegate {
    @IBOutlet weak var searchbar: UISearchBar!

    var inSummary = false
    var upcomingTransactions = false
    var recurringTransactions = false
    var transactionKeys = [String]()

    private var _currentAccountKey = CommonFunctions.currentAccountKey
	private var _accountView:AccountView?
    private var _lastSelection:NSIndexPath?
    private var _searching = false
	
	enum Segues:String {
		case SetAccount = "SetAccount"
		case AddTransaction = "AddTransaction"
		case EditTransaction = "EditTransaction"
		case PurchaseRecurring = "PurchaseRecurring"
	}
	
    override func viewDidLoad() {
		if !upcomingTransactions && !recurringTransactions {
			if !inSummary, let accountView = NSBundle.mainBundle().loadNibNamed("AccountView", owner: self, options: nil)[0] as? AccountView {
				self._accountView = accountView
				accountView.delegate = self
				updateAccountInfo()
                
                if let searchbar = searchbar, keys = ALBNoSQLDB.keysInTable(kReconcilationsTable, sortOrder: nil) where keys.count > 0 {
                    searchbar.showsScopeBar = true
                    searchbar.scopeButtonTitles = ["All","Outstanding","Cleared"]
                    searchbar.backgroundColor = UIColor.whiteColor()
                    searchbar.selectedScopeButtonIndex = 0
                    searchbar.sizeToFit()
                }
            }
        }
        
		if upcomingTransactions {
			NSNotificationCenter.defaultCenter().addObserverForName(kUpdateUpcomingTransactionsNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) -> Void in
				self.loadTransactions(.all(""))
				self.tableView.reloadData()
			})
		}
		
        if !inSummary {
            loadTransactions(.all(""))
        }
        
        if let searchbar = searchbar {
            let keyboardToolbar = UIToolbar(frame: CGRectMake(0, 0, 100, 34))
            keyboardToolbar.barStyle =  UIBarStyle.BlackTranslucent
            keyboardToolbar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 34)
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "doneTyping")
            doneButton.tintColor = UIColor.whiteColor() //(red: 0, green: 0.478431, blue: 1.0, alpha: 1.0)
            keyboardToolbar.items = [flexSpace,doneButton]
            
            searchbar.inputAccessoryView = keyboardToolbar
        }
		
		if PurchaseKit.sharedInstance.maxRecurringTransactions() == kDefaultRecurringTransactions {
			PurchaseKit.sharedInstance.loadProductsForScreen(.Recurring)
			NSNotificationCenter.defaultCenter().addObserverForName(kPurchaseSuccessfulNotification, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
				if let userInfo = notification.userInfo as? [String:String], identifier = userInfo[kProductIdentifierKey] where identifier == StoreProducts.AddRecurring.rawValue {
					delay(1.0, closure: { () -> () in
						self.addTapped(self)
					})
				}
			}
		}
    }
	
	private func updateAccountInfo() {
		_accountView?.account = Account(key: _currentAccountKey)!
	}
	
    override func viewWillAppear(animated: Bool) {
        if upcomingTransactions {
            navigationItem.title = "Upcoming"
        } else {
            if recurringTransactions {
                navigationItem.title = "Recurring"
            } else {
                navigationItem.title = "Transactions"
            }
        }
    }
    
    func doneTyping() {
        searchbar.resignFirstResponder()
        if searchbar.text?.characters.count > 0 {
            searchbar.showsCancelButton = true
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        if let lastSelection = _lastSelection {
            tableView.selectRowAtIndexPath(lastSelection, animated: true, scrollPosition: UITableViewScrollPosition.None)
            delay(1.0, closure: { () -> () in
                self.tableView.deselectRowAtIndexPath(lastSelection, animated: true)
                self._lastSelection = nil
            })
        }
    }

    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return UIInterfaceOrientation.Portrait
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segues(rawValue: segue.identifier!) {
			switch segueName {
				
        case .SetAccount:
			let navController = segue.destinationViewController as! UINavigationController
			let controller = navController.viewControllers[0] as! SelectAccountController
			controller.currentAccountKey = _currentAccountKey
			controller.accountDelegate = self
				
			case .AddTransaction:
				fallthrough
				
			case .EditTransaction:
				let controller:EditEntryController
				
				if let navController = segue.destinationViewController as? UINavigationController {
					controller = navController.viewControllers[0] as! EditEntryController
				} else {
					controller = segue.destinationViewController as! EditEntryController
				}
				
				controller.delegate = self
				controller.upcomingTransaction = upcomingTransactions
				controller.recurringTransaction = recurringTransactions
				
				if segue.identifier == "EditTransaction" {
					let indexPath = sender as! NSIndexPath
					let key = transactionKeys[indexPath.row]
					if upcomingTransactions {
						controller.transaction = UpcomingTransaction(key: key)!
						controller.title = "Edit Upcoming"
					} else {
						if recurringTransactions {
							controller.transaction = RecurringTransaction(key: key)!
							controller.title = "Edit Recurring"
						} else {
							controller.showAccountSelector = false
							controller.transaction = Transaction(key: key)!
							controller.title = "Edit Transaction"
						}
					}
				} else {
					if recurringTransactions {
						controller.title = "Add Recurring"
					} else {
						if upcomingTransactions {
							controller.title = "Add Upcoming"
							
						} else {
							controller.showAccountSelector = false
							controller.title = "Add Transaction"
						}
					}
				}
				
			case .PurchaseRecurring:
				let controller = segue.destinationViewController as! MakePurchaseController
				controller.products = PurchaseKit.sharedInstance.availableProductsForScreen(.Recurring)
			}
		}
	}
	
    func loadTransactions(filter:TransactionFilter) {
        if recurringTransactions {
            transactionKeys = CommonDB.recurringTransactionKeys(filter)
        } else {
			if upcomingTransactions {
				transactionKeys = CommonDB.upcomingTransactionKeys(filter)
			} else {
				transactionKeys = CommonDB.transactionKeys(filter)
			}
        }
		
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.tableView.reloadData()
        })
    }
		
	// MARK: - TableView

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if _accountView != nil {
			return 40
		}
		
		return 0
	}
	
    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return _accountView
	}
	
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       return transactionKeys.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let transactionCell = tableView.dequeueReusableCellWithIdentifier("TransactionCell", forIndexPath: indexPath) as! TransactionCell
        transactionCell.upcomingTransaction = upcomingTransactions
        transactionCell.recurringTransaction = recurringTransactions
        transactionCell.transactionKey = transactionKeys[indexPath.row]
        
        return transactionCell
    }
	
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		if recurringTransactions || upcomingTransactions {
			return true
		}
		
		let transaction = Transaction(key: transactionKeys[indexPath.row])!
		return !transaction.reconciled
	}
	
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            // if recurring, delete all remaining upcoming
            if recurringTransactions {
                let transaction = RecurringTransaction(key: transactionKeys[indexPath.row])!
                let recurringCondition = DBCondition(set: 0, objectKey: "recurringTransactionKey", conditionOperator: .equal, value: transaction.recurringTransactionKey)
                let keys = ALBNoSQLDB.keysInTableForConditions(kUpcomingTransactionsTable, sortOrder:nil, conditions: [recurringCondition])
                if keys == nil {
                    delay(0.5, closure: { () -> () in
                        self.tableView.setEditing(false, animated: true)
                    })
                    return
                }
                
                if keys!.count == 0 {
                    self.deleteTransaction(indexPath.row)
                } else {
                    // TODO: Show alert saying all pending transations will be deleted. Allow for cancel
                    SweetAlert().showAlert("Delete Recurring?", subTitle: "\(keys!.count) pending transactions will be deleted.", style: AlertStyle.Warning, buttonTitle:"Cancel", buttonColor:UIColorFromRGB(0x909090) , otherButtonTitle: "Delete", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in
                        if isOtherButton == true {
                            self.tableView.setEditing(false, animated: true)
                        }
                        else {
                            for key in keys! {
                                let upcoming = UpcomingTransaction(key: key)!
                                upcoming.delete()
                            }
                            self.deleteTransaction(indexPath.row)
                            SweetAlert().showAlert("Complete", subTitle: "Recurring transactions have been deleted.", style: AlertStyle.Success)
                        }
                    }
                }
                
                
            } else {
                deleteTransaction(indexPath.row)
            }
        }
    }
	
    override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        _lastSelection = indexPath
        performSegueWithIdentifier(Segues.EditTransaction.rawValue, sender: indexPath)
    }
	
	// MARK: - Other
	
	func accountCellTapped() {
		performSegueWithIdentifier(Segues.SetAccount.rawValue, sender: nil)
	}
	
	
	@IBAction func addTapped(sender: AnyObject) {
		if recurringTransactions {
			purchaseSegue(self, screen: .Recurring, segue: Segues.AddTransaction.rawValue, purchaseSegue: Segues.PurchaseRecurring.rawValue)
		} else {
			performSegueWithIdentifier(Segues.AddTransaction.rawValue, sender: nil)
		}
	}
	
	func accountSet(account: Account) {
		_currentAccountKey = account.key
		CommonFunctions.currentAccountKey = _currentAccountKey
		updateAccountInfo()
		processSearchText()
	}
	
	func ccAccountSet(account: Account) {
		// not used
	}
	
	func deleteTransaction(row: Int) {
        var transaction:Transaction?
        var indexPath = NSIndexPath(forRow: row, inSection: 0)
        
        if upcomingTransactions {
            transaction = UpcomingTransaction(key: transactionKeys[row])
        } else {
            if recurringTransactions {
                transaction = RecurringTransaction(key: transactionKeys[row])
            } else {
                transaction = Transaction(key: transactionKeys[row])
                indexPath = NSIndexPath(forRow: row, inSection: 0)
            }
        }
        
        if transaction != nil {
            transaction?.delete()
            transactionKeys.removeAtIndex(row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
			updateAccountInfo()
        }
	}
    
    func transactionAdded(transaction: Transaction) {
        transactionKeys.insert(transaction.key, atIndex: 0)
        
        let path = NSIndexPath(forRow: 0, inSection: 0)
        tableView.insertRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.Top)
		updateAccountInfo()
    }
    
    func transactionUpdated(transaction: Transaction) {
        var path = NSIndexPath(forRow: 0, inSection: 0)
        
        for index in 0..<transactionKeys.count  {
            if transactionKeys[index] == transaction.key {
                path = NSIndexPath(forRow: index, inSection: 0)
                break
            }
        }
        
        tableView.reloadRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.None)
		updateAccountInfo()
	}
    
    func checkBalances() {
        //TODO: Fill this in
    }
    
    @IBAction func doneTapped(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil);
    }
 }


// MARK: - Search Bar
extension TransactionsController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        searchbar.showsCancelButton = true
        return true
    }
    
    func searchBar(searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		if let text = searchbar.text {
			performSearch(text, selectedScope: selectedScope)
		}
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchbar.text = ""
        searchbar.endEditing(true)
        performSearch("", selectedScope: searchBar.selectedScopeButtonIndex)
    }
    
    func searchBarShouldEndEditing(searchBar: UISearchBar) -> Bool {
        searchbar.showsCancelButton = false
        return true
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
		processSearchText()
	}
	
	func processSearchText() {
		if _searching {
			return
		}
		
		_searching = true
		
		let selectedScope:Int
		if searchbar.showsScopeBar {
			selectedScope = searchbar.selectedScopeButtonIndex
		} else {
			selectedScope = 0
		}
		
		dispatch_async(_searchQueue, { () -> Void in
			if let text = self.searchbar.text {
				self.performSearch(text, selectedScope: selectedScope)
			}
			self._searching = false
		})
	}
	
    func performSearch(text:String, selectedScope:Int) {
        switch selectedScope {
        case 1:
            loadTransactions(.outstanding(text))
        case 2:
            loadTransactions(.cleared(text))
        default:
            loadTransactions(.all(text))
        }
        
    }
}

class TransactionsAccountCell:UITableViewCell {
    
    @IBOutlet weak var accountName: UILabel!
    @IBOutlet weak var currentBalance: UILabel!
    
    var accountKey:String {
        get {
            return ""
        }
        
        set(key) {
            let account = Account(key: key)!
            accountName.text = account.name
            currentBalance.text = CommonFunctions.formatForAmount(account.balance,useThousandsSeparator:true)
        }
    }
}

class TransactionCell:UITableViewCell {
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
    
    var transactionKey:String {
        get {
            return ""
        }
        
        set(key) {
            var transaction:Transaction
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
            amount.text = CommonFunctions.formatForAmount(transaction.amount,useThousandsSeparator:true)
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
    
    var reconciled:Bool {
        get {
            return !recurringBadge.hidden
        }
        set(isReconciled) {
            reconciledBadge.hidden = !isReconciled
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
