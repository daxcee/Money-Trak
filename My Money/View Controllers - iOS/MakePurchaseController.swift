//
//  MakePurchaseController.swift
//  My Money
//
//  Created by Aaron Bratcher on 7/18/15.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit
import StoreKit

class MakePurchaseController: UIViewController {
	var products: [SKProduct]?
	
	@IBOutlet weak var collectionView: UICollectionView!
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		collectionView.backgroundColor = UIColor.clearColor()
	}
	
	
	@IBAction func cancelTapped(sender: AnyObject) {
		dismissViewControllerAnimated(true, completion: nil)
	}
	
	
	@IBAction func restorePurchases(sender: AnyObject) {
		dismissViewControllerAnimated(true, completion: {() -> Void in
				if self.products != nil {
					PurchaseKit.sharedInstance.restorePurchases()
				}
			})
		
	}
}

extension MakePurchaseController: UICollectionViewDataSource {
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if let products = products {
			return products.count
		}
		
		return 0
	}
	
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Product", forIndexPath: indexPath) as! ProductCell
		cell.product = products![indexPath.row]
		
		return cell
	}
}

extension MakePurchaseController: UICollectionViewDelegate {
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		dismissViewControllerAnimated(true, completion: {() -> Void in
				if let products = self.products {
					PurchaseKit.sharedInstance.purchaseProduct(products[indexPath.row])
				}
			})
	}
}

extension MakePurchaseController: UICollectionViewDelegateFlowLayout {
	func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
		
		let layout = collectionViewLayout as! UICollectionViewFlowLayout
		let cellCount = CGFloat(collectionView.numberOfItemsInSection(section))
		if cellCount > 0 {
			let cellWidth = layout.itemSize.width + layout.minimumInteritemSpacing
			let totalCellWidth = cellWidth * cellCount
			let contentWidth = collectionView.frame.size.width - collectionView.contentInset.left - collectionView.contentInset.right
			let contentHeight = collectionView.frame.size.height - collectionView.contentInset.top - collectionView.contentInset.bottom
			if totalCellWidth < contentWidth {
				let hPadding = (contentWidth - totalCellWidth) / 2.0
				let vPadding = (contentHeight - layout.itemSize.height) / 2.0
				return UIEdgeInsets(top: vPadding, left: hPadding, bottom: vPadding, right: hPadding)
			}
		}
		
		return UIEdgeInsetsZero
	}
}


class ProductCell: UICollectionViewCell {
	@IBOutlet weak var productName: UILabel!
	@IBOutlet weak var productDescription: UILabel!
	@IBOutlet weak var productPrice: UILabel!
	
	var product: SKProduct {
		set(newProduct) {
			_product = newProduct
			
			let formatter = NSNumberFormatter()
			formatter.numberStyle = NSNumberFormatterStyle.CurrencyStyle
			formatter.locale = newProduct.priceLocale
			
			productName.text = newProduct.localizedTitle
			productDescription.text = newProduct.localizedDescription
			productPrice.text = formatter.stringFromNumber(newProduct.price)
		}
		
		get {
			return _product
		}
	}
	
	private var _product: SKProduct!
}