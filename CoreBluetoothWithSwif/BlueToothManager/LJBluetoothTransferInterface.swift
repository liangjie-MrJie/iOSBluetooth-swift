//
//  LJBluetoothTransferInterface.swift
//  CoreBluetoothWithSwif
//
//  Created by liangjie on 16/5/9.
//  Copyright © 2016年 liangjie. All rights reserved.
//

import Foundation

/// key of retrieve device
let DeviceInfoNameKey       = "DeviceInfoNameKey"
let DeviceInfoIdentifierKey = "DeviceInfoIdentifierKey"
let DeviceInfoMacAddressKey = "DeviceInfoMacAddressKey"

/**
 *  通知相关
 */
let BlueToothCentralStateUpdateNotification = "BlueToothCentralStateUpdateKey"
let BlueToothCentralStateUpdateNotificationUserInfoKey = "BlueToothCentralStateUpdateNotificationUserInfoKey"

/**
 *  LJBLEManagerDelegate
 */
protocol LJBLEManagerDelegate: NSObjectProtocol {
    func scanDeviceCallBack(device: LJDevice)
    func connectStateCallBack(state: BlueToothConnectState)
}

enum BlueToochCentralState: Int {
    case Unknown
    case UnsupportedBLE
    case Unauthorized
    case PoweredOff
    case PoweredOn
    
    init(rawValue: Int) {
        switch rawValue {
        case 1:
            self = .UnsupportedBLE
        case 2:
            self = .Unauthorized
        case 3:
            self = .PoweredOff
        case 4:
            self = .PoweredOn
        default:
            self = .Unknown
        }
    }
}

enum BlueToothConnectState: Int {
    case Connecting
    case Connected
    case Disconnecting
    case Disconnected
}
enum ResponseResult: Int {
    case Succeed
    case Fault
    case Timeout
}
enum BlueToohTransferControl: Int {
    case Write
    case Timeout
    case Succeed
}

typealias ResponseResultCallBack = (result:ResponseResult, receiveData: NSData?) -> Void

class LJBluetoothTransferInterface: NSObject {
    
    // 单利
    static let instance = LJBluetoothTransferInterface()
    class func sharedInstance() -> LJBluetoothTransferInterface {
        return LJBluetoothTransferInterface.instance;
    }
    private override init() {
        self.ljbleShared = LJBLEManager.sharedInstance()
        super.init()
    }
    
    private var ljbleShared: LJBLEManager
    weak var delegate :LJBLEManagerDelegate? {
        willSet {
            self.ljbleShared.delegate = newValue
        }
    }
    
    /**
     获取当前连接的设备
     
     - returns: 当前设备
     */
    func takeCurrentDevice() -> LJDevice? {
        return self.ljbleShared.currentDevice
    }
    /**
     注册服务UUID
     
     - parameter uuids: uuids
     */
    func registerServiceUUID(uuids: [String]?) {
        self.ljbleShared.registerServiceUUID(uuids)
    }
    /**
     扫描设备
     
     - parameter timeOut: 超时时间
     */
    func scanDevice(timeout: NSTimeInterval=DefaultScanTimeout) {
        self.ljbleShared.scanDevice(timeout)
    }
    /**
     停止扫描设备
     */
    func stopScanDevice() {
        self.ljbleShared.stopScanDevice()
    }
    /**
     当前设备的连接状态
     
     - returns: BlueToochConnectState
     */
    func currentState() -> BlueToothConnectState {
        return self.ljbleShared.currentState()
    }
    /**
     找回设备对象
     
     - parameter deviceInfo: 包涵DeviceInfoNameKey
     DeviceInfoIdentifierKey
     DeviceInfoMacAddressKey
     - returns: 设备对象
     */
    func retrieveDeviceObject(deviceInfo: Dictionary<String, String>) -> LJDevice {
        return self.ljbleShared.retrieveDeviceObject(deviceInfo)
    }
    /**
     连接设备
     
     - parameter device: 设备对象
     */
    func connectToDevice(device: LJDevice) {
        self.ljbleShared.connectToDevice(device)
    }
    /**
     断开连接
     
     - parameter device: 设备对象
     */
    func disconnectDevice(device: LJDevice) {
        self.ljbleShared.disconnectDevice(device)
    }
    
    /**
     发送数据
     
     - parameter data:           待发送的数据
     - parameter timeout:        操时时间
     - parameter responseResult: 响应结果
     
     - returns: 是否发送成功
     */
    func sendData(data: NSData, timeout: NSTimeInterval, responseResult: ResponseResultCallBack?) -> Bool {
        return self.sendData(data, timeout: timeout, repeatCount: 0, responseResult: responseResult)
    }
    /**
     发送数据
     
     - parameter data:           待发送的数据
     - parameter repeatCount:    操时重发次数
     - parameter responseResult: 响应结果
     
     - returns: 是否发送成功
     */
    func sendData(data: NSData, repeatCount: Int8, responseResult: ResponseResultCallBack?) -> Bool {
        return self.sendData(data, timeout: 3, repeatCount: repeatCount, responseResult: responseResult)
    }
    /**
     发送数据
     
     - parameter data:           待发送的数据
     - parameter timeout:        操时时间
     - parameter repeatCount:    操时重发次数
     - parameter responseResult: 响应结果
     
     - returns: 是否发送成功
     */
    func sendData(data: NSData, timeout: NSTimeInterval=3, repeatCount: Int8=0, responseResult: ResponseResultCallBack?) -> Bool {
        return self.ljbleShared.sendData(data, timeout: timeout, repeatCount: repeatCount, responseResult: responseResult)
    }
}