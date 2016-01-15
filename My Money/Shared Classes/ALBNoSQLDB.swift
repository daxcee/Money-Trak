//
//  ALBNoSQLDB.swift
//
//  Created by Aaron Bratcher on 01/08/2015.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation

// MARK: - String Extensions
extension String {
	func dataValue() -> NSData {
		return self.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
	}
}

// MARK: - Definitions
enum DBConditionOperator: String {
	case equal = "="
	case notEqual = "<>"
	case lessThan = "<"
	case greaterThan = ">"
	case lessThanOrEqual = "<="
	case greaterThanOrEqual = ">="
	case contains = "..."
	case inList = "()"
}

struct DBCondition {
	var set = 0
	var objectKey = ""
	var conditionOperator = DBConditionOperator.equal
	var value: AnyObject
}

class ALBNoSQLDBObject {
	var key: String
	
	convenience init() {
		self.init(keyValue: ALBNoSQLDB.guid(), dictValue: nil)
	}
	
	init(keyValue: String, dictValue: [String: AnyObject]? = nil) {
		self.key = keyValue
	}
	
	func dictionaryValue() -> [String: AnyObject] {
		let emptyDict = [String: AnyObject]()
		return emptyDict
	}
	
	func jsonValue() -> String {
		let dataValue = try? NSJSONSerialization.dataWithJSONObject(dictionaryValue(), options: NSJSONWritingOptions(rawValue: 0))
		let stringValue = NSString(data: dataValue!, encoding: NSUTF8StringEncoding)
		return stringValue! as String
	}
}

// MARK: - Class Definition
final class ALBNoSQLDB {
	enum ValueType: String {
		case stringArray = "stringArray"
		, intArray = "intArray"
		, doubleArray = "doubleArray"
		, string = "text"
		, int = "int"
		, double = "double"
		, unknown = "unknown"
	}
	
	private var _dbFileLocation: NSURL?
	private var _dbInstanceKey = ""
	private var _tables = [String]()
	private var _sqliteDB: COpaquePointer = nil
	private var _indexes = [String: [String]]()
	private let _dbQueue = dispatch_queue_create("com.AaronLBratcher.ALBNoSQLDBQueue", nil)
	private var _syncingEnabled = false
	private var _unsyncedTables = [String]()
	private let _dateFormatter: NSDateFormatter
	private let _deletionQueue = dispatch_queue_create("com.AaronLBratcher.ALBNoSQLDBDeletionQueue", nil)
	private let _autoDeleteTimer: dispatch_source_t
	
	private let SQLITE_TRANSIENT = unsafeBitCast(-1, sqlite3_destructor_type.self)
	
	// MARK: - File Location
	/**
	 Sets the location of the database file.

	 - parameter location: The file location.
	 */
	class func setFileLocation(location: NSURL) {
		let db = ALBNoSQLDB.sharedInstance
		db._dbFileLocation = location
	}
	
	// MARK: - Keys
	/**
	 Checks if the given table contains the given key.

	 - parameter table: The table to search.
	 - parameter key: The key to look for.

	 - returns: Bool? Returns if the key exists in the table. Is nil when database could not be opened or other error occured.
	 */
	class func tableHasKey(table table: String, key: String) -> Bool? {
		let db = ALBNoSQLDB.sharedInstance
		assert(table != "", "table name must be provided")
		assert(!db.reservedTable(table), "reserved table")
		
		if !db.openDB() {
			return nil
		}
		
		if db._tables.filter({$0 == table}).count == 0 {
			return false
		}
		
		let sql = "select 1 from \(table) where key = '\(key)'"
		let results = db.sqlSelect(sql)
		if let results = results {
			return results.count > 0
		}
		
		return nil
	}
	
	/**
	 Returns an array of keys from the given table sorted in the way specified.

	 Example:

	 if let keys = ALBNoSQLDB.keysInTable("table1",sortOrder:"date desc, amount asc") {
	 // use keys
	 } else {
	 // handle error
	 }

	 - parameter table: The table to return keys from.
	 - parameter sortOrder: Optional string that gives a comma delimited list of properties to sort by

	 - returns: [String]? Returns an array of keys from the table. Is nil when database could not be opened or other error occured.
	 */
	class func keysInTable(table: String, sortOrder: String?) -> [String]? {
		let db = ALBNoSQLDB.sharedInstance
		assert(table != "", "table name must be provided")
		assert(!db.reservedTable(table), "reserved table")
		
		if !db.openDB() {
			return nil
		}
		
		if db._tables.filter({$0 == table}).count == 0 {
			return []
		}
		
		var sql = "select key from \(table)"
		
		if let sortOrder = sortOrder {
			sql += " order by \(sortOrder)"
		}
		
		let results = db.sqlSelect(sql)
		if let results = results {
			return results.map({$0.values[0] as! String})
		}
		
		return nil
	}
	
	/**
	 Returns an array of keys from the given table sorted in the way specified matching the given conditions. All conditions in the same set are ANDed together. Separate sets are ORed against each other.  (set:0 AND set:0 AND set:0) OR (set:1 AND set:1 AND set:1) OR (set:2)

	 Unsorted Example:

	 let accountCondition = DBCondition(set:0,objectKey:"account",conditionOperator:.equal, value:"ACCT1")
	 if let keys = ALBNoSQLDB.keysInTableForConditions("table1", sortOrder:nil, conditions:accountCondition) {
	 // use keys
	 } else {
	 // handle error
	 }

	 - parameter table: The table to return keys from.
	 - parameter sortOrder: Optional string that gives a comma delimited list of properties to sort by
	 - parameter conditions: Array of DBConditions that specify what conditions must be met.

	 - returns: [String]? Returns an array of keys from the table. Is nil when database could not be opened or other error occured.
	 */
	class func keysInTableForConditions(table: String, sortOrder: String?, conditions: [DBCondition]) -> [String]? {
		let db = ALBNoSQLDB.sharedInstance
		
		assert(table != "", "table name must be provided")
		assert(!db.reservedTable(table), "reserved table")
		
		if !db.openDB() {
			return nil
		}
		
		if !db.hasTable(table) {
			return []
		}
		
		var arrayColumns = [String]()
		if let results = db.sqlSelect("select arrayColumns from __tableArrayColumns where tableName = '\(table)'") {
			if results.count > 0 {
				arrayColumns = (results[0].values[0] as! String).characters.split {$0 == ","}.map {String($0)}
			}
		} else {
			return nil
		}
		
		let tableColumns = db.columnsInTable(table).map({$0.name}) + ["key"]
		
