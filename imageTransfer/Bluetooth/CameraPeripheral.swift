//
//  PeripheralManager.swift
//  imageTransfer
//
//  Created by Mostafa Berg on 27/09/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit
import CoreBluetooth

enum ImageServiceCommand: UInt8 {
    case noCommand          = 0x00
    case startSingleCapture = 0x01
    case startStreaming     = 0x02
    case stopStreaming      = 0x03
    case changeResolution   = 0x04
    case changePhy          = 0x05
    case sendBleParameters  = 0x06
    
    func data() -> Data {
        return Data(bytes: [self.rawValue])
    }
}

enum InfoResponse: UInt8 {
    case unknown = 0x00
    case imgInfo = 0x01
    case bleInfo = 0x02
}

enum ImageResolution: UInt8 {
    case resolution160x120   = 0x01
    case resolution320x240   = 0x02
    case resolution640x480   = 0x03
    case resolution800x600   = 0x04
    case resolution1024x768  = 0x05
    case resolution1600x1200 = 0x06
    
    func description() -> String {
        switch self {
            case .resolution160x120:
                return "160x120"
            case .resolution320x240:
                return "320x240"
            case .resolution640x480:
                return "640x480"
            case .resolution800x600:
                return "800x600"
            case .resolution1024x768:
                return "1024x768"
            case .resolution1600x1200:
                return "1600x1200"
        }
    }
}

enum PhyType: UInt8 {
    case phyLE1M   = 0x01
    case phyLE2M   = 0x02
    
    func description() -> String {
        switch self {
            case .phyLE1M:
                return "LE 1M"
            case .phyLE2M:
                return "LE 2M"
        }
    }
}

class CameraPeripheral: NSObject, CBPeripheralDelegate {
    //MARK: - Service Identifiers
    public static let imageServiceUUID            = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA3E")
    public static let imageRXCharacteristicUUID   = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA3E")
    public static let imageTXCharacteristicUUID   = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA3E")
    public static let imageInfoCharacteristicUUID = CBUUID(string: "6E400004-B5A3-F393-E0A9-E50E24DCCA3E")
    
    //MARK: - Properties
    public var targetPeripheral        : CBPeripheral
    public var delegate                : CameraPeripheralDelegate?
    private var imageInfoCharacteristic : CBCharacteristic!
    private var imageRXCharacteristic   : CBCharacteristic!
    private var imageTXCharacteristic   : CBCharacteristic!
    private var snapshotData            : Data         = Data()
    private var currentImageSize        : Int          = 0
    private var imageStartTime          : TimeInterval = 0
    private var imageElapsedTime        : TimeInterval = 0
    private var streamStartTime         : TimeInterval = 0
    private var transferRate            : Double       = 0
    private var framesCount             : Int          = 0
    
    required init(withPeripheral aPeripheral: CBPeripheral) {
        targetPeripheral = aPeripheral
        super.init()
        targetPeripheral.delegate = self
    }

    public func basePeripheral() -> CBPeripheral {
        return targetPeripheral
    }
    
    //MARK: - ImageService API
    public func getBleParameters() {
        targetPeripheral.writeValue(ImageServiceCommand.sendBleParameters.data(), for: imageRXCharacteristic, type: .withoutResponse)
    }

    public func changePhy(_ aPhy: PhyType) {
        var changePhyCommand = ImageServiceCommand.changePhy.data()
        //The Raw value is decremented because phy command takes 0 for Phy1 and 1 for Phy2
        //However, the reported values in the ble connection info update will be 1 for Phy1 and 2 for Phy2
        //So the change phy command is offset by 1 to compensate.
        //See: https://github.com/NordicPlayground/nrf52-ble-image-transfer-demo/blob/master/main.c#L905
        changePhyCommand.append(contentsOf: [aPhy.rawValue - 1])
        targetPeripheral.writeValue(changePhyCommand, for: imageRXCharacteristic, type: .withoutResponse)
    }
    
    public func changeResolution(_ aResolution : ImageResolution) {
        var changeResolutionCommand = ImageServiceCommand.changeResolution.data()
        changeResolutionCommand.append(contentsOf: [aResolution.rawValue])
        targetPeripheral.writeValue(changeResolutionCommand, for: imageRXCharacteristic, type: .withoutResponse)
    }

    public func stopStream() {
        snapshotData = Data()
        targetPeripheral.writeValue(ImageServiceCommand.stopStreaming.data(), for: imageRXCharacteristic, type: .withoutResponse)
    }

    public func startStream() {
        streamStartTime = Date().timeIntervalSince1970
        framesCount = 0
        snapshotData = Data()
        targetPeripheral.writeValue(ImageServiceCommand.startStreaming.data(), for: imageRXCharacteristic, type: .withoutResponse)
    }
    
    public func takeSnapshot() {
        streamStartTime = Date().timeIntervalSince1970
        framesCount = 0
        snapshotData = Data()
        targetPeripheral.writeValue(ImageServiceCommand.startSingleCapture.data(), for: imageRXCharacteristic, type: .withoutResponse)
    }
    
