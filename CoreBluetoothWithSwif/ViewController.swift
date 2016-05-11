//
//  ViewController.swift
//  CoreBluetoothWithSwif
//
//  Created by liangjie on 16/4/5.
//  Copyright © 2016年 liangjie. All rights reserved.
//

import UIKit

class ViewController: UIViewController, LJBLEManagerDelegate {
    
    let ljBLE = LJBluetoothTransferInterface.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(blutToochCenterStateUpdate(_:)), name: BlueToothCentralStateUpdateNotification, object: nil)
        ljBLE.delegate = self
        
        ljBLE.registerServiceUUID(["AC0F"])
    }
    
    @IBAction func startScanDevice(sender: UIButton) {
        self.ljBLE.scanDevice()
    }
    
    /*****LJBLEManagerDelegate Method*****/
    func blutToochCenterStateUpdate(notification: NSNotification) {
        var state = BlueToochCentralState.Unknown
        let value = notification.userInfo?[BlueToothCentralStateUpdateNotificationUserInfoKey]?.integerValue
        if value != nil {
            state = BlueToochCentralState(rawValue: value!)
        }
        switch state {
        case .UnsupportedBLE:
            print("不支持BLE4.0")
        case .Unauthorized:
            print("没有得到权限")
        case .PoweredOff:
            print("蓝牙是关闭的")
        case .PoweredOn:
            print("蓝牙是打开的")
        case .Unknown:
            print("蓝牙状态未知")
        }
    }
    func scanDeviceCallBack(device: LJDevice) {
        print("devie: \(device)")
        if device.name == "Sharkey-B1-10064" {
            self.ljBLE.connectToDevice(device)
        }
    }
    func connectStateCallBack(state: BlueToothConnectState) {
        switch state {
        case .Connected:
            print("连接成功!")
        case .Disconnected:
            print("断开连接!")
        default : break
        }
    }
    
    
    
    @IBAction func resetMakeDevice(sender: UIButton) {
        let queryBatteryLevel = self.batteryLevel(0x1d, length: 0)
        let flag = self.ljBLE.sendData(queryBatteryLevel, timeout: 3, repeatCount: 2) { (result, receiveData) in print("result: \(result) batteryLevel: \(receiveData)")
        }
        print("flag= \(flag)")
    }

    @IBAction func disconnectDevice(sender: UIButton) {
        let device = self.ljBLE.takeCurrentDevice()
        if device != nil {
            self.ljBLE.disconnectDevice(device!)
        }
    }
    
    
    func batteryLevel(code: UInt8, length: UInt8) -> NSData {
        let data = NSMutableData()
        
        var varCode = code
        var varLen = length
        
        data.appendBytes(&varCode, length: 1)
        data.appendBytes([UInt8(4)], length: 1)
        data.appendBytes([UInt8(0)], length: 1)
        data.appendBytes([UInt8(0)], length: 1)
        data.appendBytes(&varLen, length: 1)
        
        return data.copy() as! NSData
    }
   
}

