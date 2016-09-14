//
//  Reachability.swift
//  My Money
//
//  Created by Aaron Bratcher on 10/17/15.
//  Copyright © 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import SystemConfiguration

public class Reachability {
	class func isConnectedToNetwork() -> Bool {
		var zeroAddress = sockaddr_in()

		guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				SCNetworkReachabilityCreateWithAddress(nil, $0)
			}
		}) else {
			return false
		}
		
		zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
		zeroAddress.sin_family = sa_family_t(AF_INET)
		var flags = SCNetworkReachabilityFlags()
		if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
			return false
		}
		
		let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
		let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
		return (isReachable && !needsConnection)
	}
}
