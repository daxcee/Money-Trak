//
//  Sync.swift
//  My Money
//
//  Created by Aaron Bratcher on 1/14/15.
//  Copyright (c) 2015 Aaron L. Bratcher. All rights reserved.
//

import Foundation
import UIKit

class UnknownDeviceCell:UITableViewCell {
	@IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var linkButtonView: UIView!
    @IBOutlet weak var progressWheel: UIActivityIndicatorView!
	
	var device:SyncDevice {
		get {
			return _device
		}
		
		set(newDevice) {
			_device = newDevice
			deviceName.text = _device.name
            
            linkButtonView.hidden = device.status != .idle
            progressWheel.hidden = device.status == .idle
		}
	}
	var delegate:SyncDeviceCellDelegate?
	
	private var _device = SyncDevice()
	
    @IBAction func linkTapped(sender: AnyObject) {
		delegate?.linkTappedForDevice(_device)
    }
}

class KnownDeviceCell:UITableViewCell {
    
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressWheel: UIActivityIndicatorView!

    var device:SyncDevice {
        get {
            return _device
        }
        
        set(newDevice) {
            _device = newDevice
            deviceName.text = _device.name
            
            progressWheel.hidden = device.status == .idle
            
            switch device.status {
            case .idle:
                if let lastDate = device.lastSync {
                    if lastDate.midnight() == NSDate().midnight() {
                        statusLabel.text = lastDate.relativeTimeFrom(NSDate())
                    } else {
                        statusLabel.text = lastDate.relativeDateString()
                    }
                } else {
                    statusLabel.text = "Never Synced"
                }
            case .syncing:
                statusLabel.text = "Syncing..."
            default:
                statusLabel.text = ""
                break;
            }
        }
    }
    
    var delegate:SyncDeviceCellDelegate?
    private var _device = SyncDevice()    
}