		var selectClause = "select distinct a.key from \(table) a"
		// if we have the include operator on an array object, do a left outer join
		for condition in conditions {
			if condition.conditionOperator == .contains && arrayColumns.filter({$0 == condition.objectKey}).count == 1 {
				selectClause += " left outer join \(table)_arrayValues b on a.key = b.key"
				break
			}
		}
		
		var conditionSet = conditions
		var whereClause = " where 1=1"
		if conditionSet.count > 0 {
			whereClause += " AND ("
			// order the conditions array by page
			conditionSet.sortInPlace {$0.set < $1.set}
			
			// conditionDict: ObjectKey,operator,value
			
			var currentSet = conditions[0].set
			var inPage = true
			var inMultiPage = false
			var firstConditionInSet = true
			let hasMultipleSets = conditions.filter({$0.set != conditions[0].set}).count > 0
			
			for condition in conditionSet {
				if tableColumns.filter({$0 == condition.objectKey}).count == 0 && arrayColumns.filter({$0 == condition.objectKey}).count == 0 {
					print("\(condition.objectKey) doesn't exist")
					return []
				}
				
				let valueType = db.typeOfValue(condition.value)
				
				if currentSet != condition.set {
					currentSet = condition.set
					whereClause += ")"
					if inMultiPage {
						inMultiPage = false
						whereClause += ")"
					}
					whereClause += " OR ("
					
					inMultiPage = false
				} else {
					inPage = true
					if firstConditionInSet {
						firstConditionInSet = false
						if hasMultipleSets {
							whereClause += " ("
						}
					} else {
						if inMultiPage {
							whereClause += ")"
						}
						
						whereClause += " and key in (select key from \(table) where"
						inMultiPage = true
					}
				}
				
				switch condition.conditionOperator {
				case .contains:
					if arrayColumns.filter({$0 == condition.objectKey}).count > 0 {
						switch valueType {
						case .string:
							whereClause += "b.objectKey = '\(condition.objectKey)' and b.stringValue = '\(db.esc(condition.value as! String))'"
						case .int:
							whereClause += "b.objectKey = '\(condition.objectKey)' and b.intValue = \(condition.value)"
						case .double:
							whereClause += "b.objectKey = '\(condition.objectKey)' and b.doubleValue = \(condition.value)"
						default:
							break
						}
					} else {
						whereClause += " \(condition.objectKey) like '%%\(db.esc(condition.value as! String))%%'"
					}
				case .inList:
					whereClause += " \(condition.objectKey)  in ("
					if let stringArray = condition.value as? [String] {
						for value in stringArray {
							whereClause += "'\(db.esc(value))'"
						}
						whereClause += ")"
					} else {
						if let intArray = condition.value as? [Int] {
							for value in intArray {
								whereClause += "\(value)"
							}
							whereClause += ")"
						} else {
							for value in condition.value as! [Double] {
								whereClause += "\(value)"
							}
							whereClause += ")"
						}
					}
				
				default:
					if let _ = condition.value as? String {
						whereClause += " \(condition.objectKey) \(condition.conditionOperator.rawValue) '\(db.esc(condition.value as! String))'"
					} else {
						whereClause += " \(condition.objectKey) \(condition.conditionOperator.rawValue) \(condition.value)"
					}
				}
			}
			
			whereClause += ")"
			
			if inMultiPage {
				whereClause += ")"
			}
			
			if inPage && hasMultipleSets {
				whereClause += ")"
				inPage = false
			}
		}
		
		if let sortOrder = sortOrder {
			whereClause += " order by \(sortOrder)"
		}
		
		let sql = selectClause + whereClause
		// println(sql)
		if let results = db.sqlSelect(sql) {
			return results.map({$0.values[0] as! String})
		}
		
		return nil
	}
	
	// MARK: - Indexing
	/**
	 Sets the indexes desired for a given table.

	 Example:

	 ALBNoSQLDB.setTableIndexes(table: kTransactionsTable, indexes: ["accountKey","date"]) // index accountKey and date each individually

	 - parameter table: The table to return keys from.
	 - parameter indexes: An array of table properties to be indexed. An array can be compound.
	 */
	class func setTableIndexes(table table: String, indexes: [String]) {
		let db = ALBNoSQLDB.sharedInstance
		db._indexes[table] = indexes
		if db.openDB() {
			db.createIndexesForTable(table)
		}
	}
	
	
	// MARK: - Set Values
	/**
	 Sets the value of an entry in the given table for a given key optionally deleted automatically after a given date. Supported values are dictionaries that consist of String, Int, Double and arrays of these. If more complex objects need to be stored, a string value of those objects need to be stored.

	 Example:

	 if !ALBNoSQLDB.setValue(table: "table5", key: "testKey1", value: "{\"numValue\":1,\"account\":\"ACCT1\",\"dateValue\":\"2014-8-19T18:23:42.434-05:00\",\"arrayValue\":[1,2,3,4,5]}", autoDeleteAfter: nil) {
	 // handle error
	 }

	 - parameter table: The table to return keys from.
	 - parameter key: The key for the entry.
	 - parameter value: A JSON string representing the value to be stored. Top level object provided must be a dictionary.
	 - parameter autoDeleteAfter: Optional date of when the value should be automatically deleted from the table.

	 - returns: Bool If the value was set successfully.
	 */
	class func setValue(table table: String, key: String, value: String, autoDeleteAfter: NSDate? = nil) -> Bool {
		let db = ALBNoSQLDB.sharedInstance
		assert(table != "", "table name must be provided")
		assert(!db.reservedTable(table), "reserved table")
		assert(key != "", "key must be provided")
		assert(value != "", "value must be provided")
		
		let dataValue = value.dataUsingEncoding(NSUTF8StringEncoding)
		let objectValues = (try? NSJSONSerialization.JSONObjectWithData(dataValue!, options: NSJSONReadingOptions.MutableContainers)) as? [String: AnyObject]
		assert(objectValues != nil, "Value must be valid JSON string that is a dictionary for the top-level object")
		
		let now = ALBNoSQLDB.stringValueForDate(NSDate())
		let deleteDateTime = (autoDeleteAfter == nil ? "NULL" : "'" + ALBNoSQLDB.stringValueForDate(autoDeleteAfter!) + "'")
		
		return db.setValue(table: table, key: key, objectValues: objectValues!, addedDateTime: now, updatedDateTime: now, deleteDateTime: deleteDateTime, sourceDB: db._dbInstanceKey, originalDB: db._dbInstanceKey)
	}
	
