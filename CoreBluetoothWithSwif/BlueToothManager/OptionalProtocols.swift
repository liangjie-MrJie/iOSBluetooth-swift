//
//  OptionalProtocols.swift
//  CoreBluetoothWithSwif
//
//  Created by liangjie on 16/4/27.
//  Copyright © 2016年 liangjie. All rights reserved.
//

import Foundation

extension LJBLEManagerDelegate {
    func scanDeviceCallBack(device: LJDevice) {}
    func connectStateCallBack(state: BlueToothConnectState) {}
}