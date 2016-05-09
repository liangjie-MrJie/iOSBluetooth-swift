//
//  Utils.swift
//  CoreBluetoothWithSwif
//
//  Created by liangjie on 16/4/15.
//  Copyright © 2016年 liangjie. All rights reserved.
//

import Foundation

class Utils: NSObject {
    
    class func macAddressFromManufacturerData(data: NSData!) -> String {
        let length = data.length
        var macAddress = String()
        if length > 0 {
            var macByte: UInt8 = 0
            for index in (0..<length).reverse() {
                data.getBytes(&macByte, range: NSRange(location: index, length: 1))
                macAddress = macAddress.stringByAppendingFormat("%02X", macByte)
                if index > 0 {
                    macAddress.appendContentsOf(":")
                }
            }
        }
        
        return macAddress
    }
   
    class func manufacturerDataFromMacAddress(macAddress: String!) -> NSData {
        let mac = macAddress.stringByReplacingOccurrencesOfString(":", withString: "")
        let data = mac.toHexBytes()
        
        return data.reverse()
    }
}