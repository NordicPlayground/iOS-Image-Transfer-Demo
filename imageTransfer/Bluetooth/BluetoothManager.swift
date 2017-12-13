//
//  BluetoothManager.swift
//  imageTransfer
//
//  Created by Mostafa Berg on 27/09/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit
import CoreBluetooth


class BluetoothManager: NSObject, CBCentralManagerDelegate {

    //MARK: - Properties
    let centralManager   : CBCentralManager
    var targetPeripheral : CameraPeripheral?
    var discoveryHandler : ((CBPeripheral, NSNumber) -> ())?
    var delegate         : BluetoothManagerDelegate?

    required override init() {
        centralManager = CBCentralManager()
        super.init()
        centralManager.delegate = self
    }
    
    public func enable() {
        let url = URL(string: UIApplicationOpenSettingsURLString) //for bluetooth setting
        let app = UIApplication.shared
        app.open(url!, options: [:], completionHandler: nil)
    }

    public func scanForPeripherals(withDiscoveryHandler aHandler: @escaping (CBPeripheral, NSNumber)->()) {
        guard centralManager.isScanning == false else {
            return
        }

        discoveryHandler = aHandler
        centralManager.scanForPeripherals(withServices: [CameraPeripheral.imageServiceUUID], options: nil)
    }
    
    public func stopScan() {
        guard centralManager.isScanning else {
            return
        }
        centralManager.stopScan()
        discoveryHandler = nil
    }
    
    public func connect(peripheral: CameraPeripheral) {
        guard targetPeripheral == nil else {
            // A peripheral is already connected
            return
        }
        targetPeripheral = peripheral
        centralManager.connect(peripheral.basePeripheral(), options: nil)
    }
    
    public func disconnect() {
        guard targetPeripheral != nil else {
            // No device connected at the moment
            return
        }
        centralManager.cancelPeripheralConnection(targetPeripheral!.basePeripheral())
    }
    
    public var state: CBManagerState {
        return centralManager.state
    }

    //MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.bluetoothManager(self, didUpdateState: central.state)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        delegate?.bluetoothManager(self, didConnectPeripheral: targetPeripheral!)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.bluetoothManager(self, didDisconnectPeripheral: targetPeripheral!)
        targetPeripheral = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        delegate?.bluetoothManager(self, didDisconnectPeripheral: targetPeripheral!)
        targetPeripheral = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        discoveryHandler?(peripheral, RSSI)
    }
}
