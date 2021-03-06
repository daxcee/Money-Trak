//
//  CozyLoadingActivity.swift
//  Cozy
//
//  Created by Goktug Yilmaz on 02/06/15.
//  Copyright (c) 2015 Goktug Yilmaz. All rights reserved.
//

import UIKit

struct CozyLoadingActivity {

	// ==========================================================================================================
	// Feel free to edit these variables
	// ==========================================================================================================
	struct Settings {
		static var CLABackgroundColor = UIColor(red: 227 / 255, green: 232 / 255, blue: 235 / 255, alpha: 1.0)
		static var CLAActivityColor = UIColor(red: 0 / 255, green: 0 / 255, blue: 0 / 255, alpha: 1.0)
		static var CLATextColor = UIColor(red: 80 / 255, green: 80 / 255, blue: 80 / 255, alpha: 1.0)
		static var CLAFontName = "HelveticaNeue-Light"
		// Other possible stuff: ✓ ✓ ✔︎ ✕ ✖︎ ✘
		static var CLASuccessIcon = "✔︎"
		static var CLAFailIcon = "✘"
		static var CLASuccessText = "Success"
		static var CLAFailText = "Failure"
		static var CLASuccessColor = UIColor(red: 68 / 255, green: 118 / 255, blue: 4 / 255, alpha: 1.0)
		static var CLAFailColor = UIColor(red: 255 / 255, green: 75 / 255, blue: 56 / 255, alpha: 1.0)
	}

	private static var instance: LoadingActivity?
	private static var hidingInProgress = false

	/// Disable UI stops users touch actions until CozyLoadingActivity is hidden. Return success status
	static func show(_ text: String, sender: UIViewController, disableUI: Bool) -> Bool {
		guard instance == nil else {
			print("CozyLoadingActivity: You still have an active activity, please stop that before creating a new one")
			return false
		}

		instance = LoadingActivity(text: text, sender: sender, disableUI: disableUI)
		return true
	}

	static func showWithDelay(_ text: String, sender: UIViewController, disableUI: Bool, seconds: Double) -> Bool {
		let showValue = show(text, sender: sender, disableUI: disableUI)
		delay(seconds) { () -> () in
			let _ = hide(success: true, animated: false)
		}
		return showValue
	}

	/// Returns success status
	static func hide(success: Bool, animated: Bool) -> Bool {
		guard instance != nil else {
			print("CozyLoadingActivity: You don't have an activity instance")
			return false
		}

		guard hidingInProgress == false else {
			print("CozyLoadingActivity: Hiding already in progress")
			return false
		}

		if !Thread.current.isMainThread {
			DispatchQueue.main.async {
				instance?.hideLoadingActivity(success: success, animated: animated)
			}
		} else {
			instance?.hideLoadingActivity(success: success, animated: animated)
		}
		return true
	}

	private static func delay(_ seconds: Double, after: @escaping () -> ()) {
		let queue = DispatchQueue.main
		let time = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
		queue.asyncAfter(deadline: time, execute: after)
	}

	private class LoadingActivity: UIView {
		var textLabel: UILabel!
		var activityView: UIActivityIndicatorView!
		var icon: UILabel!
		var UIDisabled = false

		convenience init(text: String, sender: UIViewController, disableUI: Bool) {
			let width = sender.view.frame.width / 1.6
			let height = width / 3
			self.init(frame: CGRect(x: sender.view.frame.midX - width / 2, y: sender.view.frame.midY - height / 2, width: width, height: height))
			backgroundColor = Settings.CLABackgroundColor
			alpha = 1
			layer.cornerRadius = 8
			createShadow()

			let yPosition = frame.height / 2 - 20

			activityView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
			activityView.frame = CGRect(x: 10, y: yPosition, width: 40, height: 40)
			activityView.color = Settings.CLAActivityColor
			activityView.startAnimating()

			textLabel = UILabel(frame: CGRect(x: 60, y: yPosition, width: width - 70, height: 40))
			textLabel.textColor = Settings.CLATextColor
			textLabel.font = UIFont(name: Settings.CLAFontName, size: 30)
			textLabel.adjustsFontSizeToFitWidth = true
			textLabel.minimumScaleFactor = 0.25
			textLabel.textAlignment = NSTextAlignment.center
			textLabel.text = text

			addSubview(activityView)
			addSubview(textLabel)

			sender.view.addSubview(self)

			if disableUI {
				UIApplication.shared.beginIgnoringInteractionEvents()
				UIDisabled = true
			}
		}

		func createShadow() {
			layer.shadowPath = createShadowPath().cgPath
			layer.masksToBounds = false
			layer.shadowColor = UIColor.black.cgColor
			layer.shadowOffset = CGSize(width: 0, height: 0)
			layer.shadowRadius = 5
			layer.shadowOpacity = 0.5
		}

		func createShadowPath() -> UIBezierPath {
			let myBezier = UIBezierPath()
			myBezier.move(to: CGPoint(x: -3, y: -3))
			myBezier.addLine(to: CGPoint(x: frame.width + 3, y: -3))
			myBezier.addLine(to: CGPoint(x: frame.width + 3, y: frame.height + 3))
			myBezier.addLine(to: CGPoint(x: -3, y: frame.height + 3))
			myBezier.close()
			return myBezier
		}

		func hideLoadingActivity(success: Bool, animated: Bool) {
			hidingInProgress = true
			if UIDisabled {
				UIApplication.shared.endIgnoringInteractionEvents()
			}

			var animationDuration: Double!
			if success {
				animationDuration = 0.5
			} else {
				animationDuration = 1
			}

			icon = UILabel(frame: CGRect(x: 10, y: frame.height / 2 - 20, width: 40, height: 40))
			icon.font = UIFont(name: Settings.CLAFontName, size: 60)
			icon.textAlignment = NSTextAlignment.center

			if animated {
				textLabel.fadeTransition(animationDuration)
			}

			if success {
				icon.textColor = Settings.CLASuccessColor
				icon.text = Settings.CLASuccessIcon
				textLabel.text = Settings.CLASuccessText
			} else {
				icon.textColor = Settings.CLAFailColor
				icon.text = Settings.CLAFailIcon
				textLabel.text = Settings.CLAFailText
			}
			addSubview(icon)

			if animated {
				icon.alpha = 0
				activityView.stopAnimating()
				UIView.animate(withDuration: animationDuration, animations: {
					self.icon.alpha = 1
					}, completion: { (value: Bool) in
					self.callSelectorAsync(#selector(self.removeFromSuperview), delay: animationDuration)
					instance = nil
					hidingInProgress = false
				})
			} else {
				activityView.stopAnimating()
				self.callSelectorAsync(#selector(removeFromSuperview), delay: animationDuration)
				instance = nil
				hidingInProgress = false
			}
		}
	}
}

private extension UIView {
	/// Cozy extension: insert view.fadeTransition right before changing content
	func fadeTransition(_ duration: CFTimeInterval) {
		let animation: CATransition = CATransition()
		animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
		animation.type = kCATransitionFade
		animation.duration = duration
		self.layer.add(animation, forKey: kCATransitionFade)
	}
}

private extension NSObject {
	/// Cozy extension
	func callSelectorAsync(_ selector: Selector, delay: TimeInterval) {
		let timer = Timer.scheduledTimer(timeInterval: delay, target: self, selector: selector, userInfo: nil, repeats: false)
		RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
	}
}
