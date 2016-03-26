//
//  ABTableView.swift
//  My Money
//
//  Created by Aaron Bratcher on 12/31/2014.
//  Copyright (c) 2014 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

//MARK: - Protocols
protocol ALBTableViewDataSource {
	// Columns
	func numberOfColumns(tableView: ALBTableView) -> Int
	func columnWidth(tableView: ALBTableView) -> CGFloat

	// Column Headers
	func heightOfColumnHeaders(tableView: ALBTableView) -> CGFloat
	func columnHeaderCell(tableView: ALBTableView, column: Int) -> UICollectionViewCell

	// Rows
	func numberOfRows(tableView: ALBTableView) -> Int
	func rowHeight(tableView: ALBTableView) -> CGFloat

	// Row Headers
	func widthOfRowHeaderCells(tableView: ALBTableView) -> CGFloat
	func rowHeaderCell(tableView: ALBTableView, row: Int) -> UICollectionViewCell

	// Data Cells
	func dataCell(tableView: ALBTableView, column: Int, row: Int) -> UICollectionViewCell
}

protocol ALBTableViewDelegate {
	func didSelectColumn(tableView: ALBTableView, column: Int)
	func didDeselectColumn(tableView: ALBTableView, column: Int)

	func didSelectRow(tableView: ALBTableView, row: Int)
	func didDeselectRow(tableView: ALBTableView, row: Int)

	func didSelectCell(tableView: ALBTableView, column: Int, row: Int)
	func didDeselectCell(tableView: ALBTableView, column: Int, row: Int)
}

enum ALBTableViewCellType: String {
	case Data = "DataCell"
	case ColumnHeader = "ColumnHeader"
	case RowHeader = "RowHeader"
}

// MARK: - ALBTableView Class
final class ALBTableView: UIView {
	var hasRowHeaders = false {
		didSet {
			reloadData()
		}
	}

	var hasColumnHeaders = false {
		didSet {
			reloadData()
		}
	}

	var showGrid = true {
		didSet {
			reloadData()
		}
	}

	var gridColor = UIColor.lightGrayColor() {
		didSet(newColor) {
			collectionView.backgroundColor = newColor
		}
	}

	var dataSource: ALBTableViewDataSource? {
		didSet {
			reloadData()
		}
	}

	var delegate: ALBTableViewDelegate?

	private var collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), collectionViewLayout: ALBTableViewLayout())
	private var columns = 0
	private var rows = 0

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		setup()
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		setup()
	}

	func setup() {
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.backgroundColor = gridColor

		addSubview(collectionView)

		let viewsDictionary = ["collectionView": collectionView]

		let hConstraints = NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[collectionView]-0-|", options: NSLayoutFormatOptions(), metrics: nil, views: viewsDictionary)

		let vConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[collectionView]-0-|", options: NSLayoutFormatOptions(), metrics: nil, views: viewsDictionary)

		addConstraints(hConstraints)
		addConstraints(vConstraints)

		collectionView.dataSource = self
		collectionView.delegate = self

		let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
		collectionView.addGestureRecognizer(pinchGesture)

		collectionView.minimumZoomScale = 0.25
		collectionView.maximumZoomScale = 4.0

		let layout = ALBTableViewLayout()
		layout.tableView = self
		collectionView.collectionViewLayout = layout
	}

	func zoom(recognizer: UIPinchGestureRecognizer) {
		print("zooming...")
	}

	func reloadData() {
		if let dataSource = dataSource {
			if showGrid {
				backgroundColor = gridColor
			} else {
				backgroundColor = UIColor.whiteColor()
			}

			columns = dataSource.numberOfColumns(self)
			rows = dataSource.numberOfRows(self)

			collectionView.collectionViewLayout.invalidateLayout()
		}
	}

	// MARK: - Register Cell NIBs
	func registerDataCellNib(nib: UINib) {
		collectionView.registerNib(nib, forCellWithReuseIdentifier: ALBTableViewCellType.Data.rawValue)
	}

	func registerColumnHeaderNib(nib: UINib) {
		collectionView.registerNib(nib, forSupplementaryViewOfKind: ALBTableViewCellType.ColumnHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.ColumnHeader.rawValue)
	}

	func registerRowHeaderNib(nib: UINib) {
		collectionView.registerNib(nib, forSupplementaryViewOfKind: ALBTableViewCellType.RowHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.RowHeader.rawValue)
	}

	// MARK: - Dequeue Cells
	func dequeDataCellForColumn(column: Int, row: Int) -> UICollectionViewCell {
		let indexPath = NSIndexPath(forRow: row, inSection: column)

		let cell = collectionView.dequeueReusableCellWithReuseIdentifier(ALBTableViewCellType.Data.rawValue, forIndexPath: indexPath)
		return cell
	}

	func dequeueColumnHeaderForColumn(column: Int) -> UICollectionViewCell {
		let indexPath = NSIndexPath(forRow: 0, inSection: column)

		let cell = collectionView.dequeueReusableSupplementaryViewOfKind(ALBTableViewCellType.ColumnHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.ColumnHeader.rawValue, forIndexPath: indexPath) as! UICollectionViewCell

		return cell
	}

	func dequeueRowHeaderForRow(row: Int) -> UICollectionViewCell {
		let indexPath = NSIndexPath(forRow: row, inSection: 0)

		let cell = collectionView.dequeueReusableSupplementaryViewOfKind(ALBTableViewCellType.RowHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.RowHeader.rawValue, forIndexPath: indexPath) as! UICollectionViewCell

		return cell
	}

	// MARK: - Public Select / Deselect Methods
	func selectCell(column: Int, row: Int) {
	}

	func selectColumn(column: Int) {
	}

	func selectRow(row: Int) {
	}

	func deselectCell(column: Int, row: Int) {
	}

	func deselectColumn(column: Int) {
	}

	func deselectRow(column: Int) {
	}
}