	// MARK: - Return Values
	/**
	 Returns the JSON value of what was stored for a given table and key.

	 Example:
	 if let jsonValue = ALBNoSQLDB.valueForKey(table: "table1", key: "58D200A048F9") {
	 // process JSON text
	 } else {
	 // handle error
	 }

	 - parameter table: The table to return keys from.
	 - parameter key: The key for the entry.

	 - returns: String? JSON value of what was stored. Is nil when database could not be opened or other error occured.
	 */
	class func valueForKey(table table: String, key: String) -> String? {
		if let dictionaryValue = dictValueForKey(table: table, key: key) {
			let dataValue = try? NSJSONSerialization.dataWithJSONObject(dictionaryValue, options: NSJSONWritingOptions(rawValue: 0))
			let jsonValue = NSString(data: dataValue!, encoding: NSUTF8StringEncoding)
			return jsonValue! as String
		}
		
		return nil
	}
	
	/**
	 Returns the JSON value of what was stored for a given table and key.

	 Example:
	 if let dictValue = ALBNoSQLDB.dictValueForKey(table: "table1", key: "58D200A048F9") {
	 // process dictionary
	 } else {
	 // handle error
	 }

	 - parameter table: The table to return keys from.
	 - parameter key: The key for the entry.

	 - returns: [String:AnyObject]? Dictionary value of what was stored. Is nil when database could not be opened or other error occured.
	 */
	class func dictValueForKey(table table: String, key: String) -> [String: AnyObject]? {
		let db = ALBNoSQLDB.sharedInstance
		
		assert(table != "", "table name must be provided")
		assert(key != "", "key value must be provided")
		assert(!db.reservedTable(table), "reserved table")
		
		return db.dictValueForKey(table: table, key: key, includeDates: false)
	}
	
	
	// MARK: - Delete
	/**
	 Delete the value from the given table for the given key.

	 - parameter table: The table to return keys from.
	 - parameter key: The key for the entry.

	 - returns: Bool Value was successfuly removed.
	 */
	class func deleteForKey(table table: String, key: String) -> Bool {
		let db = ALBNoSQLDB.sharedInstance
		
		assert(table != "", "table name must be provided")
		assert(!db.reservedTable(table), "reserved table")
		assert(key != "", "key must be provided")
		
		return db.deleteForKey(table: table, key: key, autoDelete: false, sourceDB: db._dbInstanceKey, originalDB: db._dbInstanceKey)
	}
	
	
	/**
	 Removes the given table and associated values.

	 - parameter table: The table to return keys from.

	 - returns: Bool Table was successfuly removed.
	 */
	class func dropTable(table: String) -> Bool {
		let db = ALBNoSQLDB.sharedInstance
		assert(table != "", "table name must be provided")
		assert(!db.reservedTable(table), "reserved table")
		
		if !db.openDB() {
			return false
		}
		
		if !db.sqlExecute("drop table \(table)")
		|| !db.sqlExecute("drop table \(table)_arrayValues")
		|| !db.sqlExecute("delete from __tableArrayColumns where tableName = '\(table)'") {
			return false
		}
		
		db._tables = db._tables.filter({$0 != table})
		
		if db._syncingEnabled && db._unsyncedTables.filter({$0 == table}).count == 0 {
			let now = stringValueForDate(NSDate())
			if !db.sqlExecute("insert into __synclog(timestamp, sourceDB, originalDB, tableName, activity, key) values('\(now)','\(db._dbInstanceKey)','\(db._dbInstanceKey)','\(table)','X',NULL)") {
				return false
			}
			let lastID = sqlite3_last_insert_rowid(db._sqliteDB)
			if !db.sqlExecute("delete from __synclog where tableName = '\(table)' and rowid < \(lastID)") {
				return false
			}
		}
		
		return true
	}
	
	/**
	 Removes all tables and associated values.

	 - returns: Bool Tables were successfuly removed.
	 */
	class func dropAllTables() -> Bool {
		let db = ALBNoSQLDB.sharedInstance
		if !db.openDB() {
			return false
		}
		
		var successful = true
		for table in db._tables {
			successful = dropTable(table)
			if !successful {
				return false
			}
		}
		
		db._tables = [String]()
		
		return true
	}
	
	// MARK: - Sync
	/**
	 Returns whether syncing is currently enabled.

	 - returns: Bool? If syncing is enabled. Is nil when database could not be opened.
	 */
	class func syncingEnabled() -> Bool? {
		let db = ALBNoSQLDB.sharedInstance
		if !db.openDB() {
			return nil
		}
		
		return db._syncingEnabled
	}
	
	/**
	 Enables syncing. Once enabled, a log is created for all current values in the tables.

	 - returns: Bool If syncing was successfully enabled.
	 */
	class func enableSyncing() -> Bool {
		let db = ALBNoSQLDB.sharedInstance
		if !db.openDB() {
			return false
		}
		
		if db._syncingEnabled {
			return true
		}
		
		if !db.sqlExecute("create table __synclog(timestamp text, sourceDB text, originalDB text, tableName text, activity text, key text)") {
			return false
		}
		db.sqlExecute("create index __synclog_index on __synclog(tableName,key)")
		db.sqlExecute("create index __synclog_source on __synclog(sourceDB,originalDB)")
		db.sqlExecute("create table __unsyncedTables(tableName text)")
		
		let now = stringValueForDate(NSDate())
		for table in db._tables {
			if !db.sqlExecute("insert into __synclog(timestamp, sourceDB, originalDB, tableName, activity, key) select '\(now)','\(db._dbInstanceKey)','\(db._dbInstanceKey)','\(table)','U',key from \(table)") {
				return false
			}
		}
		
		db._syncingEnabled = true
		return true
	}
	
	/**
	 Disables syncing.

	 - returns: Bool If syncing was successfully disabled.
	 */
	class func disableSyncing() -> Bool {
		let db = ALBNoSQLDB.sharedInstance
		if !db.openDB() {
			return false
		}
		
		if !db._syncingEnabled {
			return true
		}
		
		if !db.sqlExecute("drop table __synclog") || !db.sqlExecute("drop table __unsyncedTables") {
			return false
		}
		
		db._syncingEnabled = false
		
		return true
	}
	
	/**
	 Returns an array of tables not being synced.

	 - returns: [String] Array of table names.
	 */
	class func unsyncedTables() -> [String] {
		return ALBNoSQLDB.sharedInstance._unsyncedTables
	}
	
	/**
	 Sets the tables that are not to be synced.

	 - parameter tables: Array of tables that are not to be synced.

	 - returns: Bool If list was set successfully.
	 */
	class func setUnsyncedTables(tables: [String]) -> Bool {
		let db = ALBNoSQLDB.sharedInstance
		if !db.openDB() {
			return false
		}
		
		if !db._syncingEnabled {
			print("syncing must be enabled before setting unsynced tables")
			return false
		}
		
