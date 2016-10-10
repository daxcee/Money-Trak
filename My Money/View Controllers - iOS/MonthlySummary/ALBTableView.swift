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
	func numberOfColumns(_ tableView: ALBTableView) -> Int
	func columnWidth(_ tableView: ALBTableView) -> CGFloat

	// Column Headers
	func heightOfColumnHeaders(_ tableView: ALBTableView) -> CGFloat
	func columnHeaderCell(_ tableView: ALBTableView, column: Int) -> UICollectionViewCell

	// Rows
	func numberOfRows(_ tableView: ALBTableView) -> Int
	func rowHeight(_ tableView: ALBTableView) -> CGFloat

	// Row Headers
	func widthOfRowHeaderCells(_ tableView: ALBTableView) -> CGFloat
	func rowHeaderCell(_ tableView: ALBTableView, row: Int) -> UICollectionViewCell

	// Data Cells
	func dataCell(_ tableView: ALBTableView, column: Int, row: Int) -> UICollectionViewCell
}

protocol ALBTableViewDelegate {
	func didSelectColumn(_ tableView: ALBTableView, column: Int)
	func didDeselectColumn(_ tableView: ALBTableView, column: Int)

	func didSelectRow(_ tableView: ALBTableView, row: Int)
	func didDeselectRow(_ tableView: ALBTableView, row: Int)

	func didSelectCell(_ tableView: ALBTableView, column: Int, row: Int)
	func didDeselectCell(_ tableView: ALBTableView, column: Int, row: Int)
}

enum ALBTableViewCellType: String {
	case dataCell
	case columnHeader
	case rowHeader
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

	var gridColor = UIColor.lightGray {
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

	fileprivate var collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), collectionViewLayout: ALBTableViewLayout())
	fileprivate var columns = 0
	fileprivate var rows = 0

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

		let viewsDictionary: [String: UIView] = ["collectionView": collectionView]

		let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[collectionView]-0-|", options: NSLayoutFormatOptions.directionLeftToRight, metrics: nil, views: viewsDictionary)

		let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[collectionView]-0-|", options: NSLayoutFormatOptions.directionLeftToRight, metrics: nil, views: viewsDictionary)

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

	func zoom(_ recognizer: UIPinchGestureRecognizer) {
		print("zooming...")
	}

	func reloadData() {
		if let dataSource = dataSource {
			if showGrid {
				backgroundColor = gridColor
			} else {
				backgroundColor = UIColor.white
			}

			columns = dataSource.numberOfColumns(self)
			rows = dataSource.numberOfRows(self)

			collectionView.collectionViewLayout.invalidateLayout()
		}
	}

	// MARK: - Register Cell NIBs
	func registerDataCellNib(_ nib: UINib) {
		collectionView.register(nib, forCellWithReuseIdentifier: ALBTableViewCellType.dataCell.rawValue)
	}

	func registerColumnHeaderNib(_ nib: UINib) {
		collectionView.register(nib, forSupplementaryViewOfKind: ALBTableViewCellType.columnHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.columnHeader.rawValue)
	}

	func registerRowHeaderNib(_ nib: UINib) {
		collectionView.register(nib, forSupplementaryViewOfKind: ALBTableViewCellType.rowHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.rowHeader.rawValue)
	}

	// MARK: - Dequeue Cells
	func dequeDataCellForColumn(_ column: Int, row: Int) -> UICollectionViewCell {
		let indexPath = IndexPath(row: row, section: column)

		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ALBTableViewCellType.dataCell.rawValue, for: indexPath)
		return cell
	}

	func dequeueColumnHeaderForColumn(_ column: Int) -> UICollectionViewCell {
		let indexPath = IndexPath(row: 0, section: column)

		let cell = collectionView.dequeueReusableSupplementaryView(ofKind: ALBTableViewCellType.columnHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.columnHeader.rawValue, for: indexPath) as! UICollectionViewCell

		return cell
	}

	func dequeueRowHeaderForRow(_ row: Int) -> UICollectionViewCell {
		let indexPath = IndexPath(row: row, section: 0)

		let cell = collectionView.dequeueReusableSupplementaryView(ofKind: ALBTableViewCellType.rowHeader.rawValue, withReuseIdentifier: ALBTableViewCellType.rowHeader.rawValue, for: indexPath) as! UICollectionViewCell

		return cell
	}

	// MARK: - Public Select / Deselect Methods
	func selectCell(_ column: Int, row: Int) {
	}

	func selectColumn(_ column: Int) {
	}

	func selectRow(_ row: Int) {
	}

	func deselectCell(_ column: Int, row: Int) {
	}

	func deselectColumn(_ column: Int) {
	}

	func deselectRow(_ column: Int) {
	}
}

extension ALBTableView: UICollectionViewDataSource {
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return columns
	}

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return rows
	}

	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		if let dataSource = dataSource {
			let cell: UICollectionViewCell

			let headerType = ALBTableViewCellType(rawValue: kind)!
			switch headerType {
			case .columnHeader:
				cell = dataSource.columnHeaderCell(self, column: (indexPath as NSIndexPath).section)

			case .rowHeader:
				cell = dataSource.rowHeaderCell(self, row: (indexPath as NSIndexPath).row)

			case .dataCell:
				cell = UICollectionViewCell()
			}

			return cell
		}

		return UICollectionViewCell()
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		if let dataSource = dataSource {
			let cell = dataSource.dataCell(self, column: (indexPath as NSIndexPath).section, row: (indexPath as NSIndexPath).row)
			return cell
		}

		return UICollectionViewCell()
	}
}

