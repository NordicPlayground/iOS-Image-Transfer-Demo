//
//  CameraViewController.swift
//  imageTransfer
//
//  Created by Mostafa Berg on 28/09/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit
import CoreBluetooth

class CameraViewController: UIViewController, CameraPeripheralDelegate, BluetoothManagerDelegate {
    
    //MARK: - Outlets
    @IBOutlet weak var imageProgressIndicator: UIProgressView!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var resolutionButton: UIButton!
    @IBOutlet weak var phyButton: UIButton!
    @IBOutlet weak var connectionIntervalLabel: UILabel!
    @IBOutlet weak var mtuLabel: UILabel!
    @IBOutlet weak var transferRateLabel: UILabel!
    @IBOutlet weak var fpsLabel: UILabel!
    @IBOutlet weak var fpsLabelFrame: UIView!
    
    //MARK: - Actions
    @IBAction func phyButtonTapped(_ sender: Any) {
        handlePhyButtonTapped()
    }
    @IBAction func resolutionButtonTapped(_ sender: Any) {
        handleResolutionButtonTapped()
    }
    @IBAction func videoButtonTapped(_ sender: Any) {
        handleVideoButtonTapped()
    }
    @IBAction func cameraButtonTapped(_ sender: Any) {
        handleCameraButtonTapped()
    }
    
    //MARK: - Properties
    var bluetoothManager : BluetoothManager!
    var targetPeripheral : CameraPeripheral!
    private var isStreaming       : Bool              = false
    private var currentResolution : ImageResolution   = .resolution160x120
    private var currentPhy        : PhyType           = .phyLE1M
    private var loadingView: UIAlertController?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bluetoothManager.delegate = self
        targetPeripheral.delegate = self
        
        updateResolutionButtonTitle(currentResolution)
        imageProgressIndicator.progress = 0
        
