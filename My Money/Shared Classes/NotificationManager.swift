import Foundation

enum NotificationName: String {
	case SessionRefreshed
	case PushNotificationPerformAction
	case PushNotificationPresentPushAlert
}

class NotificationManager {
	private var observers = [String: AnyObject]()

	deinit {
		reset()
	}

	func reset() {
		for observer in observers.values {
			NSNotificationCenter.defaultCenter().removeObserver(observer)
		}
	}

	func observerCount() -> Int {
		return observers.count
	}

	/**
	 Posts a notification with the given name and optional userInfo through the defaultCenter
	 - parameter name: NotificationName from enumeration
	 - parameter userInfo: (optional) dictionary of information to be passed in the notification
	 */
	func postNotificationWithName(name: NotificationName, userInfo: [NSObject: AnyObject]? = nil) {
		NSNotificationCenter.defaultCenter().postNotificationName(name.rawValue, object: nil, userInfo: userInfo)
	}

	/**
	 Posts a notification with the given name and optional userInfo through the defaultCenter
	 - parameter name: Name of notification that is not enumerated.
	 - parameter userInfo: (optional) dictionary of information to be passed in the notification
	 */
	func postNotificationWithName(name: String, userInfo: [NSObject: AnyObject]? = nil) {
		NSNotificationCenter.defaultCenter().postNotificationName(name, object: nil, userInfo: userInfo)
	}

	/**
	 Adds a notification observer with the given name and a block to perform when the notification is received
	 - parameter name: NotificationName from enumeration
	 - parameter block: code to be executed when notification is received. Notification recevied is the passed parameter.
	 */
	func addObserverForName(name: NotificationName, block: (NSNotification) -> Void) {
		// make sure observer isn't already in place
		guard observers[name.rawValue] == nil else { return }

		let observer = NSNotificationCenter.defaultCenter().addObserverForName(name.rawValue, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: block)
		observers[name.rawValue] = observer
	}

	/**
	 Adds a notification observer with the given name and a block to perform when the notification is received
	 - parameter name: Name of notification that is not enumerated
	 - parameter block: code to be executed when notification is received. Notification recevied is the passed parameter.
	 */
	func addObserverForName(name: String, block: (NSNotification) -> Void) {
		// make sure observer isn't already in place
		guard observers[name] == nil else { return }

		let observer = NSNotificationCenter.defaultCenter().addObserverForName(name, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: block)
		observers[name] = observer
	}

	/**
	 Removes a notification with the given name
	 - parameter name: NotificationName from enumeration
	 */
	func removeObserverForName(name: NotificationName) {
		guard let observer = observers[name.rawValue] else { return }

		NSNotificationCenter.defaultCenter().removeObserver(observer)
		observers.removeValueForKey(name.rawValue)
	}

	/**
	 Removes a notification with the given name
	 - parameter name: Name of notification that is not enumerated
	 */
	func removeObserverForName(name: String) {
		guard let observer = observers[name] else { return }

		NSNotificationCenter.defaultCenter().removeObserver(observer)
		observers.removeValueForKey(name)
	}
}

extension NSNotificationCenter {
	/**
	 Posts a notification with the given name and optional userInfo throught the defaultCenter
	 - parameter name: NotificationName from enumeration
	 - parameter userInfo: (optional) dictionary of information to be passed in the notification
	 */
	static func postNotificationWithName(name: NotificationName, userInfo: [NSObject: AnyObject]? = nil) {
		NSNotificationCenter.defaultCenter().postNotificationName(name.rawValue, object: nil, userInfo: userInfo)
	}
}