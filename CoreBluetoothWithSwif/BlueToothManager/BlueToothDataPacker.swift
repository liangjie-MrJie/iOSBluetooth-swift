//
//  BlueToothDataPacker.swift
//  CoreBluetoothWithSwif
//
//  Created by liangjie on 16/4/28.
//  Copyright © 2016年 liangjie. All rights reserved.
//

import Foundation

/**
 *  设备返回来的数据包, 玩家需要自己定义自己的格式
 */
struct ResponseDataPack {
    let rawValue : Int
    
    static let Code         = ResponseDataPack(rawValue: 0).rawValue
    static let ID           = ResponseDataPack(rawValue: 1).rawValue
    static let Count        = ResponseDataPack(rawValue: 2).rawValue
    static let DIR          = ResponseDataPack(rawValue: 3).rawValue
    static let Length       = ResponseDataPack(rawValue: 4).rawValue
    static let Data         = ResponseDataPack(rawValue: 5).rawValue
    static let ExtendLength = ResponseDataPack.Data
    static let ExtendData   = ResponseDataPack.ExtendLength + sizeof(UInt16)
}

class BlueToothDataPacker: NSObject {
    var sendData: NSData
    var repeatCount: Int8
    var canWrite: Bool
    var responseResult: ResponseResultCallBack?
    var timeout: NSTimeInterval
    let conditionLock: NSCondition
    var needSignal: Bool
    
    init(data: NSData,  timeout: NSTimeInterval, repeatCount: Int8, responseResult: ResponseResultCallBack?) {
        self.canWrite = data.length != 0
        self.sendData = data
        self.timeout = timeout
        self.repeatCount = repeatCount
        self.responseResult = responseResult
        self.conditionLock = NSCondition()
        self.needSignal = false
        super.init()
    }
    
    func wait() {
        self.needSignal = true
        self.conditionLock.lock()
        self.conditionLock.wait()
        self.conditionLock.unlock()
        self.needSignal = false
    }
    func signal() {
        if self.needSignal {            
            self.conditionLock.signal()
        }
    }
}