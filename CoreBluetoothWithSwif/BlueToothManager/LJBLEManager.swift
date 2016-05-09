
//
//  LJBLEManager.swift
//  CoreBluetoothWithSwif
//
//  Created by liangjie on 16/4/5.
//  Copyright © 2016年 liangjie. All rights reserved.
//

import Foundation
import CoreBluetooth


let DefaultScanTimeout = 10.0

class LJDevice: NSObject {
    private(set) var name: String!
    private(set) var identifier: String!
    private(set) var macAddress: String?
    private(set) var peripheral: CBPeripheral!
    
    override var description: String {
        var state: String!
        switch peripheral.state {
        case .Connected:
            state = "Connected"
        case .Connecting:
            state = "Connecting"
        case .Disconnected:
            state = "Disconnected"
        case .Disconnecting:
            state = "Disconnecting"
        }
        return "name: \(name)\n identifier:\(identifier)\n macAddress:\(macAddress)\n connectState:\(state)\n"
    }
}

typealias WriteResultCallBack = (Bool) -> Void

class LJBLEManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // 私有属性, 有关于蓝牙
    private var centralManage: CBCentralManager!
    private var serviceUUIDs: [CBUUID]?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?
    weak var delegate :LJBLEManagerDelegate?
    
    // 私有属性
    private(set) var currentDevice: LJDevice?
    private var characteristicNotifyTotals = 0
    private var characteristicNotifyResponseCount = 0
    
    private let LJBLEManagerSerialQueue = dispatch_queue_create("LJBLEManagerSerialQueue", DISPATCH_QUEUE_SERIAL)
    private var receiveData: NSMutableData
    private var LJBLESendDataQueue: [BlueToothDataPacker] = []
    private var LJBLEWaitRespondQueue: [BlueToothDataPacker] = []
    
    // 相关回调
    private var writeResult: WriteResultCallBack?
    
    // 单利
    static let instance = LJBLEManager()
    class func sharedInstance() -> LJBLEManager {
        return LJBLEManager.instance;
    }
    private override init() {
        self.receiveData = NSMutableData()
        super.init()
        self.centralManage = CBCentralManager(delegate: self, queue: LJBLEManagerSerialQueue)
        self.centralManage.delegate = self
    }
    
    /***** 公开的方法 *****/
    ////////////////////////////
    func registerServiceUUID(uuids: [String]?) {
        self.serviceUUIDs = Array()
        for uuid in uuids! {
            self.serviceUUIDs?.append(CBUUID(string: uuid))
        }
    }
    func scanDevice(timeout: NSTimeInterval=DefaultScanTimeout) {
        let peripherals = self.centralManage.retrieveConnectedPeripheralsWithServices(self.serviceUUIDs!)
        for peripheral in peripherals {
            self.notifyScanResult(peripheral, macAddress: nil)
        }
        self.centralManage.scanForPeripheralsWithServices(self.serviceUUIDs, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        self.performSelector(#selector(LJBLEManager.scanTimeout), withObject: nil, afterDelay: timeout)
    }
    func stopScanDevice() {
        self.centralManage.stopScan()
    }
    func currentState() -> BlueToothConnectState {
        var state = BlueToothConnectState.Disconnected
        if self.currentDevice != nil {
            switch self.currentDevice!.peripheral.state {
            case .Connecting:
                state = .Connecting
            case .Connected:
                state = .Connected
            case .Disconnected:
                state = .Disconnected
            case .Disconnecting:
                state = .Disconnecting
            }
        }
        
        return state
    }
    func retrieveDeviceObject(deviceInfo: Dictionary<String, String>) -> LJDevice {
        let device = LJDevice()
        device.name = deviceInfo[DeviceInfoNameKey]!
        device.identifier = deviceInfo[DeviceInfoIdentifierKey]!
        device.macAddress = deviceInfo[DeviceInfoMacAddressKey]!
        let peripherals = self.centralManage.retrievePeripheralsWithIdentifiers([NSUUID(UUIDString: device.identifier)!])
        device.peripheral = peripherals.first
        
        return device
    }
    func connectToDevice(device: LJDevice) {
        self.centralManage.connectPeripheral(device.peripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey : true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey : true,
            CBConnectPeripheralOptionNotifyOnNotificationKey : true])
        self.currentDevice = device
    }
    func disconnectDevice(device: LJDevice) {
        self.centralManage.cancelPeripheralConnection(device.peripheral)
    }
    func sendData(data: NSData, timeout: NSTimeInterval=3, repeatCount: Int8=0, responseResult: ResponseResultCallBack?) -> Bool {
        var result = false
        if self.currentState() == .Connected {
            let task = BlueToothDataPacker(data: data, timeout: timeout, repeatCount: repeatCount, responseResult: responseResult)
            let canWrite = self.blueToothTransferControl(.Write, task: task)
            if canWrite {
                self.writeResult = {flag in result = flag}
                task.wait()
            }
        }
        else {
            responseResult?(result: .Fault, receiveData: nil)
        }
        
        return result
    }
    
    
    
    /***** 私有方法 *****/
    /////////////////////////////////////////
    @objc private func scanTimeout() {
        self.stopScanDevice()
    }
    private func clearVariable() {
        LJBLESendDataQueue.removeAll()
        LJBLEWaitRespondQueue.removeAll()
        self.writeCharacteristic = nil
        self.readCharacteristic = nil
        self.currentDevice = nil
        self.characteristicNotifyTotals = 0
        self.characteristicNotifyResponseCount = 0
        self.clearResponseData()
    }
    private func notifyScanResult(peripheral: CBPeripheral, macAddress: String?) {
        let device = self.makeDevice(peripheral, macAddress: macAddress)
        delegate?.scanDeviceCallBack(device)
    }
    private func makeDevice(peripheral: CBPeripheral, macAddress: String?) ->LJDevice {
        let device = LJDevice()
        device.name = peripheral.name
        device.identifier = peripheral.identifier.UUIDString
        device.macAddress = macAddress
        device.peripheral = peripheral
        
        return device
    }
    private func errorLog(error: NSError?) -> Bool {
        if error != nil {
            print("error: \(error!.localizedDescription)")
            return true
        }
        
        return false
    }
    private func clearResponseData() {
        self.receiveData.length = 0
    }
    private func writeDataToBluetooth() {
        if self.queueCount(true) > 0 && self.currentState() == .Connected {
            let task = self.getQueueHead(true)
            var needSend = true
            var sendAmount = 0, sendIndex = 0
            var writeType = CBCharacteristicWriteType.WithoutResponse
            while needSend {
                sendAmount = task.sendData.length - sendIndex
                sendAmount = sendAmount > 20 ? 20 : sendAmount
                let data = NSData(bytes: task.sendData.bytes + sendIndex, length: sendAmount)
                sendIndex += sendAmount
                if sendIndex >= task.sendData.length {
                    needSend = false
                    writeType = .WithResponse
                }
                self.currentDevice?.peripheral.writeValue(data, forCharacteristic: self.writeCharacteristic!, type: writeType)
            }
            print("send data: \(task.sendData)")
            task.canWrite = false
        }
    }
    /**
     判定是否是玩家想要得到的全部数据
     
     - parameter receiveData: 蓝牙返回来的数据
     
     - returns: true／false
     */
    private func responseDataAnalyse(receiveData: NSData) -> Bool {
        var needDataLength = -1
        let headerLength = ResponseDataPack.Data;
        let headerExtendLength = ResponseDataPack.ExtendData;
        if (receiveData.length >= headerLength)
        {
            var packLength : UInt8 = 0
            receiveData.getBytes(&packLength, range: NSRange(location: ResponseDataPack.Length, length: 1))
            if (packLength < 0xFF)
            {
                needDataLength = headerLength + Int(packLength);
            }
            else if (receiveData.length >= headerExtendLength)
            {
                var extendLength: UInt16 = 0
                receiveData.getBytes(&extendLength, range: NSRange(location: ResponseDataPack.ExtendLength, length: sizeof(UInt16)))
                needDataLength = headerExtendLength + Int(extendLength)
            }
        }
        
        return (needDataLength >= 0 && receiveData.length >= needDataLength) ? true : false
    }
    private func enqueueControler(task: BlueToothDataPacker) {
        LJBLESendDataQueue.append(task)
        LJBLEWaitRespondQueue.append(task)
    }
    private func dequeueControler(isSendQueue: Bool) {
        if isSendQueue {
            if LJBLESendDataQueue.count > 0 {
                LJBLESendDataQueue.removeFirst()
            }
        }
        else {
            if LJBLEWaitRespondQueue.count > 0 {
                LJBLEWaitRespondQueue.removeFirst()
            }
        }
    }
    private func queueCount(isSendQueue: Bool) -> Int {
        if isSendQueue {
            return LJBLESendDataQueue.count
        }
        else {
            return LJBLEWaitRespondQueue.count
        }
    }
    private func getQueueHead(isSendQueue: Bool) -> BlueToothDataPacker {
        if isSendQueue {
            if LJBLESendDataQueue.count > 0 {
                return LJBLESendDataQueue.first!
            }
        }
        else {
            if LJBLEWaitRespondQueue.count > 0 {
                return LJBLEWaitRespondQueue.first!
            }
        }
        //print("Queue not task, Not to write a Bluetooth operation!")
        return BlueToothDataPacker(data: NSData(bytes: nil, length: 0), timeout:0, repeatCount: 0, responseResult: nil)
    }
    private func recoverQueueHead(isSendQueue: Bool, task: BlueToothDataPacker) {
        if isSendQueue {
            LJBLESendDataQueue.insert(task, atIndex: 0)
        }
        else {
            LJBLEWaitRespondQueue.insert(task, atIndex: 0)
        }
    }
    private func blueToothTransferControl(transferControl: BlueToohTransferControl, task: BlueToothDataPacker) -> Bool {
        switch transferControl {
        case .Write:
            self.enqueueControler(task)
        case .Timeout:
            if task.repeatCount <= 0 {
                task.responseResult?(result: ResponseResult.Timeout, receiveData: nil)
                self.dequeueControler(false)
            }
            else {
                task.canWrite = true
                self.recoverQueueHead(true, task: task)
                task.repeatCount -= 1
            }
        case .Succeed:
            self.dequeueControler(false)
        }
        
        let flag = self.getQueueHead(true).canWrite
        if flag {
            self.writeDataToBluetooth()
        }
        
        return flag
    }
    @objc private func responseTimeout() {
        let timeoutTask = self.getQueueHead(false)
        /*
        timeoutTask.canWrite = true
        timeoutTask.repeatCount -= 1
        if timeoutTask.repeatCount < 0 {
            self.dequeueControler(false)
            timeoutTask.responseResult?(result: .Timeout, receiveData: nil)
        }
        self.writeDataToBluetooth() 
        */
        self.blueToothTransferControl(.Timeout, task: timeoutTask)
    }
    
    /***** 蓝牙代理方法实现 *****/
    ///////////////////
    func centralManagerDidUpdateState(central: CBCentralManager) {
        var centralState = BlueToochCentralState.Unknown
        switch central.state {
        case .Unknown: centralState = .Unknown
            
        case .Resetting: print("蓝牙重新接入")
            
        case .Unsupported: centralState = .UnsupportedBLE 
            
        case .Unauthorized: centralState = .Unauthorized
            
        case .PoweredOff: centralState = .PoweredOff; self.clearVariable()
            
        case .PoweredOn: centralState = .PoweredOn
        }
        NSNotificationCenter.defaultCenter().postNotificationName(BlueToothCentralStateUpdateNotification, object: self, userInfo: [BlueToothCentralStateUpdateNotificationUserInfoKey : NSNumber(integer: centralState.rawValue)])
    }
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let macData = advertisementData[CBAdvertisementDataManufacturerDataKey] as! NSData
        let macAddress = Utils.macAddressFromManufacturerData(macData)
        self.notifyScanResult(peripheral, macAddress: macAddress)
    }
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("connect to peripheral:\(peripheral.name)")
        self.stopScanDevice()
        peripheral.delegate = self
        peripheral.discoverServices(self.serviceUUIDs)
    }
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.errorLog(error)
        self.currentDevice = nil
        dispatch_async(dispatch_get_main_queue()) {
            self.delegate?.connectStateCallBack(BlueToothConnectState.Disconnected)
        }
    }
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        if self.errorLog(error) {return}
        self.clearVariable()
        dispatch_async(dispatch_get_main_queue()) { 
            self.delegate?.connectStateCallBack(BlueToothConnectState.Disconnected)
        }
    }
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if self.errorLog(error) {return}
        self.characteristicNotifyTotals = 0
        self.characteristicNotifyResponseCount = 0
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if self.errorLog(error) {return}
        for charcteristice in service.characteristics! {
            if charcteristice.properties.rawValue&CBCharacteristicProperties.Write.rawValue
                || charcteristice.properties.rawValue&CBCharacteristicProperties.WriteWithoutResponse.rawValue
            {
                self.writeCharacteristic = charcteristice
            }
            else if charcteristice.properties.rawValue&CBCharacteristicProperties.Read.rawValue {
                self.readCharacteristic = charcteristice
            }
            else if charcteristice.properties.rawValue&CBCharacteristicProperties.Notify.rawValue
                || charcteristice.properties.rawValue&CBCharacteristicProperties.Indicate.rawValue
            {   
                peripheral.setNotifyValue(true, forCharacteristic: charcteristice)
                self.characteristicNotifyTotals += 1
            }
        }
    }
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if self.errorLog(error) {return}
        self.characteristicNotifyResponseCount += 1
        print("received number \(self.characteristicNotifyResponseCount) notification response.(total: \(self.characteristicNotifyTotals))")
        if self.characteristicNotifyResponseCount == self.characteristicNotifyTotals {
            dispatch_async(dispatch_get_main_queue(), { 
                self.delegate?.connectStateCallBack(BlueToothConnectState.Connected)
            })
        }
    }
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        let currentTask = self.getQueueHead(true)
        self.dequeueControler(true)
        if self.errorLog(error) {
            self.writeResult?(false)
        }
        else {
            self.writeResult?(true)
            dispatch_async(dispatch_get_main_queue(), {
                self.performSelector(#selector(LJBLEManager.responseTimeout), withObject: nil, afterDelay: currentTask.timeout)
            })
        }
        
        currentTask.signal()
    }
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if self.errorLog(error) {return}
        
        self.receiveData.appendData(characteristic.value!)
        if self.responseDataAnalyse(self.receiveData) {
            dispatch_async(dispatch_get_main_queue(), { 
                NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(LJBLEManager.responseTimeout), object: nil)
            })
            let task = self.getQueueHead(false)
            task.responseResult?(result: ResponseResult.Succeed, receiveData: self.receiveData)
            self.clearResponseData()
            self.blueToothTransferControl(.Succeed, task: task)
        }
        
    }

    
}