extension ALBTableView: UICollectionViewDataSource {
	func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
		return columns
	}

	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return rows
	}

	func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
		if let dataSource = dataSource {
			let cell: UICollectionViewCell

			let headerType = ALBTableViewCellType(rawValue: kind)!
			switch headerType {
			case .ColumnHeader:
				cell = dataSource.columnHeaderCell(self, column: indexPath.section)

			case .RowHeader:
				cell = dataSource.rowHeaderCell(self, row: indexPath.row)

			case .Data:
				cell = UICollectionViewCell()
			}

			return cell
		}

		return UICollectionViewCell()
	}

	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		if let dataSource = dataSource {
			let cell = dataSource.dataCell(self, column: indexPath.section, row: indexPath.row)
			return cell
		}

		return UICollectionViewCell()
	}
}

extension ALBTableView: UICollectionViewDelegate {
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		delegate?.didSelectCell(self, column: indexPath.section, row: indexPath.row)
	}

	func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
		delegate?.didDeselectCell(self, column: indexPath.section, row: indexPath.row)
	}
}

//MARK: - Layout Class
final class ALBTableViewLayout: UICollectionViewLayout {
	var tableView: ALBTableView?
	var contentSize = CGSize(width: 0, height: 0)
	var columnWidth: CGFloat = 0
	var rowHeight: CGFloat = 0
	var rowHeaderWidth: CGFloat = 0
	var columnHeaderHeight: CGFloat = 0
	var lastRect = CGRect(x: 0, y: 0, width: 100, height: 100)

	override func collectionViewContentSize() -> CGSize {
		return contentSize
	}

	override func prepareLayout() {
		if let tableView = tableView, dataSource = tableView.dataSource {
			var totalWidth: CGFloat = 0.0
			var totalHeight: CGFloat = 0.0

			columnWidth = dataSource.columnWidth(tableView)
			rowHeight = dataSource.rowHeight(tableView)

			if tableView.hasColumnHeaders {
				columnHeaderHeight = dataSource.heightOfColumnHeaders(tableView)
				totalHeight = columnHeaderHeight + (tableView.showGrid ? 1.0 : 0)
			}

			totalHeight = totalHeight + (CGFloat(tableView.rows) * rowHeight)
			totalHeight = totalHeight + (tableView.showGrid ? CGFloat(tableView.rows) + 1: 0)

			if tableView.hasRowHeaders {
				rowHeaderWidth = dataSource.widthOfRowHeaderCells(tableView)
				totalWidth = rowHeaderWidth + (tableView.showGrid ? 1.0 : 0)
			}

			totalWidth = totalWidth + (CGFloat(tableView.columns) * columnWidth)
			totalWidth = totalWidth + (tableView.showGrid ? CGFloat(tableView.columns) + 1: 0)

			contentSize = CGSize(width: totalWidth, height: totalHeight)
		}
	}

