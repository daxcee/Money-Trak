import Foundation

enum DefaultKey: String {
	case amountAvailable = "amountAvailable"
	case defaultAccount = "Default Account"
	case checkPasscode = "passcodeChecked"
	case lastCheckDate = "lastProcessDate"
	case upcomingBalanceScan
	case upcomingTransactionScan
	case upcomingTransactionsWarning = "upcomingTransactionsWarning"
}

class DefaultManager {
	func boolForKey(_ key: DefaultKey) -> Bool {
		return UserDefaults.standard.bool(forKey: key.rawValue)
	}

	func integerForKey(_ key: DefaultKey) -> Int {
		return UserDefaults.standard.integer(forKey: key.rawValue)
	}

	func objectForKey(_ key: DefaultKey) -> Any? {
		return UserDefaults.standard.object(forKey: key.rawValue)
	}

	func stringForKey(_ key: DefaultKey) -> String? {
		return UserDefaults.standard.string(forKey: key.rawValue)
	}

	func setBool(_ value: Bool, forKey: DefaultKey) {
		UserDefaults.standard.set(value, forKey: forKey.rawValue)
	}

	func setInteger(_ value: Int, forKey: DefaultKey) {
		UserDefaults.standard.set(value, forKey: forKey.rawValue)
		UserDefaults.resetStandardUserDefaults()
	}

	func setObject(_ value: AnyObject?, forKey: DefaultKey) {
		UserDefaults.standard.set(value, forKey: forKey.rawValue)
		UserDefaults.resetStandardUserDefaults()
	}

	func removeObjectForKey(_ key: DefaultKey) {
		UserDefaults.standard.removeObject(forKey: key.rawValue)
		UserDefaults.resetStandardUserDefaults()
	}
}
