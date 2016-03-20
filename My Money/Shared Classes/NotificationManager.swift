import Foundation

enum NotificationName: String {
	case SessionRefreshed
    case PushNotificationPerformAction
    case PushNotificationPresentPushAlert
}

class NotificationManager {
	private var observers = [AnyObject]()

	deinit {
        reset()
	}
	
    func reset() {
        for observer in observers {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }
    
	/**
		Posts a notification with the given name and optional userInfo throught the defaultCenter
		- parameter name: NotificationName from enumeration
		- parameter userInfo: (optional) dictionary of information to be passed in the notification
	*/
	func postNotificationWithName(name: NotificationName, userInfo: [NSObject: AnyObject]? = nil) {
		NSNotificationCenter.defaultCenter().postNotificationName(name.rawValue, object: nil, userInfo: userInfo)
	}
	
	/**
		Adds a notification observer with the given name and a block to perform when the notification is received
		- parameter name: NotificationName from enumeration
		- parameter block: code to be executed when notification is received. Notification recevied is the passed parameter.
	*/
	func addObserverForName(name: NotificationName, block:(NSNotification) -> Void) {
		observers.append(NSNotificationCenter.defaultCenter().addObserverForName(name.rawValue, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: block))
	}
}

extension NSNotificationCenter {
	/**
	Posts a notification with the given name and optional userInfo throught the defaultCenter
	- parameter name: NotificationName from enumeration
	- parameter userInfo: (optional) dictionary of information to be passed in the notification
	*/
	static func postNotificationWithName(name: NotificationName, userInfo: [NSObject : AnyObject]? = nil) {
		NSNotificationCenter.defaultCenter().postNotificationName(name.rawValue, object: nil, userInfo: userInfo)
	}
}