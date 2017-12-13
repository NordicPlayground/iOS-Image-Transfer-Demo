//
//  MainViewController.swift
//  imageTransfer
//
//  Created by Mostafa Berg on 27/09/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit
import CoreBluetooth

class MainViewController: UIViewController, BluetoothManagerDelegate, UITableViewDelegate, UITableViewDataSource, CameraPeripheralDelegate {

    //MARK: - Outlets and Actions
    @IBOutlet weak var noTargetsLabel: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bluetoothDisabledView: UIView!
    
    @IBAction func enableBluetooth(_ sender: UIButton) {
        bluetoothManager.enable()
    }
    
    //MARK: - Properties
    private var peripherals: [CameraPeripheral] = []
    private var bluetoothManager: BluetoothManager
    private var loadingView: UIAlertController?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    //MARK: - UIViewController
    required init?(coder aDecoder: NSCoder) {
        bluetoothManager = BluetoothManager()
        super.init(coder: aDecoder)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        bluetoothManager.delegate = self
        if bluetoothManager.state == .poweredOn {
            startScan()
        } else {
            bluetoothDisabledView.alpha = 1
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        stopScan()
    }
    
    //MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Skip the Header Clicked event
        guard indexPath.row > 0 else {
            return
        }
        // Deselect the row (there will be short click animation)
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard bluetoothManager.state == .poweredOn else {
            return
        }
        
        // Stop scanning and connect to selected peripheral
        stopScan()
        connect(to: peripherals[indexPath.row - 1])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count + 1 // 1 for the section header with activity indicator
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let header = tableView.dequeueReusableCell(withIdentifier: "section_cell", for: indexPath) as! SectionTableViewCell
            header.setEnabled(enabled: bluetoothManager.state == .poweredOn)
            return header
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "device_cell", for: indexPath)
        cell.textLabel?.text = peripherals[indexPath.row - 1].basePeripheral().name ?? "No name"
        return cell
    }
    
    //MARK: - CameraPeripheralDelegate
    func cameraPeripheralDidBecomeReady(_ aPeripheral: CameraPeripheral) {
        startCamera(with: aPeripheral)
    }
    
    func cameraPeripheralNotSupported(_ aPeripheral: CameraPeripheral) {
        print("Device not supported")
        loadingView!.message = "Device not supported"
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, failedWithError error: Error) {
        print("Error: \(error.localizedDescription)")
        loadingView!.message = "Operation failed:\n\(error.localizedDescription)"
    }
    
    func cameraPeripheralDidStart(_ aPeripheral: CameraPeripheral) {
        //NOOP
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, didReceiveImageData someData: Data, withFps fps: Double) {
        //NOOP
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, imageProgress: Float, transferRateInKbps: Double) {
        //NOOP
    }
    
    func cameraPeripheral(_ aPeripheral: CameraPeripheral, didUpdateParametersWithMTUSize mtuSize: UInt16, connectionInterval connInterval: Float, txPhy: PhyType, andRxPhy rxPhy: PhyType) {
        //NOOP
    }
    
    //MARK: - Implementation
    private func startScan() {
        // If the scanning was started again, remove all previous results to aviod duplicates
        if peripherals.isEmpty == false {
            peripherals.removeAll()
            tableView.reloadData()
            
            UIView.animate(withDuration: 0.2) {
                self.noTargetsLabel.alpha = 1
            }
        }
        
        print("Scanning started")
        bluetoothManager.scanForPeripherals(withDiscoveryHandler: { (aPeripheral, RSSI) in
            UIView.animate(withDuration: 0.5) {
                self.noTargetsLabel.alpha = 0
            }
            self.tableView.beginUpdates()
            self.peripherals.append(CameraPeripheral(withPeripheral: aPeripheral))
            self.tableView.insertRows(at: [IndexPath(row: 1, section: 0)], with: .automatic)
            self.tableView.endUpdates()
        })
    }
    
    private func stopScan() {
        bluetoothManager.stopScan()
        print("Scanning stopped")
    }
    
    private func connect(to aPeripheral: CameraPeripheral) {
        loadingView = UIAlertController(title: "Status", message: "Connecting to the camera...", preferredStyle: .alert)
        loadingView!.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
            // Clicking an action automatically dismisses the alert controller
            self.bluetoothManager.disconnect()
            self.loadingView = nil
        })
        present(loadingView!, animated: true) {
            aPeripheral.delegate = self
            print("Connecting...")
            self.bluetoothManager.connect(peripheral: aPeripheral)
        }
    }
    
    private func discoverServices(for aPeripheral: CameraPeripheral) {
        print("Discovering services...")
        loadingView!.message = "Discovering services..."
        aPeripheral.discoverServices()
    }
    
    private func startCamera(with aPeripheral: CameraPeripheral) {
        loadingView!.dismiss(animated: false)
        print("Ready")
        performSegue(withIdentifier: "showCameraControl", sender: aPeripheral)
    }
    
    //MARK: - BluetoothManagerDelegate
    func bluetoothManager(_ aManager: BluetoothManager, didUpdateState state: CBManagerState) {
        if state == .poweredOn {
            print("Bluetooth ON")
            bluetoothDisabledView.alpha = 0
            startScan()
        } else {
            stopScan()
            bluetoothDisabledView.alpha = 1
        }
        tableView.reloadData()
    }
    
    func bluetoothManager(_ aManager: BluetoothManager, didConnectPeripheral aPeripheral: CameraPeripheral) {
        print("Connected")
        discoverServices(for: aPeripheral)
    }
    
    func bluetoothManager(_ aManager: BluetoothManager, didDisconnectPeripheral aPeripheral: CameraPeripheral) {
        print("Disconnected")
        loadingView?.dismiss(animated: true) {
            self.loadingView = nil
        }
        startScan()
    }

    //MARK: - Segue handling
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return identifier == "showCameraControl"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCameraControl" {
            let cameraPeriperal = sender as! CameraPeripheral
            let cameraView = segue.destination as! CameraViewController
            cameraView.bluetoothManager = bluetoothManager
            cameraView.targetPeripheral = cameraPeriperal
        }
    }
}
