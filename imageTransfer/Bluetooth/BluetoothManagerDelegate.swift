//
//  BluetoothManagerDelegate.swift
//  imageTransfer
//
//  Created by Mostafa Berg on 28/09/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BluetoothManagerDelegate {
    func bluetoothManager(_ aManager: BluetoothManager, didUpdateState state: CBManagerState)
    func bluetoothManager(_ aManager: BluetoothManager, didConnectPeripheral aPeripheral: CameraPeripheral)
    func bluetoothManager(_ aManager: BluetoothManager, didDisconnectPeripheral aPeripheral: CameraPeripheral)
}