    //MARK: - Bluetooth API
    public func discoverServices() {
        targetPeripheral.discoverServices([CameraPeripheral.imageServiceUUID])
    }
    
    public func enableNotifications() {
        guard imageRXCharacteristic != nil && imageTXCharacteristic != nil && imageInfoCharacteristic != nil else {
            return
        }
        targetPeripheral.setNotifyValue(true, for: imageTXCharacteristic)
        targetPeripheral.setNotifyValue(true, for: imageInfoCharacteristic)
    }

    //MARK: - CBPeripheralDelegate
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            delegate?.cameraPeripheral(self, failedWithError: error!)
            return
        }
        
        if let services = peripheral.services {
            // Check if the required service has been found
            guard services.count == 1 else {
                delegate?.cameraPeripheralNotSupported(self)
                return
            }
            
            // If the service was found, discover required characteristics
            for aService in services {
                if aService.uuid == CameraPeripheral.imageServiceUUID {
                    peripheral.discoverCharacteristics([CameraPeripheral.imageRXCharacteristicUUID,
                                                        CameraPeripheral.imageTXCharacteristicUUID,
                                                        CameraPeripheral.imageInfoCharacteristicUUID],
                                                       for: aService)
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            delegate?.cameraPeripheral(self, failedWithError: error!)
            return
        }
        
        if let characteristics = service.characteristics {
            // Assign references
            for aCharacteristic in characteristics {
                if aCharacteristic.uuid == CameraPeripheral.imageTXCharacteristicUUID {
                    imageTXCharacteristic = aCharacteristic
                } else if aCharacteristic.uuid == CameraPeripheral.imageRXCharacteristicUUID {
                    imageRXCharacteristic = aCharacteristic
                } else if aCharacteristic.uuid == CameraPeripheral.imageInfoCharacteristicUUID {
                    imageInfoCharacteristic = aCharacteristic
                }
            }
            
            // Check if all required characteristics were found
            guard imageRXCharacteristic != nil && imageTXCharacteristic != nil && imageInfoCharacteristic != nil else {
                delegate?.cameraPeripheralNotSupported(self)
                return
            }
            
            // Notify the delegate that the device is supported and ready
            delegate?.cameraPeripheralDidBecomeReady(self)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            delegate?.cameraPeripheral(self, failedWithError: error!)
            return
        }
        
        if characteristic == imageInfoCharacteristic {
            snapshotData.removeAll()
            let data = characteristic.value!
            let messageType = InfoResponse(rawValue: data[0]) ?? .unknown
            switch messageType {
            case .imgInfo:
                imageStartTime   = Date().timeIntervalSince1970
                transferRate     = 0
                currentImageSize = data.subdata(in: 1..<5).withUnsafeBytes { $0.pointee }
            case .bleInfo:
                let mtuSize = data.subdata(in: 1..<3).withUnsafeBytes { (ptr: UnsafePointer<UInt16>) -> UInt16 in return ptr.pointee }
                let connectionInterval = Float(data.subdata(in: 3..<5).withUnsafeBytes { (ptr: UnsafePointer<UInt16>) -> UInt16 in return ptr.pointee }) * 1.25
                
                //Phy types here will be the UInt8 value 1 or 2 for 1Mb and 2Mb respectively.
                let txPhy = PhyType(rawValue: data[5]) ?? .phyLE1M
                let rxPhy = PhyType(rawValue: data[6]) ?? .phyLE1M
                delegate?.cameraPeripheral(self, didUpdateParametersWithMTUSize: mtuSize, connectionInterval: connectionInterval, txPhy: txPhy, andRxPhy: rxPhy)
            default:
                break
            }
        } else if characteristic == imageTXCharacteristic {
            if let dataChunk = characteristic.value {
                snapshotData.append(dataChunk)
            }
            let now = Date().timeIntervalSince1970
            imageElapsedTime = now - imageStartTime
            transferRate     = Double(snapshotData.count) / imageElapsedTime * 8.0 / 1000.0 // convert bytes per second to kilobits per second
            
            if snapshotData.count == currentImageSize {
                framesCount += 1
                delegate?.cameraPeripheral(self, imageProgress: 1.0, transferRateInKbps: transferRate)
                delegate?.cameraPeripheral(self, didReceiveImageData: snapshotData, withFps: Double(framesCount) / (now - streamStartTime))
                snapshotData.removeAll()
            } else {
                let completion = Float(snapshotData.count) / Float(currentImageSize)
                delegate?.cameraPeripheral(self, imageProgress: completion, transferRateInKbps: transferRate)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            delegate?.cameraPeripheral(self, failedWithError: error!)
            return
        }
        if imageTXCharacteristic.isNotifying && imageInfoCharacteristic.isNotifying {
            delegate?.cameraPeripheralDidStart(self)
        }
    }
}
