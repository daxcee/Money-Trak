import Foundation

enum DefaultKey: String {
	case AmountAvailable = "amountAvailable"
	case DefaultAccount = "Default Account"
	case CheckPasscode = "passcodeChecked"
	case LastCheckDate = "lastProcessDate"
	case UpcomingBalanceScan
	case UpcomingTransactionScan
	case UpcomingTransactionsWarning = "upcomingTransactionsWarning"
}

class DefaultManager {
	func boolForKey(key: DefaultKey) -> Bool {
		return NSUserDefaults.standardUserDefaults().boolForKey(key.rawValue)
	}

	func integerForKey(key: DefaultKey) -> Int {
		return NSUserDefaults.standardUserDefaults().integerForKey(key.rawValue)
	}

	func objectForKey(key: DefaultKey) -> AnyObject? {
		return NSUserDefaults.standardUserDefaults().objectForKey(key.rawValue)
	}

	func stringForKey(key: DefaultKey) -> String? {
		return NSUserDefaults.standardUserDefaults().stringForKey(key.rawValue)
	}

	func setBool(value: Bool, forKey: DefaultKey) {
		NSUserDefaults.standardUserDefaults().setBool(value, forKey: forKey.rawValue)
	}

	func setInteger(value: Int, forKey: DefaultKey) {
		NSUserDefaults.standardUserDefaults().setInteger(value, forKey: forKey.rawValue)
		NSUserDefaults.resetStandardUserDefaults()
	}

	func setObject(value: AnyObject?, forKey: DefaultKey) {
		NSUserDefaults.standardUserDefaults().setObject(value, forKey: forKey.rawValue)
		NSUserDefaults.resetStandardUserDefaults()
	}

	func removeObjectForKey(key: DefaultKey) {
		NSUserDefaults.standardUserDefaults().removeObjectForKey(key.rawValue)
		NSUserDefaults.resetStandardUserDefaults()
	}
}