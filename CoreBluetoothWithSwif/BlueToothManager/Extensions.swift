//
//  Extensions.swift
//  CoreBluetoothWithSwif
//
//  Created by liangjie on 16/4/24.
//  Copyright © 2016年 liangjie. All rights reserved.
//

import Foundation

extension String {
    func toHexBytes() -> NSData {
        let bytes = self.cStringUsingEncoding(NSUTF8StringEncoding)
        var i = 0, len = self.characters.count
        let data = NSMutableData(capacity: len/2)
        let b = Int8(0)
        var byteArray = [b, b, b]
        while i < len {
            byteArray[0] = bytes![i]
            i = i.advancedBy(1)
            byteArray[1] = bytes![i]
            i = i.advancedBy(1)
            var wholeByte = strtoul(byteArray, nil, 16)
            data!.appendBytes(&wholeByte, length: 1)
        }
        
        return data!.copy() as! NSData
    }
}

extension NSData {
    
    func toHexString() -> String {
        var hexString = String()
        for index in 0..<self.length {
            var byte = 0
            self.getBytes(&byte, range: NSRange(location: index, length:1))
            hexString = hexString.stringByAppendingFormat("%02X", byte)
        }
        
        return hexString
    }
    
    func reverse() -> NSData {
        let reverseData = NSMutableData(capacity: self.length)
        for index in (0..<self.length).reverse() {
            var byte = 0
            self.getBytes(&byte, range: NSRange(location: index, length: 1))
            reverseData!.appendBytes(&byte, length: 1)
        }
        
        return reverseData!.copy() as! NSData
    }

    func toUnsignedLongLong() -> UInt64 {
        var ull = UInt64()
        for index in 0..<self.length {
            var byte = UInt64()
            let bitCount = UInt64((self.length-1-index)*8)
            self.getBytes(&byte, range: NSRange(location: index, length: 1))
            ull |= byte << bitCount
        }
        
        return ull
    }
}

extension UInt64 {
    func toNSData() -> NSData {
        var tempUint64 = self
        var bytes = Array(count: 8, repeatedValue: UInt8())
        for index in (0...7).reverse() {
            bytes[index] = UInt8(tempUint64 & 0x00000000000000FF)
            tempUint64 = tempUint64 >> 8
        }
        let data = NSData(bytes: bytes, length: 8)
        
        return data
    }
}

extension UInt: BooleanType {
    public var boolValue: Bool {
        get {
            if self > 0 {
                return true
            }
            else {
                return false
            }
        }
    }
}



