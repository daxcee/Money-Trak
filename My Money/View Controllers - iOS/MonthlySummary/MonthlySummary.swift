//
//  MonthlySummary.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/27/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class MonthlySummaryController: UIViewController, UsesCurrency {
	@IBOutlet weak var progressWheel: UIActivityIndicatorView!

	var tableView: ALBTableView!
	var summary: SummaryMatrix?

	let summaryQueue = DispatchQueue(label: "com.AaronLBratcher.summaryQueue")
	let kTemplateCellCount = 5
	let kColumnHeader = "ColumnHeader"
	let kRowHeader = "RowHeader"
	let kData = "DataCell"
	var transactionKeys = [String]()

	enum Segues: String {
		case ShowTransactions = "ShowTransactions"
	}

	override func viewDidLoad() {
		loadSummary()
	}

	func loadSummary() {
		summaryQueue.async(execute: { () -> Void in
			self.summary = SummaryMatrix()

			DispatchQueue.main.async(execute: { () -> Void in
				if self.tableView != nil {
					self.tableView.removeFromSuperview()
				}

				self.addTableView()
			})
		})
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		NotificationCenter.default.removeObserver(self)
	}

	func addTableView() {
		tableView = ALBTableView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
		tableView.translatesAutoresizingMaskIntoConstraints = false

		view.addSubview(self.tableView)

		let views = ["tableView": tableView]
		let metrics = ["margin": NSNumber(value: 0.0)]

		let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-margin-[tableView]-margin-|", options: NSLayoutFormatOptions(), metrics: metrics, views: views)
		let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-margin-[tableView]-margin-|", options: NSLayoutFormatOptions(), metrics: metrics, views: views)

		view.addConstraints(hConstraints)
		view.addConstraints(vConstraints)

		loadTemplateCells()

		tableView.hasColumnHeaders = true
		tableView.hasRowHeaders = true
		progressWheel.isHidden = true
		tableView.delegate = self
		tableView.dataSource = self
	}

	func loadTemplateCells() {
		let dataCell = UINib(nibName: kData, bundle: Bundle.main)
		tableView.registerDataCellNib(dataCell)

		let columnHeader = UINib(nibName: kColumnHeader, bundle: Bundle.main)
		tableView.registerColumnHeaderNib(columnHeader)

		let rowHeader = UINib(nibName: kRowHeader, bundle: Bundle.main)
		tableView.registerRowHeaderNib(rowHeader)
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		let segueName = Segues(rawValue: segue.identifier!)!

		switch segueName {
		case .ShowTransactions:
			let controller = segue.destination.childViewControllers[0] as! TransactionsController
			controller.transactionKeys = transactionKeys
			controller.inSummary = true
		}
	}

	@IBAction func doneTapped(_ sender: AnyObject) {
		dismiss(animated: true, completion: nil)
	}
}

extension MonthlySummaryController: ALBTableViewDelegate {
	// tableView tap delegate calls
	func didSelectColumn(_ tableView: ALBTableView, column: Int) {
		// TODO: Enable sorting
	}

	func didDeselectColumn(_ tableView: ALBTableView, column: Int) {
	}

	func didSelectRow(_ tableView: ALBTableView, row: Int) {
		if let summary = summary {
			transactionKeys = summary.transactionKeysForRow(row)
			performSegue(withIdentifier: Segues.ShowTransactions.rawValue, sender: nil)
		}
	}

	func didDeselectRow(_ tableView: ALBTableView, row: Int) {
	}

	func didSelectCell(_ tableView: ALBTableView, column: Int, row: Int) {
		if let summary = summary {
			transactionKeys = summary.transactionKeysForColumn(column, row: row)
			performSegue(withIdentifier: Segues.ShowTransactions.rawValue, sender: nil)
		}
	}

	func didDeselectCell(_ tableView: ALBTableView, column: Int, row: Int) {
	}
}

extension MonthlySummaryController: ALBTableViewDataSource {
	// Columns
	func numberOfColumns(_ tableView: ALBTableView) -> Int {
		if let summary = summary {
			return summary.monthNames.count
		}

		return 0
	}

	func columnWidth(_ tableView: ALBTableView) -> CGFloat {
		return 120
	}

	func heightOfColumnHeaders(_ tableView: ALBTableView) -> CGFloat {
		return 25
	}

	func columnHeaderCell(_ tableView: ALBTableView, column: Int) -> UICollectionViewCell {
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
	func numberOfRows(_ tableView: ALBTableView) -> Int {
		if let summary = summary {
			return summary.categoryNames.count
		}

		return 0
	}

	func rowHeight(_ tableView: ALBTableView) -> CGFloat {
		return 35
	}

	func widthOfRowHeaderCells(_ tableView: ALBTableView) -> CGFloat {
		return 120
	}

	func rowHeaderCell(_ tableView: ALBTableView, row: Int) -> UICollectionViewCell {
		let cell = tableView.dequeueRowHeaderForRow(row)

		if let label = cell.viewWithTag(1) as? UILabel {
			if let summary = summary {
				label.text = summary.categoryNames[row]
			}
		}

		return cell
	}

	// Data Cells
	func dataCell(_ tableView: ALBTableView, column: Int, row: Int) -> UICollectionViewCell {
		let cell = tableView.dequeDataCellForColumn(column, row: row)
		if let summary = summary {
			if let amountLabel = cell.viewWithTag(1) as? UILabel {

				if let amount = summary.amounts.amountAtColumn(column, row: row) {
					amountLabel.text = intFormatForAmount(amount)
				} else {
					amountLabel.text = ""
				}
			}
			if let percentLabel = cell.viewWithTag(2) as? UILabel {
				if let percent = summary.percents.amountAtColumn(column, row: row) {
					percentLabel.text = "\(intFormatForAmount(percent*100))%"
				} else {
					percentLabel.text = ""
				}
			}
		}

		return cell
	}
}