	// MARK: - Layout for cells
	override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
		if let tableView = tableView {
			lastRect = rect
			var attributes = [UICollectionViewLayoutAttributes]()
			let columnCount = tableView.columns
			let rowCount = tableView.rows

			if columnCount == 0 || rowCount == 0 {
				return nil
			}

			if tableView.hasColumnHeaders && tableView.hasRowHeaders {
				let indexPath = NSIndexPath(forRow: 0, inSection: -1)
				if let columnHeaderAttributes = layoutAttributesForSupplementaryViewOfKind(ALBTableViewCellType.ColumnHeader.rawValue, atIndexPath: indexPath) {
					attributes.append(columnHeaderAttributes)
				}

				// if self.collectionView!.contentOffset.x > 0 {
				// let shadowAttributes = UICollectionViewLayoutAttributes(forDecorationViewOfKind: ALBTableViewCellType.RowHeader.rawValue, withIndexPath: indexPath)
				// let frame = CGRect(x: columnHeaderAttributes.frame.origin.x + rowHeaderWidth, y: columnHeaderAttributes.frame.origin.y, width: 2, height: columnHeaderHeight)
				// shadowAttributes.frame = frame
				// shadowAttributes.zIndex = 2
				// attributes.append(shadowAttributes)
				// }
			}

			for column in 0 ..< columnCount {
				for row in 0 ..< rowCount {
					let indexPath = NSIndexPath(forRow: row, inSection: column)
					let frame = frameAtIndexPath(indexPath, tableView: tableView)

					if frame.intersects(rect) {
						let layoutAttributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
						layoutAttributes.frame = frame
						layoutAttributes.zIndex = 1
						attributes.append(layoutAttributes)

						if tableView.hasColumnHeaders {
							if let columnHeaderAttributes = layoutAttributesForSupplementaryViewOfKind(ALBTableViewCellType.ColumnHeader.rawValue, atIndexPath: indexPath) {
								attributes.append(columnHeaderAttributes)
							}
						}

						if tableView.hasRowHeaders {
							if let rowHeaderAttributes = layoutAttributesForSupplementaryViewOfKind(ALBTableViewCellType.RowHeader.rawValue, atIndexPath: indexPath) {
								attributes.append(rowHeaderAttributes)
							}
						}
					}
				}
			}

			return attributes
		}

		return nil
	}

	override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
		let attributes = UICollectionViewLayoutAttributes(forCellWithIndexPath: indexPath)
		if let tableView = tableView {
			attributes.frame = frameAtIndexPath(indexPath, tableView: tableView)
			attributes.zIndex = 1
		}

		return attributes
	}

	private func frameAtIndexPath(indexPath: NSIndexPath, tableView: ALBTableView) -> CGRect {
		let column = CGFloat(indexPath.section)
		let row = CGFloat(indexPath.row)

		let x: CGFloat = (tableView.hasRowHeaders ? rowHeaderWidth : (tableView.showGrid ? 1 : 0)) + (column * columnWidth) + (tableView.showGrid ? 1.0 * column: 0)
		let y: CGFloat = (tableView.hasColumnHeaders ? columnHeaderHeight : (tableView.showGrid ? 1 : 0)) + (row * rowHeight) + (tableView.showGrid ? 1.0 * row: 0)

		let frame = CGRect(x: x, y: y, width: columnWidth, height: rowHeight)

		return frame
	}

	// MARK: - Other layout
	override func layoutAttributesForSupplementaryViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
		let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind, withIndexPath: indexPath)
		if let tableView = tableView {
			let column = CGFloat(indexPath.section)
			let row = CGFloat(indexPath.row)
			let showGrid = tableView.showGrid
			let frame: CGRect

			if indexPath.row == 0 && indexPath.section == -1 {
				frame = CGRect(x: self.collectionView!.contentOffset.x, y: self.collectionView!.contentOffset.y, width: rowHeaderWidth, height: columnHeaderHeight)
				attributes.zIndex = 4
			} else {
				let headerType = ALBTableViewCellType(rawValue: elementKind)!
				switch headerType {
				case .ColumnHeader:
					let x = (indexPath.section == 0 && !tableView.hasRowHeaders ? 0 : rowHeaderWidth) + (column * columnWidth) + (showGrid ? 1.0 * column: 0)
					frame = CGRect(x: x, y: self.collectionView!.contentOffset.y, width: (indexPath.section == 0 && tableView.hasRowHeaders ? rowHeaderWidth : columnWidth), height: columnHeaderHeight)

				case .RowHeader:
					let y = (indexPath.row == 0 && !tableView.hasColumnHeaders ? 0 : columnHeaderHeight) + (row * rowHeight) + (showGrid ? 1.0 * row: 0)
					frame = CGRect(x: self.collectionView!.contentOffset.x, y: y, width: rowHeaderWidth, height: rowHeight)

				case .Data:
					frame = CGRect(x: 0, y: 0, width: 0, height: 0)
				}

				attributes.zIndex = 3
			}

			attributes.frame = frame
		}

		return attributes
	}

	override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
		return true
	}
}

final class ALBTableViewGridView {
}

final class ALBTableViewHeaderShadowView: UIView {
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		backgroundColor = UIColor.lightGrayColor()
		alpha = 0.5
	}
}