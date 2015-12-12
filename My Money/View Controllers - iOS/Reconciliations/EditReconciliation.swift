//
//  ReconcileAccount.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/10/14.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

protocol EditReconciliationProtocol {
    func reconciliationAdded(reconciliation:Reconciliation)
    func reconciliationUpdated(reconciliation:Reconciliation)
}

class EditReconciliationController:UIViewController,ReconciliationHeaderDelegate,EditTransactionProtocol,UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate {

    @IBOutlet weak var searchbar: UISearchBar!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var endingBalance: UILabel!
	@IBOutlet weak var transactionCount: UILabel!
	@IBOutlet weak var difference: UILabel!
	
	@IBOutlet weak var tableConstraint: NSLayoutConstraint!
	
	
    var delegate:EditReconciliationProtocol?
    var reconciliation = Reconciliation()
    
    private var _transactionKeys = [String]()
    private var _lastSelection:NSIndexPath?
    private var _searching = false
    private var _buffered = false
	private var _firstForAccount = false
	private var _initialBalanceTansactionKey:String?

    private let _keyboardToolbar = UIToolbar(frame: CGRectMake(0, 0, 100, 34))
	
	enum Segues:String {
		case ShowHeader = "ShowHeader"
		case EditTransaction = "EditTransaction"
		case AddTransaction = "AddTransaction"
	}
	
	//MARK: - View
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        if reconciliation.isNew {
            performSegueWithIdentifier(Segues.ShowHeader.rawValue, sender: nil)
			if let lastReconciliation = CommonDB.lastReconciliationForAccount(reconciliation.accountKey, ignoreUnreconciled: true) {
				reconciliation.beginningBalance = lastReconciliation.endingBalance
			} else {
				_firstForAccount = true
			}
		}
		