		db._unsyncedTables = [String]()
		for tableName in tables {
			db.sqlExecute("delete from __synclog where tableName = '\(tableName)'")
			db._unsyncedTables.append(tableName)
		}
		
		return true
	}
	
	/**
	 Creates a sync file that can be used on another ALBNoSQLDB instance to sync data. This is a synchronous call.

	 - parameter filePath: The full path, including the file itself, to be used for the log file.
	 - parameter lastSequence: The last sequence used for the given target DB. Initial sequence is 0.
	 - parameter targetDBInstanceKey: The dbInstanceKey of the target database. Use the class dbInstanceKey method to get the DB's instanceKey.

	 - returns: (Bool,Int) If the file was successfully created and the lastSequence that should be used in subsequent calls to this instance for the given targetDBInstanceKey.
	 */
	class func createSyncFileAtURL(localURL: NSURL!, lastSequence: Int, targetDBInstanceKey: String) -> (Bool, Int) {
		let db = ALBNoSQLDB.sharedInstance
		if !db.openDB() {
			return (false, lastSequence)
		}
		
		if !db._syncingEnabled {
			print("syncing must be enabled before creating sync file")
			return (false, lastSequence)
		}
		
		let filePath = localURL.path!
		
		if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
			do {
				try NSFileManager.defaultManager().removeItemAtPath(filePath)
			} catch _ as NSError {
				return (false, lastSequence)
			}
		}
		
		NSFileManager.defaultManager().createFileAtPath(filePath, contents: nil, attributes: nil)
		
		if let fileHandle = NSFileHandle(forWritingAtPath: filePath) {
			if let results = db.sqlSelect("select rowid,timestamp,originalDB,tableName,activity,key from __synclog where rowid > \(lastSequence) and sourceDB <> '\(targetDBInstanceKey)' and originalDB <> '\(targetDBInstanceKey)' order by rowid") {
				var lastRowID = lastSequence
				fileHandle.writeData("{\"sourceDB\":\"\(db._dbInstanceKey)\",\"logEntries\":[\n".dataValue())
				var firstEntry = true
				for row in results {
					lastRowID = row.values[0] as! Int
					let timeStamp = row.values[1] as! String
					let originalDB = row.values[2] as! String
					let tableName = row.values[3] as! String
					let activity = row.values[4] as! String
					let key = row.values[5] as! String?
					
					var entryDict = [String: AnyObject]()
					entryDict["timeStamp"] = timeStamp
					if originalDB != db._dbInstanceKey {
						entryDict["originalDB"] = originalDB
					}
					entryDict["tableName"] = tableName
					entryDict["activity"] = activity
					if key != nil {
						entryDict["key"] = key
						if activity == "U" {
							entryDict["value"] = db.dictValueForKey(table: tableName, key: key!, includeDates: true)!
						}
					}
					
					let dataValue = try? NSJSONSerialization.dataWithJSONObject(entryDict, options: NSJSONWritingOptions(rawValue: 0))
					if firstEntry {
						firstEntry = false
					} else {
						fileHandle.writeData("\n,".dataValue())
					}
					
					fileHandle.writeData(dataValue!)
				}
				
				fileHandle.writeData("\n],\"lastSequence\":\(lastRowID)}".dataValue())
				fileHandle.closeFile()
				return (true, lastRowID)
				
			} else {
				do {
					try NSFileManager.defaultManager().removeItemAtPath(filePath)
				} catch _ {
					return (false, lastSequence)
				}
			}
		}
		
