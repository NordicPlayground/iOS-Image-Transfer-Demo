# iOS-image-transfer-demo

This app allows images to be streamed from an nRF52 kit with a connected camera sensor to the application, showing the image and measuring the transfer speed in the process.

Different image resolutions can be selected in the app, and the BLE phy can be changed between 1Mbps and 2Mbps to demonstrate the difference (this requires a phone that supports 2Mbps).

### Installation instructions:

- Download the appropriate firmware for your development kit [Here](https://github.com/NordicPlayground/nrf52-ble-image-transfer-demo)
- Power on your Development Kit.
- Plug in the Development Kit over USB to your computer.
- A new drive will appear on your computer (Mass Storage Device).
- Drag (or copy/paste) the appropriate hex file to that device.
- The Development Kit will now disconnect and reconnect, it is not programmed and ready.
- Open the Xcode project and build against your connected device (**Note:** iOS Simulators do not have BLE capabilities, so this demo will not work on the Simulator).

### App instructions:

- Launch the Image Transfer Demo app on your device.
- The app will scan for nearby peripherals (**Note:** If you can't discover your peripheral, make sure it's powered on and functional).
- Select the target peripheral from the list.
- The app will now connect and discover the services and characteristics on the peripheral.
- Press the PHY: LE 1M button to switch to 2M mode (if the iOS device does not support it, it'll grey out and stay at 1M), if 2M is supported, it'll switch to 2M and the button will grey out as it's not possible to switch back from 2M to 1M connections.
- Supported connections:
  - 1M
  - 2M
- Press the Resolution button to switch the resolution between:
  - 160 x 120
  - 320 x 240
  - 640 x 480
  - 800 x 600
  - 1024 x 768
  - 1600 x 1200
- Press take snapshot to receive an image from the Development Kit
- Press Start stream to start sending continuous images from the Development Kit (Pressing the button again will cause the stream to stop).
- During streaming and taking snapshots, the following labels will update to notify of connection properties:
  - Connection Interval: Displays the current connection interval.
  - MTU: Displays the current MTU.
  - Trasnfer rate: distlays the instantaneous transfer rate.
  - FPS: This will display the calculated framerate according to the current speed.