		if reconciliation.reconciled {
			navigationItem.rightBarButtonItem = nil
			navigationItem.leftBarButtonItem = nil
			headerView.removeFromSuperview()
            searchbar.removeFromSuperview()
			tableConstraint.constant = -80
		} else {
            let addButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: "addTransaction")
			let saveButton = navigationItem.rightBarButtonItem!
			navigationItem.rightBarButtonItems = [saveButton,addButton]
		}

        updateHeader()
        loadTransactions()
        
        _keyboardToolbar.barStyle =  UIBarStyle.BlackTranslucent
        _keyboardToolbar.frame = CGRectMake(0, 0, self.view.bounds.size.width, 34)
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "doneTyping")
        doneButton.tintColor = UIColor.whiteColor() //(red: 0, green: 0.478431, blue: 1.0, alpha: 1.0)
        _keyboardToolbar.items = [flexSpace,doneButton]
    }
    
    override func viewDidAppear(animated: Bool) {
        if let lastSelection = _lastSelection {
            delay(0.25, closure: { () -> () in
                self.tableView.selectRowAtIndexPath(lastSelection, animated: true, scrollPosition: UITableViewScrollPosition.None)
                delay(1.0, closure: { () -> () in
                    self.tableView.deselectRowAtIndexPath(lastSelection, animated: true)
                    self._lastSelection = nil
                })
            })
        }
        
        searchbar.inputAccessoryView = _keyboardToolbar
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier != nil, let segueName = Segues(rawValue: segue.identifier!) {
			switch segueName {
			case .ShowHeader:
				let controller = segue.destinationViewController as! EditReconciliationHeaderController
				controller.reconciliation = reconciliation
				controller.delegate = self
				
			case .EditTransaction:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! EditEntryController
				controller.delegate = self
				
				let indexPath = sender as! NSIndexPath
				let key = _transactionKeys[indexPath.row]
				controller.showAccountSelector = false
				controller.transaction = Transaction(key: key)!
				controller.title = "Edit Transaction"
				
			case .AddTransaction:
				let navController = segue.destinationViewController as! UINavigationController
				let controller = navController.viewControllers[0] as! EditEntryController
				controller.delegate = self
				controller.maxDate = reconciliation.date
				controller.showAccountSelector = false
				controller.title = "Add Transaction"
			}
		}
    }
	
	// MARK: - Misc
    
    func doneTyping() {
        view.endEditing(true)
    }
	
    func reconciliationHeaderChanged() {
		if _firstForAccount {
			if let key = _initialBalanceTansactionKey {
				CommonDB.updateInitialBalanceTransaction(key, reconciliation: reconciliation)
			} else {
				_initialBalanceTansactionKey = CommonDB.createInitialBalanceTransaction(reconciliation)
			}
		}
		
		loadTransactions()
        updateHeader()
    }
	
    func loadTransactions(searchString:String? = nil) {
        _searching = true

        CommonDB.loadTransactionsForReconciliation(reconciliation, searchString: searchString) { (transactionKeys) -> () in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self._transactionKeys = transactionKeys
                self.tableView.reloadData()
                self._searching = false
            })
        }
    }
	
    func updateHeader() {
		endingBalance.text = CommonFunctions.formatForAmount(reconciliation.endingBalance, useThousandsSeparator: true)
		let countString = CommonFunctions.formatInteger(reconciliation.transactionKeys.count)
		transactionCount.text = countString
		difference.text = CommonFunctions.formatForAmount(reconciliation.difference, useThousandsSeparator: true)
	}
    
    // MARK: - Searchbar
    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        searchbar.showsCancelButton = true
        return true
    }
    
    func searchBar(searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		if let text = searchbar.text {
			performSearch(text)
		}
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchbar.text = ""
        searchbar.endEditing(true)
        performSearch("")
    }
    
    func searchBarShouldEndEditing(searchBar: UISearchBar) -> Bool {
        searchbar.showsCancelButton = false
        return true
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
		// if a search is already in progress... wait a second before doing a search. 
		// Only do this dispatch once per search.
		if _searching {
            if !_buffered {
                _buffered = true
                dispatch_after(1, dispatch_get_main_queue(), { () -> Void in
					if let text = self.searchbar.text {
						self.performSearch(text)
					}
                    self._searching = false
                })
            }
            
            return
        }
        
        var useText = true
        if searchBar.text?.characters.count < 2 {
            useText = false
        }
        
        _buffered = false
		
		if let text = searchbar.text {
			performSearch(useText ? text : "")
		}
    }
    
    func performSearch(text:String) {
        loadTransactions(text)
    }
 
    //MARK: - TableView
        
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _transactionKeys.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell:TransactionCell
        if let transaction = Transaction(key: _transactionKeys[indexPath.row]) {
            if transaction.checkNumber != nil && transaction.checkNumber! > 0 {
                cell = tableView.dequeueReusableCellWithIdentifier("CheckCell") as! TransactionCell
            } else {
                cell = tableView.dequeueReusableCellWithIdentifier("TransactionCell") as! TransactionCell
            }
            cell.transactionKey = _transactionKeys[indexPath.row]
            if !reconciliation.reconciled {
                let cleared = reconciliation.transactionKeys.filter({$0==transaction.key}).count > 0
                cell.reconciled = cleared
            }
        } else {
            cell = tableView.dequeueReusableCellWithIdentifier("TransactionCell") as! TransactionCell
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if reconciliation.reconciled {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
            return
        }

        delay(1.0, closure: { () -> () in
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        })

        let key = _transactionKeys[indexPath.row]
        if reconciliation.hasTransactionKey(key) {
            reconciliation.removeTransactionKey(key)
        } else {
            reconciliation.addTransactionKey(key)
        }
        
        updateHeader()
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
    }
	
	func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        _lastSelection = indexPath
        performSegueWithIdentifier(Segues.EditTransaction.rawValue, sender: indexPath)
	}
    
    //MARK: - User Actions
    
	@IBAction func headerTapped(sender: AnyObject) {
         performSegueWithIdentifier(Segues.ShowHeader.rawValue, sender: nil)
    }
    
    
    @IBAction func cancelTapped(sender: AnyObject) {
        // TODO: Show alert if changes made
		
        if reconciliation.isNew {
            dismissViewControllerAnimated(true, completion:nil)
        } else {
            navigationController?.popViewControllerAnimated(true)
        }

    }

    @IBAction func saveTapped(sender: AnyObject) {
        doneTyping()
        
		if reconciliation.difference == 0 && reconciliation.transactionKeys.count > 0 {
			dispatch_async(dispatch_get_main_queue(), {[unowned self] () -> Void in
				SweetAlert().showAlert("Reconciled?", subTitle: "Save this as fully reconciled? This cannot be undone.", style: AlertStyle.Warning, buttonTitle:"Yes", buttonColor:UIColorFromRGB(0x909090) , otherButtonTitle:  "No", otherButtonColor: UIColorFromRGB(0xDD6B55)) { (isOtherButton) -> Void in
					
					if isOtherButton == true {
							CozyLoadingActivity.show("Saving...", sender: self, disableUI: true)
							
							dispatch_async(dbProcessingQueue, { () -> Void in
								self.reconciliation.reconciled = true
								for key in self.reconciliation.transactionKeys {
									let transaction = Transaction(key: key)!
									transaction.reconciled = true
									transaction.save()
								}

								CozyLoadingActivity.hide(success: true, animated: true)
								
								dispatch_async(dispatch_get_main_queue(), { () -> Void in
									self.closeView()
								})
							})
							
					} else {
						self.closeView()
					}
				}
			})
		} else {
            self.closeView()
		}
    }
	
	func closeView() {
		reconciliation.save()
		
		if reconciliation.isNew {
			dismissViewControllerAnimated(true, completion: { () -> Void in
				self.delegate?.reconciliationAdded(self.reconciliation)
				return
			})
			
		} else {
			navigationController?.popViewControllerAnimated(true)
			delegate?.reconciliationUpdated(reconciliation)
		}
	}
	
	func addTransaction() {
		performSegueWithIdentifier(Segues.AddTransaction.rawValue, sender: nil)
	}
	
	func transactionAdded(transaction:Transaction) {
		var index = 0
		for key in _transactionKeys {
			let testTransaction = Transaction(key: key)!
			let testDate = testTransaction.date.stringValue()
			let date = transaction.date.stringValue()
			if date > testDate {
				break
			} else {
				index++
			}
		}
		
		_transactionKeys.insert(transaction.key, atIndex: index)
        let path = NSIndexPath(forRow: index, inSection: 0)
        if _transactionKeys.count > 5 {
            self.tableView.scrollToRowAtIndexPath(path, atScrollPosition: UITableViewScrollPosition.Middle, animated: true)
        }
        self.tableView.insertRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.Top)
        self.tableView.selectRowAtIndexPath(path, animated: true, scrollPosition: .Middle)
        delay(0.5, closure: { () -> () in
			self.tableView(self.tableView, didSelectRowAtIndexPath: path)
            self.tableView.deselectRowAtIndexPath(path, animated: true)
        })
    }
	
	func transactionUpdated(transaction:Transaction) {
		var path = NSIndexPath(forRow: 0, inSection: 0)
		
		for index in 0..<_transactionKeys.count  {
			if _transactionKeys[index] == transaction.key {
				path = NSIndexPath(forRow: index, inSection: 0)
				break
			}
		}
		
		tableView.reloadRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimation.None)
	}
}