		return (false, lastSequence)
	}
	
	/**
	 Processes a sync file created by another instance of ALBNoSQLDB. This is a synchronous call.

	 - parameter filePath: The path to the sync file.
	 - parameter syncProgress: Optional function that will be called periodically giving the percent complete.

	 - returns: (Bool,String,Int)  If the sync file was successfully processed,the instanceKey of the submiting DB, and the lastSequence that should be used in subsequent calls to the createSyncFile method of the instance that was used to create this file. If the database couldn't be opened or syncing hasn't been enabled, then the instanceKey will be empty and the lastSequence will be equal to zero.
	 */
	typealias syncProgressUpdate = (percentComplete: Double) -> ()
	class func processSyncFileAtURL(localURL: NSURL!, syncProgress: syncProgressUpdate?) -> (Bool, String, Int) {
		let db = ALBNoSQLDB.sharedInstance
		if !db.openDB() {
			return (false, "", 0)
		}
		
		if !db._syncingEnabled {
			print("syncing must be enabled before creating sync file")
			return (false, "", 0)
		}
		
		db.autoDelete()
		
		let filePath = localURL.path!
		
		if let _ = NSFileHandle(forReadingAtPath: filePath) {
			// TODO: Stream in the file and parse as needed instead of parsing the entire thing at once to save on memory use
			let now = ALBNoSQLDB.stringValueForDate(NSDate())
			if let fileText = try? String(contentsOfFile: filePath, encoding: NSUTF8StringEncoding) {
				let dataValue = fileText.dataValue()
				
				if let objectValues = (try? NSJSONSerialization.JSONObjectWithData(dataValue, options: NSJSONReadingOptions.MutableContainers)) as? [String: AnyObject] {
					let sourceDB = objectValues["sourceDB"] as! String
					let logEntries = objectValues["logEntries"] as! [[String: AnyObject]]
					let lastSequence = objectValues["lastSequence"] as! Int
					var index = 0
					for entry in logEntries {
						index++
						if index % 20 == 0 {
							if let syncProgress = syncProgress {
								let percent = (Double(index) / Double(logEntries.count))
								syncProgress(percentComplete: percent)
							}
						}
						
						let activity = entry["activity"] as! String
						let timeStamp = entry["timeStamp"] as! String
						let tableName = entry["tableName"] as! String
						let originalDB = (entry["originalDB"] == nil ? sourceDB : entry["originalDB"] as! String)
						
						// for entry activity U,D only process log entry if no local entry for same table/key that is greater than one received
						if activity == "D" || activity == "U" {
							if let key = entry["key"] as? String, results = db.sqlSelect("select 1 from __synclog where tableName = '\(tableName)' and key = '\(key)' and timestamp > '\(timeStamp)'") {
								if results.count == 0 {
									if activity == "U" {
										// strip out the dates to send separately
										var objectValues = entry["value"] as! [String: AnyObject]
										let addedDateTime = objectValues["addedDateTime"] as! String
										let updatedDateTime = objectValues["updatedDateTime"] as! String
										let deleteDateTime = (objectValues["deleteDateTime"] == nil ? "NULL" : objectValues["deleteDateTime"] as! String)
										objectValues.removeValueForKey("addedDateTime")
										objectValues.removeValueForKey("updatedDateTime")
										objectValues.removeValueForKey("deleteDateTime")
										
										db.setValue(table: tableName, key: key, objectValues: objectValues, addedDateTime: addedDateTime, updatedDateTime: updatedDateTime, deleteDateTime: deleteDateTime, sourceDB: sourceDB, originalDB: originalDB)
									} else {
										db.deleteForKey(table: tableName, key: key, autoDelete: false, sourceDB: sourceDB, originalDB: originalDB)
									}
								}
							}
						} else {
							// for table activity X, delete any entries that occured BEFORE this event
							db.sqlExecute("delete from \(tableName) where key in (select key from __synclog where tableName = '\(tableName)' and timeStamp < '\(timeStamp)')")
							db.sqlExecute("delete from \(tableName)_arrayValues where key in (select key from __synclog where tableName = '\(tableName)' and timeStamp < '\(timeStamp)')")
							db.sqlExecute("delete from __synclog where tableName = '\(tableName)' and timeStamp < '\(timeStamp)'")
							db.sqlExecute("insert into __synclog(timestamp, sourceDB, originalDB, tableName, activity, key) values('\(now)','\(sourceDB)','\(originalDB)','\(tableName)','X',NULL)")
						}
					}
					
					return (true, sourceDB, lastSequence)
				} else {
					return (false, "", 0)
				}
			} else {
				return (false, "", 0)
			}
		}
		
		return (false, "", 0)
	}
	
	
	// MARK: - Misc
	/**
	 Close the database.
	 */
	class func close() {
		let db = ALBNoSQLDB.sharedInstance
		dispatch_suspend(db._autoDeleteTimer)
		sqlite3_close_v2(db._sqliteDB)
		db._sqliteDB = nil
	}
	
	
	/**
	 The instanceKey for this database instance.

	 - returns: String? the instanceKey.  Is nil when database could not be opened.
	 */
	class func dbInstanceKey() -> String? {
		let db = ALBNoSQLDB.sharedInstance
		if db.openDB() {
			return db._dbInstanceKey
		}
		
		return nil
	}
	
	/**
	 A unique string that can be used as a key.

	 - returns: String Unique string.
	 */
	class func guid() -> String {
		let uuid = CFUUIDCreate(kCFAllocatorDefault)
		let uuidString = String(CFUUIDCreateString(kCFAllocatorDefault, uuid))
		
		return uuidString
	}
	
	/**
	 String value for a given date.

	 - parameter date: Date to get string value of

	 - returns: String Date presented as a string
	 */
	class func stringValueForDate(date: NSDate) -> String {
		let db = ALBNoSQLDB.sharedInstance
		return db._dateFormatter.stringFromDate(date)
	}
	
	/**
	 Date value for given string

	 - parameter stringValue: String representation of date given in ISO format "yyyy-MM-dd'T'HH:mm:ss'.'SSSZZZZZ"

	 - returns: NSDate? Date value. Is nil if the string could not be converted to date.
	 */
	class func dateValueForString(stringValue: String) -> NSDate? {
		let db = ALBNoSQLDB.sharedInstance
		return db._dateFormatter.dateFromString(stringValue)
	}
	
	private func typeOfValue(value: AnyObject) -> ValueType {
		var valueType = ValueType.unknown
		
		if value is [String] {
			valueType = .stringArray
		} else {
			if value is [Int] {
				valueType = .intArray
			} else {
				if value is [Double] {
					valueType = .doubleArray
				} else {
					if value is String {
						valueType = .string
					} else {
						if value is Int {
							valueType = .int
						} else {
							if value is Double {
								valueType = .double
							}
						}
					}
				}
			}
		}
		
		return valueType
	}
	
	// MARK: - Initialization Methods
	static let sharedInstance = ALBNoSQLDB()
	
	init() {
		_dateFormatter = NSDateFormatter()
		_dateFormatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)
		_dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.'SSSZZZZZ"
		_autoDeleteTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _deletionQueue)
	}
	
	private func openDB() -> Bool {
		if _sqliteDB != nil {
			return true
		}
		
		var dbFilePath = ""
		
		if let _dbFileLocation = self._dbFileLocation {
			dbFilePath = _dbFileLocation.path!
		} else {
			let searchPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
			let documentFolderPath = searchPaths[0]
			dbFilePath = documentFolderPath + "/ABNoSQLDB.db"
		}
		
		// println(dbFilePath)
		let fileExists = NSFileManager.defaultManager().fileExistsAtPath(dbFilePath)
		
		var openDBSuccessful = true
		dispatch_sync(_dbQueue) {
			openDBSuccessful = self.openDBFile(dbFilePath)
		}
		
		if openDBSuccessful {
			if !fileExists {
				self.makeDB()
			}
			self.checkSchema()
			self.sqlExecute("ANALYZE")
			
			dispatch_source_set_timer(_autoDeleteTimer, DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC, 1 * NSEC_PER_SEC) ; // every 60 seconds, with leeway of 1 second
			dispatch_source_set_event_handler(_autoDeleteTimer) {
				self.autoDelete()
			}
			dispatch_resume(_autoDeleteTimer)
		}
		
		return openDBSuccessful
	}
	
	private func openDBFile(dbFilePath: String) -> Bool {
		let status = sqlite3_open_v2(dbFilePath.cStringUsingEncoding(NSUTF8StringEncoding)!, &_sqliteDB, SQLITE_OPEN_FILEPROTECTION_COMPLETE | SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil)
		
		if status != SQLITE_OK {
			print("Error opening SQLite Database: \(status)")
			return false
		}
		
		return true
	}
	
	private func makeDB() {
		assert(sqlExecute("create table __settings(key text, value text)"), "Unable to make DB")
		assert(sqlExecute("insert into __settings(key,value) values('schema',1)"), "Unable to make DB")
		assert(sqlExecute("create table __tableArrayColumns(tableName text, arrayColumns text)"), "Unable to make DB")
	}
	
	private func checkSchema() {
		_tables = [String]()
		let tableList = sqlSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
		if let tableList = tableList {
			for tableRow in tableList {
				let table = tableRow.values[0] as! String
				if !reservedTable(table) && !table.hasSuffix("_arrayValues") {
					_tables.append(table)
				}
				
				if table == "__synclog" {
					_syncingEnabled = true
				}
			}
		}
		
		if _syncingEnabled {
			_unsyncedTables = [String]()
			let unsyncedTables = sqlSelect("select tableName from __unsyncedTables")
			if let unsyncedTables = unsyncedTables {
				_unsyncedTables = unsyncedTables.map({$0.values[0] as! String})
			}
		}
		
		if let keyResults = sqlSelect("select value from __settings where key = 'dbInstanceKey'") {
			if keyResults.count == 0 {
				_dbInstanceKey = ALBNoSQLDB.guid()
				let parts = _dbInstanceKey.componentsSeparatedByString("-")
				_dbInstanceKey = parts[parts.count - 1]
				sqlExecute("insert into __settings(key,value) values('dbInstanceKey','\(_dbInstanceKey)')")
			} else {
				_dbInstanceKey = keyResults[0].values[0] as! String
			}
		}
		
		if let schemaResults = sqlSelect("select value from __settings where key = 'schema'") {
			var schemaVersion = Int((schemaResults[0].values[0] as! String))!
			if schemaVersion == 1 {
				sqlExecute("update __settings set value = 2 where key = 'schema'")
				schemaVersion = 2
			}
			
			// use this space to update the schema value in __settings and to update any other tables that need updating with the new schema
		}
	}
	
	// MARK: - Internal data handling methods
	private func setValue(table table: String, key: String, objectValues: [String: AnyObject], addedDateTime: String, updatedDateTime: String, deleteDateTime: String, sourceDB: String, originalDB: String) -> Bool {
		if !openDB() {
			return false
		}
		
		if !createTable(table) {
			return false
		}
		
		// look for any array objects
		var arrayKeys = [String]()
		var arrayKeyTypes = [String]()
		var arrayTypes = [ValueType]()
		var arrayValues = [AnyObject]()
		
		for (objectKey, objectValue) in objectValues {
			let valueType = typeOfValue(objectValue)
			if valueType == .stringArray || valueType == .intArray || valueType == .doubleArray {
				arrayKeys.append(objectKey)
				arrayTypes.append(valueType)
				arrayKeyTypes.append("\(objectKey):\(valueType.rawValue)")
				arrayValues.append(objectValue)
			}
		}
		
		let joinedArrayKeys = arrayKeyTypes.joinWithSeparator(",")
		
		var sql = "select key from \(esc(table)) where key = '\(esc(key))'"
		
		var tableHasKey = false
		if let results = sqlSelect(sql) {
			if results.count == 0 {
				// key doesn't exist, insert values
				sql = "insert into \(table) (key,addedDateTime,updatedDateTime,autoDeleteDateTime,hasArrayValues"
				var placeHolders = "'\(key)','\(addedDateTime)','\(updatedDateTime)',\(deleteDateTime),'\(joinedArrayKeys)'"
				
				for (objectKey, objectValue) in objectValues {
					let valueType = typeOfValue(objectValue)
					if valueType == .int || valueType == .double || valueType == .string {
						sql += ",\(objectKey)"
						placeHolders += ",?"
					}
				}
				
				sql += ") values(\(placeHolders))"
			} else {
				tableHasKey = true
				sql = "update \(table) set updatedDateTime='\(updatedDateTime)',autoDeleteDateTime=\(deleteDateTime),hasArrayValues='\(joinedArrayKeys)'"
				for (objectKey, objectValue) in objectValues {
					let valueType = typeOfValue(objectValue)
					if valueType == .int || valueType == .double || valueType == .string {
						sql += ",\(objectKey)=?"
					}
				}
				// set unused columns to NULL
				let objectKeys = objectValues.keys
				let columns = columnsInTable(table)
				for column in columns {
					let filteredKeys = objectKeys.filter({$0 == column.name})
					if filteredKeys.count == 0 {
						sql += ",\(column.name)=NULL"
					}
				}
				sql += " where key = '\(key)'"
			}
			
			if !processValues(table: table, objectValues: objectValues, sql: sql) {
				// adjust table columns
				validateTableColumns(table: table, objectValues: objectValues)
				// try again
				if !processValues(table: table, objectValues: objectValues, sql: sql) {
					return false
				}
			}
			
			// process any array values
			for index in 0..<arrayKeys.count {
				if !setArrayValues(table: table, arrayValues: arrayValues[index] as! [AnyObject], valueType: arrayTypes[index], key: key, objectKey: arrayKeys[index]) {
					return false
				}
			}
			
			if _syncingEnabled && _unsyncedTables.filter({$0 == table}).count == 0 {
				let now = ALBNoSQLDB.stringValueForDate(NSDate())
				sql = "insert into __synclog(timestamp, sourceDB, originalDB, tableName, activity, key) values('\(now)','\(sourceDB)','\(originalDB)','\(table)','U','\(esc(key))')"
				sqlExecute(sql)
				let lastID = sqlite3_last_insert_rowid(_sqliteDB)
				
				if tableHasKey {
					sql = "delete from __synclog where tableName = '\(table)' and key = '\(esc(key))' and rowid < \(lastID)"
					sqlExecute(sql)
				}
			}
		} else {
			return false
		}
		
		return true
	}
	
	private func processValues(table table: String, objectValues: [String: AnyObject], sql: String) -> Bool {
		var statement: COpaquePointer = nil
		var status = sqlite3_prepare_v2(self._sqliteDB, sql, -1, &statement, nil)
		if status != SQLITE_OK {
			// displaySQLError(sql)
			return false
		} else {
			// try to bind the object properties to table fields.
			var index: Int32 = 1
			
			for (_, objectValue) in objectValues {
				let valueType = typeOfValue(objectValue)
				if valueType == .int || valueType == .double || valueType == .string {
					status = bindValue(statement, index: index, value: objectValue)
					if status != SQLITE_OK {
						displaySQLError(sql)
						sqlite3_finalize(statement)
						return false
					}
					index++
				}
			}
			
			status = sqlite3_step(statement)
			if status != SQLITE_DONE && status != SQLITE_OK {
				displaySQLError(sql)
				return false
			}
		}
		
		sqlite3_finalize(statement)
		
		return true
	}
	
	
	private func bindValue(statement: COpaquePointer, index: Int32, value: AnyObject) -> Int32 {
		var status = SQLITE_OK
		let valueType = typeOfValue(value)
		var int64Value: Int64 = 0
		
		if valueType == .int {
			int64Value = Int64(value as! Int)
		}
		
		switch valueType {
		case .string:
			status = sqlite3_bind_text(statement, index, value as! String, -1, SQLITE_TRANSIENT)
		case .int:
			status = sqlite3_bind_int64(statement, index, int64Value)
		case .double:
			status = sqlite3_bind_double(statement, index, value as! Double)
		default:
			status = SQLITE_OK
		}
		
		return status
	}
	
	private func setArrayValues(table table: String, arrayValues: [AnyObject], valueType: ValueType, key: String, objectKey: String) -> Bool {
		var successful = sqlExecute("delete from \(table)_arrayValues where key='\(key)' and objectKey='\(objectKey)'")
		if !successful {
			return false
		}
		
		for value in arrayValues {
			switch valueType {
			case .stringArray:
				successful = sqlExecute("insert into \(table)_arrayValues(key,objectKey,stringValue) values('\(key)','\(objectKey)','\(esc(value as! String))')")
			case .intArray:
				successful = sqlExecute("insert into \(table)_arrayValues(key,objectKey,intValue) values('\(key)','\(objectKey)',\(value as! Int))")
			case .doubleArray:
				successful = sqlExecute("insert into \(table)_arrayValues(key,objectKey,doubleValue) values('\(key)','\(objectKey)',\(value as! Double))")
			default:
				successful = true
			}
			
			if !successful {
				return false
			}
		}
		
		return true
	}
	
	private func deleteForKey(table table: String, key: String, autoDelete: Bool, sourceDB: String, originalDB: String) -> Bool {
		if !openDB() {
			return false
		}
		
		if !hasTable(table) {
			return false
		}
		
		if !sqlExecute("delete from \(table) where key = '\(esc(key))'") || !sqlExecute("delete from \(table)_arrayValues where key = '\(esc(key))'") {
			return false
		}
		
		let now = ALBNoSQLDB.stringValueForDate(NSDate())
		if _syncingEnabled && _unsyncedTables.filter({$0 == table}).count == 0 {
			var sql = ""
			// auto-deleted entries will be automatically removed from any other databases too. Don't need to log this deletion.
			if !autoDelete {
				sql = "insert into __synclog(timestamp, sourceDB, originalDB, tableName, activity, key) values('\(now)','\(sourceDB)','\(originalDB)','\(table)','D','\(esc(key))')"
				sqlExecute(sql)
				
				let lastID = sqlite3_last_insert_rowid(_sqliteDB)
				sql = "delete from __synclog where tableName = '\(table)' and key = '\(esc(key))' and rowid < \(lastID)"
				sqlExecute(sql)
			} else {
				sql = "delete from __synclog where tableName = '\(table)' and key = '\(esc(key))"
				sqlExecute(sql)
			}
		}
		
		return true
	}
	
	private func autoDelete() {
		let now = ALBNoSQLDB.stringValueForDate(NSDate())
		for table in _tables {
			if !reservedTable(table) {
				let sql = "select key from \(table) where autoDeleteDateTime < '\(now)'"
				if let results = sqlSelect(sql) {
					for row in results {
						let key = row.values[0] as! String
						deleteForKey(table: table, key: key, autoDelete: true, sourceDB: _dbInstanceKey, originalDB: _dbInstanceKey)
					}
				}
			}
		}
	}
	
	private func dictValueForKey(table table: String, key: String, includeDates: Bool) -> [String: AnyObject]? {
		if !openDB() || !hasTable(table) {
			return nil
		}
		
		var columns = columnsInTable(table)
		if includeDates {
			columns.append(TableColumn(name: "autoDeleteDateTime", type: .string))
			columns.append(TableColumn(name: "addedDateTime", type: .string))
			columns.append(TableColumn(name: "updatedDateTime", type: .string))
		}
		
		var sql = "select hasArrayValues"
		for column in columns {
			sql += ",\(column.name)"
		}
		sql += " from \(table) where key = '\(esc(key))'"
		var results = sqlSelect(sql)
		
		if results == nil || (results != nil && results?.count == 0) {
			return nil
		}
		
		var valueDict = [String: AnyObject]()
		for columnIndex in 0..<columns.count {
			let valueIndex = columnIndex + 1
			if results![0].values[valueIndex] != nil {
				valueDict[columns[columnIndex].name] = results![0].values[valueIndex]
			}
		}
		
		// handle any arrayValues
		let arrayObjects = (results![0].values[0] as! String).characters.split {$0 == ","}.map {String($0)}
		for object in arrayObjects {
			if object == "" {
				continue
			}
			
			let keyType = object.characters.split {$0 == ":"}.map {String($0)}
			let objectKey = keyType[0]
			let valueType = ValueType(rawValue: keyType[1] as String)!
			var stringArray = [String]()
			var intArray = [Int]()
			var doubleArray = [Double]()
			
			switch valueType {
			case .stringArray:
				results = sqlSelect("select stringValue from \(table)_arrayValues where key = '\(key)' and objectKey = '\(objectKey)'")
			case .intArray:
				results = sqlSelect("select intValue from \(table)_arrayValues where key = '\(key)' and objectKey = '\(objectKey)'")
			case .doubleArray:
				results = sqlSelect("select doubleValue from \(table)_arrayValues where key = '\(key)' and objectKey = '\(objectKey)'")
				valueDict[objectKey] = doubleArray
			default:
				break
			}
			
			if results != nil {
				for index in 0..<results!.count {
					switch valueType {
					case .stringArray:
						stringArray.append(results![index].values[0] as! String)
					case .intArray:
						intArray.append(results![index].values[0] as! Int)
					case .doubleArray:
						doubleArray.append(results![index].values[0] as! Double)
					default:
						break
					}
				}
			} else {
				return nil
			}
			
			switch valueType {
			case .stringArray:
				valueDict[objectKey] = stringArray
			case .intArray:
				valueDict[objectKey] = intArray
			case .doubleArray:
				valueDict[objectKey] = doubleArray
			default:
				break
			}
		}
		
		return valueDict
	}
	
	// MARK: - Internal Table methods
	class TableColumn {
		var name = ""
		var type = ValueType.string
		
		init(name: String, type: ValueType) {
			self.name = name
			self.type = type
		}
	}
	
	private func hasTable(table: String) -> Bool {
		return _tables.filter({$0 == table}).count > 0
	}
	
	private func reservedTable(table: String) -> Bool {
		return table.hasPrefix("__") || table.hasPrefix("sqlite_stat")
	}
	
	private func reservedColumn(column: String) -> Bool {
		return column == "key"
		|| column == "addedDateTime"
		|| column == "updatedDateTime"
		|| column == "autoDeleteDateTime"
		|| column == "hasArrayValues"
		|| column == "arrayValues"
	}
	
	private func createTable(table: String) -> Bool {
		if hasTable(table) {
			return true
		}
		
		if reservedTable(table) {
			return false
		}
		
		if !sqlExecute("create table \(table) (key text PRIMARY KEY, autoDeleteDateTime text, addedDateTime text, updatedDateTime text, hasArrayValues text)") || !sqlExecute("create index idx_\(table)_autoDeleteDateTime on \(table)(autoDeleteDateTime)") {
			return false
		}
		
		if !sqlExecute("create table \(table)_arrayValues (key text, objectKey text, stringValue text, intValue int, doubleValue double)") || !sqlExecute("create index idx_\(table)_arrayValues_keys on \(table)_arrayValues(key,objectKey)") {
			return false
		}
		
		_tables.append(table)
		
		return true
	}
	
	private func createIndexesForTable(table: String) {
		if !hasTable(table) {
			return
		}
		
		if let indexes = _indexes[table] {
			for index in indexes {
				var indexName = index.stringByReplacingOccurrencesOfString(",", withString: "_", options: NSStringCompareOptions.LiteralSearch, range: nil)
				indexName = "idx_\(table)_\(indexName)"
				
				var sql = "select * from sqlite_master where tbl_name = '\(table)' and name = '\(indexName)'"
				if let results = sqlSelect(sql) {
					if results.count == 0 {
						sql = "CREATE INDEX \(indexName) on \(table)(\(index))"
						sqlExecute(sql)
					}
				}
			}
		}
	}
	
	private func columnsInTable(table: String) -> [TableColumn] {
		let tableInfo = sqlSelect("pragma table_info(\(table))")
		var columns = [TableColumn]()
		for info in tableInfo! {
			let columnName = info.values[1] as! String
			if !reservedColumn(columnName) {
				columns.append(TableColumn(name: columnName, type: ValueType(rawValue: info.values[2] as! String)!))
			}
		}
		
		return columns
	}
	
	private func validateTableColumns(table table: String, objectValues: [NSString: AnyObject]) {
		let columns = columnsInTable(table)
		// determine missing columns and add them
		for (objectKey, value) in objectValues {
			assert(!reservedColumn(objectKey as String), "Reserved column")
			assert((objectKey as String).rangeOfString("'") == nil, "Single quote not allowed in column names")
			var found = false
			for column in columns {
				if column.name == objectKey {
					found = true
					break
				}
			}
			
			if !found {
				let valueType = typeOfValue(value)
				assert(valueType != .unknown, "column types are .int, double, string or arrays of these types")
				
				if valueType == .int || valueType == .double || valueType == .string {
					let sql = "alter table \(table) add column \(objectKey) \(valueType.rawValue)"
					sqlExecute(sql)
				}
				else {
					// array type
					let sql = "select arrayColumns from __tableArrayColumns where tableName = '\(table)'"
					if let results = sqlSelect(sql) {
						var arrayColumns = ""
						if results.count > 0 {
							arrayColumns = results[0].values[0] as! String
							arrayColumns += ",\(objectKey)"
							sqlExecute("delete from __tableArrayColumns where tableName = '\(table)'")
						} else {
							arrayColumns = objectKey as String
						}
						sqlExecute("insert into __tableArrayColumns(tableName,arrayColumns) values('\(table)','\(arrayColumns)')")
					}
				}
			}
		}
		
		createIndexesForTable(table)
	}
	
	// MARK: - SQLite execute/query
	func esc(source: String) -> String {
		return source.stringByReplacingOccurrencesOfString("'", withString: "''", options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil)
	}
	
	
	private func sqlExecute(sql: String) -> Bool {
		var successful = false
		
		// create task closure
		dispatch_sync(_dbQueue) {
			successful = self.runCommand(sql)
		}
		
		return successful
	}
	
	private func runCommand(sql: String) -> Bool {
		var dbps: COpaquePointer = nil
		var status = sqlite3_prepare_v2(self._sqliteDB, sql, -1, &dbps, nil)
		if status != SQLITE_OK {
			displaySQLError(sql)
			sqlite3_finalize(dbps)
			return false
		}
		
		status = sqlite3_step(dbps)
		if status != SQLITE_DONE && status != SQLITE_OK {
			displaySQLError(sql)
			sqlite3_finalize(dbps)
			return false
		}
		
		sqlite3_finalize(dbps)
		return true
	}
	
	func sqlSelect(sql: String) -> [DBRow]? {
		var recordset: [DBRow]?
		
		dispatch_sync(_dbQueue) {
			recordset = self.runSelect(sql)
		}
		
		return recordset
	}
	
	private func runSelect(sql: String) -> [DBRow]? {
		// explain(sql)
		
		var dbps: COpaquePointer = nil
		var rows = [DBRow]()
		
		
		var status = sqlite3_prepare_v2(self._sqliteDB, sql, -1, &dbps, nil)
		if status != SQLITE_OK {
			displaySQLError(sql)
			sqlite3_finalize(dbps)
			return nil
		}
		
		repeat {
			status = sqlite3_step(dbps)
			if status == SQLITE_ROW {
				var row = DBRow()
				let count = sqlite3_column_count(dbps)
				for var index = Int32(0) ; index < count; index++ {
					let columnType = sqlite3_column_type(dbps, index)
					switch columnType {
					case SQLITE_TEXT:
						let text = UnsafePointer<Int8>(sqlite3_column_text(dbps, index))
						let value = String.fromCString(text)
						row.values.append(value)
					case SQLITE_INTEGER:
						row.values.append(Int(sqlite3_column_int64(dbps, index)))
					case SQLITE_FLOAT:
						row.values.append(sqlite3_column_double(dbps, index) as Double)
					default:
						row.values.append(nil)
					}
				}
				
				rows.append(row)
			}
		} while status == SQLITE_ROW
		
		if status != SQLITE_DONE {
			displaySQLError(sql)
			sqlite3_finalize(dbps)
			return nil
		}
		
		sqlite3_finalize(dbps)
		return rows
	}
	
	private func displaySQLError(sql: String) {
		let text = UnsafePointer<Int8>(sqlite3_errmsg(self._sqliteDB))
		let error = String.fromCString(text)
		print("Error: \(error!)")
		print("     on command - \(sql)")
		print("")
	}
	
	private func explain(sql: String) {
		var dbps: COpaquePointer = nil
		let explainCommand = "EXPLAIN QUERY PLAN \(sql)"
		sqlite3_prepare_v2(self._sqliteDB, explainCommand, -1, &dbps, nil)
		print("\n\n.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  \nQuery:\(sql)\n\nAnalysis:\n")
		while (sqlite3_step(dbps) == SQLITE_ROW) {
			let iSelectid = sqlite3_column_int(dbps, 0)
			let iOrder = sqlite3_column_int(dbps, 1)
			let iFrom = sqlite3_column_int(dbps, 2)
			let text = UnsafePointer<Int8>(sqlite3_column_text(dbps, 3))
			let value = String.fromCString(text)
			
			print("\(iSelectid) \(iOrder) \(iFrom) \(value)\n=================================================\n\n")
		}
		
		sqlite3_finalize(dbps)
	}
}

struct DBRow {
	var values = [AnyObject?]()
}