        setRoundedCornerRadius(aRadius: 10, forView: cameraImageView)
        setRoundedCornerRadius(aRadius: 10, forView: videoButton)
        setRoundedCornerRadius(aRadius: 10, forView: cameraButton)
        setRoundedCornerRadius(aRadius: 10, forView: resolutionButton)
        setRoundedCornerRadius(aRadius: 10, forView: phyButton)
        setRoundedCornerRadius(aRadius: 10, forView: fpsLabelFrame)
        startCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        bluetoothManager.disconnect()
    }
    
    private func startCamera() {
        loadingView = UIAlertController(title: "Status", message: "Starting notifications...", preferredStyle: .alert)
        loadingView!.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
            self.navigationController!.popViewController(animated: true)
        })
        present(loadingView!, animated: false) {
            self.cameraPeripheralDidBecomeReady(self.targetPeripheral)
        }
    }

    private func setRoundedCornerRadius(aRadius : CGFloat, forView aView : UIView) {
        aView.layer.cornerRadius = aRadius
        aView.layer.masksToBounds = true
    }

    private func handlePhyButtonTapped() {
        if currentPhy == .phyLE2M {
            currentPhy = .phyLE1M
        } else {
            currentPhy = .phyLE2M
        }
        targetPeripheral.changePhy(currentPhy)
        updatePhyButtonTitle(currentPhy)
    }
    
    private func handleResolutionButtonTapped() {
        if currentResolution == .resolution1600x1200 {
            currentResolution = .resolution160x120
        } else {
            var rawValue = currentResolution.rawValue
            rawValue = rawValue + 1
            currentResolution = ImageResolution(rawValue: rawValue)!
        }
        targetPeripheral.changeResolution(currentResolution)
        updateResolutionButtonTitle(currentResolution)
    }
    
    private func handleVideoButtonTapped() {
        imageProgressIndicator.progress = 0
        
        if isStreaming {
            targetPeripheral.stopStream()
            videoButton.setTitle("📹 Start stream", for: .normal)
        } else {
            targetPeripheral.startStream()
            videoButton.setTitle("📹 Stop stream", for: .normal)
        }
        isStreaming = !isStreaming
    }
    
    private func handleCameraButtonTapped() {
        imageProgressIndicator.progress = 0
        targetPeripheral.takeSnapshot()
    }

    private func updateResolutionButtonTitle(_ aResolution: ImageResolution) {
        resolutionButton.setTitle("Resolution: \(aResolution.description())", for: .normal)
    }

    private func updatePhyButtonTitle(_ aPhy: PhyType) {
        phyButton.setTitle("PHY: \(aPhy.description())", for: .normal)
    }

    //MARK: - CameraPeripheralDelegate
    func cameraPeripheralDidBecomeReady(_ aPeripheral: CameraPeripheral) {
        loadingView!.message = "Reading parameters..."
        aPeripheral.enableNotifications()
    }
    
    func cameraPeripheralDidStart(_ aPeripheral: CameraPeripheral) {
        aPeripheral.getBleParameters()
    }
    
    func cameraPeripheralNotSupported(_ aPeripheral: CameraPeripheral) {
        // NOOP
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, failedWithError error: Error) {
        let alert = UIAlertController(title: "Status", message: "Error: \(error.localizedDescription)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
            self.navigationController!.popViewController(animated: true)
        })
        present(alert, animated: true, completion: nil)
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, didReceiveImageData someData: Data, withFps fps: Double) {
        if let anImage = UIImage(data: someData) {
            cameraImageView.image = anImage
        }
        fpsLabel.text = String(format:"FPS: %0.2f", fps)
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, imageProgress: Float, transferRateInKbps: Double) {
        imageProgressIndicator.progress = imageProgress
        transferRateLabel.text = String(format:"%0.2f kbps", transferRateInKbps)
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, didUpdateParametersWithMTUSize mtuSize: UInt16, connectionInterval connInterval: Float, txPhy: PhyType, andRxPhy rxPhy: PhyType) {
        if rxPhy == .phyLE1M && currentPhy == .phyLE2M {
            print("2mbps not supported")
            currentPhy = .phyLE1M
            phyButton.isEnabled = false
            phyButton.backgroundColor = UIColor.gray
        }
        if rxPhy == .phyLE2M && currentPhy == .phyLE1M {
            print("Changing back to PHY LE 1M not supported")
            currentPhy = .phyLE2M
        }
        
        connectionIntervalLabel.text = "\(connInterval) ms"
        mtuLabel.text = "\(mtuSize)(+3) bytes"
        updatePhyButtonTitle(rxPhy)
        
        loadingView?.dismiss(animated: true) {
            self.loadingView = nil
        }
    }
    
    //MARK: - BluetoothManagerDelegate
    
    func bluetoothManager(_ aManager: BluetoothManager, didDisconnectPeripheral aPeripheral: CameraPeripheral) {
        print("Disconnected")
        videoButton.isEnabled            = false
        cameraButton.isEnabled           = false
        resolutionButton.isEnabled       = false
        phyButton.isEnabled              = false
        videoButton.backgroundColor      = UIColor.gray
        cameraButton.backgroundColor     = UIColor.gray
        resolutionButton.backgroundColor = UIColor.gray
        phyButton.backgroundColor        = UIColor.gray
        
        let alert = UIAlertController(title: "Status", message: "Device disconnected", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { action in
            self.navigationController!.popViewController(animated: true)
        })
        present(alert, animated: true, completion: nil)
    }
    
    func bluetoothManager(_ aManager: BluetoothManager, didUpdateState state: CBManagerState) {
        if state != .poweredOn {
            print("Bluetooth OFF")
            bluetoothManager(aManager, didDisconnectPeripheral: targetPeripheral)
        }
    }
    
    func bluetoothManager(_ aManager: BluetoothManager, didConnectPeripheral aPeripheral: CameraPeripheral) {
        // NOOP
    }
}
