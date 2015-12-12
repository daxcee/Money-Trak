//
//  MonthlySummary.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/27/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class MonthlySummaryController:UIViewController {
    @IBOutlet weak var progressWheel: UIActivityIndicatorView!
	
	var tableView: ALBTableView!
    var summary:SummaryMatrix?
    
    let summaryQueue = dispatch_queue_create("com.AaronLBratcher.summaryQueue", DISPATCH_QUEUE_CONCURRENT)
    let kTemplateCellCount = 5
    let kColumnHeader = "ColumnHeader"
    let kRowHeader = "RowHeader"
    let kData = "DataCell"
    var transactionKeys = [String]()
	
	enum Segues:String {
		case ShowTransactions = "ShowTransactions"
		case AddMonths = "AddMonths"
	}

	override func viewDidLoad() {
		if PurchaseKit.sharedInstance.maxSummaryMonths() == kDefaultSummaryMonths {
			NSNotificationCenter.defaultCenter().addObserverForName(kProductsUpdatedNotification, object: nil, queue: nil, usingBlock: { (notification) -> Void in
				if PurchaseKit.sharedInstance.availableProductsForScreen(.Summary).count > 0 {
					let addButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: "addMonthsTapped")
					self.navigationItem.rightBarButtonItem = addButton
				}
			})
			
			PurchaseKit.sharedInstance.loadProductsForScreen(.Summary)
			
			NSNotificationCenter.defaultCenter().addObserverForName(kPurchaseSuccessfulNotification, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
				if let userInfo = notification.userInfo as? [String:String], identifier = userInfo[kProductIdentifierKey] where identifier == StoreProducts.AddSummary.rawValue {
					delay(1.0, closure: { () -> () in
						self.loadSummary()
					})
				}
			}
		}
		
		loadSummary()
	}
	
	func loadSummary() {
		dispatch_async(summaryQueue, { () -> Void in
			self.summary = SummaryMatrix()
			
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				if self.tableView != nil {
					self.tableView.removeFromSuperview()
				}
				
				self.addTableView()
			})
		})
	}
	
	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	func addTableView() {
		tableView = ALBTableView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
		tableView.translatesAutoresizingMaskIntoConstraints = false
		
		view.addSubview(self.tableView)
		
		let views = ["tableView":tableView]
		let metrics = ["margin":NSNumber(double: 0.0)]
		
		let hConstraints = NSLayoutConstraint.constraintsWithVisualFormat("H:|-margin-[tableView]-margin-|", options: NSLayoutFormatOptions(), metrics: metrics, views: views)
		let vConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|-margin-[tableView]-margin-|", options: NSLayoutFormatOptions(), metrics: metrics, views: views)
		
		view.addConstraints(hConstraints)
		view.addConstraints(vConstraints)
		
		loadTemplateCells()
		
		tableView.hasColumnHeaders = true
		tableView.hasRowHeaders = true
		progressWheel.hidden = true
		tableView.delegate = self
		tableView.dataSource = self
	}
	
	func loadTemplateCells() {
		let dataCell = UINib(nibName: kData, bundle: NSBundle.mainBundle())
		tableView.registerDataCellNib(dataCell)
		
		let columnHeader = UINib(nibName: kColumnHeader, bundle: NSBundle.mainBundle())
		tableView.registerColumnHeaderNib(columnHeader)
		
		let rowHeader = UINib(nibName: kRowHeader, bundle: NSBundle.mainBundle())
		tableView.registerRowHeaderNib(rowHeader)
	}
	
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		let segueName = Segues(rawValue: segue.identifier!)!
		
		switch segueName {
		case .ShowTransactions:
			let controller = segue.destinationViewController.childViewControllers[0] as! TransactionsController
			controller.transactionKeys = transactionKeys
			controller.inSummary = true
			
		case .AddMonths:
			let controller = segue.destinationViewController as! MakePurchaseController
			controller.products = PurchaseKit.sharedInstance.availableProductsForScreen(.Summary)
			controller.title = "Add Months"
		}
		
    }
	
    override func shouldAutorotate() -> Bool {
        return true
    }
    
	
	@IBAction func doneTapped(sender: AnyObject) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	
	func addMonthsTapped() {
		performSegueWithIdentifier(Segues.AddMonths.rawValue, sender: nil)
	}
	
}