extension ALBTableView: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		delegate?.didSelectCell(self, column: (indexPath as NSIndexPath).section, row: (indexPath as NSIndexPath).row)
	}

	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		delegate?.didDeselectCell(self, column: (indexPath as NSIndexPath).section, row: (indexPath as NSIndexPath).row)
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

	override func prepare() {
		if let tableView = tableView, let dataSource = tableView.dataSource {
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
	override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
		if let tableView = tableView {
			lastRect = rect
			var attributes = [UICollectionViewLayoutAttributes]()
			let columnCount = tableView.columns
			let rowCount = tableView.rows

			if columnCount == 0 || rowCount == 0 {
				return nil
			}

			if tableView.hasColumnHeaders && tableView.hasRowHeaders {
				let indexPath = IndexPath(row: 0, section: -1)
				if let columnHeaderAttributes = layoutAttributesForSupplementaryView(ofKind: ALBTableViewCellType.columnHeader.rawValue, at: indexPath) {
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
					let indexPath = IndexPath(row: row, section: column)
					let frame = frameAtIndexPath(indexPath, tableView: tableView)

					if frame.intersects(rect) {
						let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
						layoutAttributes.frame = frame
						layoutAttributes.zIndex = 1
						attributes.append(layoutAttributes)

						if tableView.hasColumnHeaders {
							if let columnHeaderAttributes = layoutAttributesForSupplementaryView(ofKind: ALBTableViewCellType.columnHeader.rawValue, at: indexPath) {
								attributes.append(columnHeaderAttributes)
							}
						}

						if tableView.hasRowHeaders {
							if let rowHeaderAttributes = layoutAttributesForSupplementaryView(ofKind: ALBTableViewCellType.rowHeader.rawValue, at: indexPath) {
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

	override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
		let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
		if let tableView = tableView {
			attributes.frame = frameAtIndexPath(indexPath, tableView: tableView)
			attributes.zIndex = 1
		}

		return attributes
	}

	private func frameAtIndexPath(_ indexPath: IndexPath, tableView: ALBTableView) -> CGRect {
		let column = CGFloat((indexPath as NSIndexPath).section)
		let row = CGFloat((indexPath as NSIndexPath).row)

		let x: CGFloat = (tableView.hasRowHeaders ? rowHeaderWidth : (tableView.showGrid ? 1 : 0)) + (column * columnWidth) + (tableView.showGrid ? 1.0 * column: 0)
		let y: CGFloat = (tableView.hasColumnHeaders ? columnHeaderHeight : (tableView.showGrid ? 1 : 0)) + (row * rowHeight) + (tableView.showGrid ? 1.0 * row: 0)

		let frame = CGRect(x: x, y: y, width: columnWidth, height: rowHeight)

		return frame
	}

	// MARK: - Other layout
	override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
		let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind, with: indexPath)
		if let tableView = tableView {
			let column = CGFloat((indexPath as NSIndexPath).section)
			let row = CGFloat((indexPath as NSIndexPath).row)
			let showGrid = tableView.showGrid
			let frame: CGRect

			if (indexPath as NSIndexPath).row == 0 && (indexPath as NSIndexPath).section == -1 {
				frame = CGRect(x: self.collectionView!.contentOffset.x, y: self.collectionView!.contentOffset.y, width: rowHeaderWidth, height: columnHeaderHeight)
				attributes.zIndex = 4
			} else {
				let headerType = ALBTableViewCellType(rawValue: elementKind)!
				switch headerType {
				case .columnHeader:
					let x = ((indexPath as NSIndexPath).section == 0 && !tableView.hasRowHeaders ? 0 : rowHeaderWidth) + (column * columnWidth) + (showGrid ? 1.0 * column: 0)
					frame = CGRect(x: x, y: self.collectionView!.contentOffset.y, width: ((indexPath as NSIndexPath).section == 0 && tableView.hasRowHeaders ? rowHeaderWidth : columnWidth), height: columnHeaderHeight)

				case .rowHeader:
					let y = ((indexPath as NSIndexPath).row == 0 && !tableView.hasColumnHeaders ? 0 : columnHeaderHeight) + (row * rowHeight) + (showGrid ? 1.0 * row: 0)
					frame = CGRect(x: self.collectionView!.contentOffset.x, y: y, width: rowHeaderWidth, height: rowHeight)

				case .dataCell:
					frame = CGRect(x: 0, y: 0, width: 0, height: 0)
				}

				attributes.zIndex = 3
			}

			attributes.frame = frame
		}

		return attributes
	}

	override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
		return true
	}
}

final class ALBTableViewGridView {
}

final class ALBTableViewHeaderShadowView: UIView {
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		backgroundColor = UIColor.lightGray
		alpha = 0.5
	}
}