extension MonthlySummaryController:ALBTableViewDelegate {
	// tableView tap delegate calls
	func didSelectColumn(tableView:ALBTableView, column:Int) {
		//TODO: Enable sorting
	}
	
	func didDeselectColumn(tableView:ALBTableView, column:Int) {
	}
	
	func didSelectRow(tableView:ALBTableView, row:Int) {
		if let summary = summary {
			transactionKeys = summary.transactionKeysForRow(row)
			performSegueWithIdentifier(Segues.ShowTransactions.rawValue, sender: nil)
		}
	}
	
	func didDeselectRow(tableView: ALBTableView, row: Int) {
		
	}
	
	func didSelectCell(tableView:ALBTableView, column:Int, row:Int) {
		if let summary = summary {
			transactionKeys = summary.transactionKeysForColumn(column, row: row)
			performSegueWithIdentifier(Segues.ShowTransactions.rawValue, sender: nil)
		}
	}

	func didDeselectCell(tableView: ALBTableView, column: Int, row: Int) {
		
	}
}

extension MonthlySummaryController:ALBTableViewDataSource {
	// Columns
	func numberOfColumns(tableView:ALBTableView) -> Int {
		if let summary = summary {
			return summary.monthNames.count
		}
		
		return 0
	}
	
	func columnWidth(tableView:ALBTableView) -> CGFloat {
		return 120
	}
	
	func heightOfColumnHeaders(tableView:ALBTableView) -> CGFloat {
		return 25
	}
	
	func columnHeaderCell(tableView:ALBTableView, column:Int) -> UICollectionViewCell {
		let cell = tableView.dequeueColumnHeaderForColumn(column)
		
		if let label = cell.viewWithTag(1) as? UILabel {
			if column == -1 {
				label.text = "Category"
			} else {
				if let summary = summary {
					label.text = summary.monthNames[column]
				}
			}
		}
		
		return cell
	}
	
	// Rows
	func numberOfRows(tableView:ALBTableView) -> Int {
		if let summary = summary {
			return summary.categoryNames.count
		}
		
		return 0
	}
	
	func rowHeight(tableView:ALBTableView) -> CGFloat {
		return 35
	}
	
	func widthOfRowHeaderCells(tableView:ALBTableView) -> CGFloat {
		return 120
	}
	
	func rowHeaderCell(tableView:ALBTableView, row:Int) -> UICollectionViewCell {
		let cell = tableView.dequeueRowHeaderForRow(row)
		
		if let label = cell.viewWithTag(1) as? UILabel {
			if let summary = summary {
				label.text = summary.categoryNames[row]
			}
		}
		
		return cell
	}
	
	// Data Cells
	func dataCell(tableView:ALBTableView, column:Int, row:Int) -> UICollectionViewCell {
		let cell = tableView.dequeDataCellForColumn(column, row: row)
		if let summary = summary {
			if let amountLabel = cell.viewWithTag(1) as? UILabel {
				
				if let amount = summary.amounts.amountAtColumn(column, row: row) {
					amountLabel.text = CommonFunctions.intFormatForAmount(amount)
				} else {
					amountLabel.text = ""
				}
			}
			if let percentLabel = cell.viewWithTag(2) as? UILabel {
				if let percent = summary.percents.amountAtColumn(column, row: row) {
					percentLabel.text = "\(CommonFunctions.intFormatForAmount(percent*100))%"
				} else {
					percentLabel.text = ""
				}
			}
		}
		
		return cell
	}
}