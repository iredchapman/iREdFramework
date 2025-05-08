import Foundation
import CoreBluetooth
import HealthKitFramework
import SportKitFramework
import UIKit
import SwiftUI


// MARK: MAIN Method
@MainActor
public final class iREdBluetooth: NSObject, ObservableObject, Sendable {
    @MainActor public static let shared = iREdBluetooth()
    
    // UserDefaults Keys
    private enum StorageKeys: String {
        case thermometer = "lastPairedThermometer"
        case oximeter = "lastPairedOximeter"
        case sphygmometer = "lastPairedSphygmometer"
        case jumpRope = "lastPairedJumpRope"
        case heartRate = "lastPairedHeartRate"
        case scale = "lastPairedScale"
    }
    
    // Delegates
    private weak var hkDelegate: HealthKitDelegate?
    private weak var skDelegate: SportKitDelegate?
    private weak var bleDelegate: BlueToothDelegate?
    
    private var centralManager: CBCentralManager!
    private var devices: [iRedDevice] = []
    private var currentDeviceType: iREdBluetoothDeviceType = .none
    
    // Services
    private var thermometerService: ThermometerService!
    private var oximeterService: OximeterService!
    private var sphygmometerService: BloodPressureMonitorService!
    private var scaleService: SportKitFramework.ScaleService!
    private var jumpRopeService: JumpRopeService!
    private var heartrateProfile: HeartrateProfile!
    
    // Data
    @Published private(set) public var iredDeviceData: iRedDeviceData = iRedDeviceData()
    
    private var startPairingningAlert: UIAlertController? = nil
    private var connectingLoadingAlert: UIAlertController? = nil
    private var currentUUIDString: String? = nil
    private var currentPeripheral: CBPeripheral? = nil
    
    private var lastPairedThermometer: PairedDeviceModel? {
        didSet { saveDevice(lastPairedThermometer, forKey: .thermometer) }
    }
    private var lastPairedOximeter: PairedDeviceModel? {
        didSet { saveDevice(lastPairedOximeter, forKey: .oximeter) }
    }
    private var lastPairedSphygmometer: PairedDeviceModel? {
        didSet { saveDevice(lastPairedSphygmometer, forKey: .sphygmometer) }
    }
    private var lastPairedJumpRope: PairedDeviceModel? {
        didSet { saveDevice(lastPairedJumpRope, forKey: .jumpRope) }
    }
    private var lastPairedHeartRate: PairedDeviceModel? {
        didSet { saveDevice(lastPairedHeartRate, forKey: .heartRate) }
    }
    private var lastPairedScale: PairedDeviceModel? {
        didSet { saveDevice(lastPairedScale, forKey: .scale) }
    }
    
    @Published private var setRSSI: Int = -60
    
    public override init() {
        super.init()
        
        initPairedDevices()
        
        centralManager = CBCentralManager(delegate: self, queue: .main)
        
        thermometerService = ThermometerService()
        thermometerService.delegate = self
        
        oximeterService = OximeterService()
        oximeterService.delegate = self
        
        sphygmometerService = BloodPressureMonitorService()
        sphygmometerService.delegate = self
        
        scaleService = ScaleService()
        scaleService.delegate = self
        
        jumpRopeService = JumpRopeService()
        jumpRopeService.delegate = self
        
        heartrateProfile = HeartrateProfile()
        heartrateProfile.delegate = self
    }
    
    init(delegate: AnyObject? = nil) {
        hkDelegate = delegate as? HealthKitDelegate
        skDelegate = delegate as? SportKitDelegate
        bleDelegate = delegate as? BlueToothDelegate
    }
    
    // Start pairing
    @MainActor public func startPairing(to deviceType: iREdBluetoothDeviceType) {
        debugPrint("正在配对: ", deviceType.rawValue)
        switch deviceType {
        case .thermometer:
            iredDeviceData.thermometerData = .empty
            iredDeviceData.thermometerData.state.isPairing = true
            lastPairedThermometer = nil
        case .oximeter:
            iredDeviceData.oximeterData = .empty
            iredDeviceData.oximeterData.state.isPairing = true
            lastPairedOximeter = nil
        case .sphygmometer:
            iredDeviceData.sphygmometerData = .empty
            iredDeviceData.sphygmometerData.state.isPairing = true
            lastPairedSphygmometer = nil
        case .jumpRope:
            iredDeviceData.jumpRopeData = .empty
            iredDeviceData.jumpRopeData.state.isPairing = true
            lastPairedJumpRope = nil
        case .heartRateBelt:
            iredDeviceData.heartRateData = .empty
            iredDeviceData.heartRateData.state.isPairing = true
            lastPairedHeartRate = nil
        case .scale:
            iredDeviceData.scaleData = .empty
            iredDeviceData.scaleData.state.isPairing = true
            lastPairedScale = nil
        default:
            break
        }
        currentUUIDString = nil
        currentDeviceType = deviceType
        centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    // Stop pairing
    public func stopPairing() {
        iredDeviceData.thermometerData.state.isPairing = false
        iredDeviceData.oximeterData.state.isPairing = false
        iredDeviceData.sphygmometerData.state.isPairing = false
        iredDeviceData.jumpRopeData.state.isPairing = false
        iredDeviceData.heartRateData.state.isPairing = false
        iredDeviceData.scaleData.state.isPairing = false
        
        iredDeviceData.scaleData.state.isMeasuring = false
        iredDeviceData.scaleData.state.isMeasurementCompleted = false
        centralManager.stopScan()
        debugPrint("stop pairing")
    }
    
    // Connecting device
    /*
    private func connect(to device: iRedDevice) {
        switch device.deviceType {
        case .thermometer:
            if !iredDeviceData.thermometerData.state.isConnected {
                iredDeviceData.thermometerData.state.isConnecting = true
            }
        case .oximeter:
            if !iredDeviceData.oximeterData.state.isConnected {
                iredDeviceData.oximeterData.state.isConnecting = true
            }
        case .sphygmometer:
            if !iredDeviceData.sphygmometerData.state.isConnected {
                iredDeviceData.sphygmometerData.state.isConnecting = true
            }
        case .jumpRope:
            if !iredDeviceData.jumpRopeData.state.isConnected {
                iredDeviceData.jumpRopeData.state.isConnecting = true
            }
        case .heartRateBelt:
            if !iredDeviceData.heartRateData.state.isConnected {
                iredDeviceData.heartRateData.state.isConnecting = true
            }
        case .scale:
            if !iredDeviceData.scaleData.state.isConnected {
                iredDeviceData.scaleData.state.isConnecting = true
            }
        default:
            break
        }
        // connectingLoadingAlert = iREdAlert.shared.showLoadingAlert(title: "Connecting", message: "Connecting to \(device.name)...")
        // Avoid duplicate connections
        if let idx = devices.firstIndex(where: { $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }) {
            if !devices[idx].isConnected {
                centralManager.connect(device.peripheral, options: nil)
            }
        }
    }
     */
    
    /*
    @MainActor public func connect(from deviceType: iREdBluetoothDeviceType) {
        switch deviceType {
        case .thermometer:
            if let lastPairedThermometer, !iredDeviceData.thermometerData.state.isConnected {
                iredDeviceData.thermometerData.state.isConnecting = true
                connect(byUUIDString: lastPairedThermometer.uuidString)
            }
        case .oximeter:
            if let lastPairedOximeter, !iredDeviceData.oximeterData.state.isConnected {
                iredDeviceData.oximeterData.state.isConnecting = true
                connect(byUUIDString: lastPairedOximeter.uuidString)
            }
        case .sphygmometer:
            if let lastPairedSphygmometer, !iredDeviceData.sphygmometerData.state.isConnected {
                iredDeviceData.sphygmometerData.state.isConnecting = true
                connect(byUUIDString: lastPairedSphygmometer.uuidString)
            }
        case .jumpRope:
            if let lastPairedJumpRope, !iredDeviceData.jumpRopeData.state.isConnected {
                /// print("Start connecting the jump rope")
                iredDeviceData.jumpRopeData.state.isConnecting = true
                connect(byUUIDString: lastPairedJumpRope.uuidString)
            }
        case .heartRateBelt:
            if let lastPairedHeartRate, !iredDeviceData.heartRateData.state.isConnected {
                iredDeviceData.heartRateData.state.isConnecting = true
                connect(byUUIDString: lastPairedHeartRate.uuidString)
            }
        case .scale:
            if let lastPairedScale, !iredDeviceData.scaleData.state.isConnected {
                iredDeviceData.scaleData.state.isConnecting = true
                connect(byUUIDString: lastPairedScale.uuidString)
            }
        default:
            break
        }
//        if let i = devices.firstIndex(where: { $0.deviceType == deviceType }) {
//            connect(to: devices[i])
//        }
    }
    */
    @MainActor public func connect(from deviceType: iREdBluetoothDeviceType) {
        initPairedDevices()
        currentDeviceType = deviceType
        switch deviceType {
        case .thermometer:
            if let lastPairedThermometer, !iredDeviceData.thermometerData.state.isConnected {
                iredDeviceData.thermometerData.state.isConnecting = true
                currentUUIDString = lastPairedThermometer.uuidString
                centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        case .oximeter:
            if let lastPairedOximeter, !iredDeviceData.oximeterData.state.isConnected {
                iredDeviceData.oximeterData.state.isConnecting = true
                currentUUIDString = lastPairedOximeter.uuidString
                centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        case .sphygmometer:
            if let lastPairedSphygmometer, !iredDeviceData.sphygmometerData.state.isConnected {
                iredDeviceData.sphygmometerData.state.isConnecting = true
                currentUUIDString = lastPairedSphygmometer.uuidString
                centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        case .jumpRope:
            if let lastPairedJumpRope, !iredDeviceData.jumpRopeData.state.isConnected {
                iredDeviceData.jumpRopeData.state.isConnecting = true
                currentUUIDString = lastPairedJumpRope.uuidString
                centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        case .heartRateBelt:
            if let lastPairedHeartRate, !iredDeviceData.heartRateData.state.isConnected {
                iredDeviceData.heartRateData.state.isConnecting = true
                currentUUIDString = lastPairedHeartRate.uuidString
                centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        case .scale:
            if let lastPairedScale, !iredDeviceData.scaleData.state.isConnected {
                iredDeviceData.scaleData.state.isConnecting = true
                currentUUIDString = lastPairedScale.uuidString
                centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        default:
            break
        }
    }
    @MainActor public func connect(byUUIDString uuid: String) {
        currentUUIDString = uuid
        startPairing(to: .all_ired_devices)
        //        centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    // disconnect
    public func disconnect(from device: iRedDevice) {
        centralManager.cancelPeripheralConnection(device.peripheral)
    }
    
    // Disconnect by device type
    public func disconnect(from deviceType: iREdBluetoothDeviceType) {
        if deviceType == .all_ired_devices {
            for device in devices {
                centralManager.cancelPeripheralConnection(device.peripheral)
            }
        }
        let device = devices.filter { $0.deviceType == deviceType }.first
        if let device = device {
            centralManager.cancelPeripheralConnection(device.peripheral)
        }
    }
    
    private func deviceTypeByPeripheralName(_ name: String) -> iREdBluetoothDeviceType {
        var deviceType: iREdBluetoothDeviceType = .none
        if name.contains("AOJ-20A") || name.contains("iREd_THERM")  {
            deviceType = .thermometer
        } else if name.contains("AAA002") {
            deviceType = .scale
        } else if name.contains("AOJ-30B") || name.contains("iREd_BPM") {
            deviceType = .sphygmometer
        } else if name.contains("AOJ-70B") || name.contains("iREd_OXI") {
            deviceType = .oximeter
        } else if name.contains("QN-Rope") {
            deviceType = .jumpRope
        } else if name.contains("CL8") {
            deviceType = .heartRateBelt
        }
        return deviceType
    }
}

// MARK: 持久化存储
extension iREdBluetooth {
    private func initPairedDevices() {
        self.lastPairedThermometer = loadDevice(.thermometer)
        self.lastPairedOximeter = loadDevice(.oximeter)
        self.lastPairedSphygmometer = loadDevice(.sphygmometer)
        self.lastPairedJumpRope = loadDevice(.jumpRope)
        self.lastPairedHeartRate = loadDevice(.heartRate)
        self.lastPairedScale = loadDevice(.scale)

        // 设置是否已配对
        iredDeviceData.jumpRopeData.state.isPaired = lastPairedJumpRope != nil
        iredDeviceData.heartRateData.state.isPaired = lastPairedHeartRate != nil
        iredDeviceData.thermometerData.state.isPaired = lastPairedThermometer != nil
        iredDeviceData.oximeterData.state.isPaired = lastPairedOximeter != nil
        iredDeviceData.sphygmometerData.state.isPaired = lastPairedSphygmometer != nil
        iredDeviceData.scaleData.state.isPaired = lastPairedScale != nil

        // 设置 macAddress 和 peripheralName
        iredDeviceData.jumpRopeData.data.macAddress = lastPairedJumpRope?.macAddress
        iredDeviceData.jumpRopeData.data.peripheralName = lastPairedJumpRope?.name

        iredDeviceData.heartRateData.data.macAddress = lastPairedHeartRate?.macAddress
        iredDeviceData.heartRateData.data.peripheralName = lastPairedHeartRate?.name

        iredDeviceData.thermometerData.data.macAddress = lastPairedThermometer?.macAddress
        iredDeviceData.thermometerData.data.peripheralName = lastPairedThermometer?.name

        iredDeviceData.oximeterData.data.macAddress = lastPairedOximeter?.macAddress
        iredDeviceData.oximeterData.data.peripheralName = lastPairedOximeter?.name

        iredDeviceData.sphygmometerData.data.macAddress = lastPairedSphygmometer?.macAddress
        iredDeviceData.sphygmometerData.data.peripheralName = lastPairedSphygmometer?.name

        iredDeviceData.scaleData.data.macAddress = lastPairedScale?.macAddress
        iredDeviceData.scaleData.data.peripheralName = lastPairedScale?.name
    }
    private func loadDevice(_ key: StorageKeys) -> PairedDeviceModel? {
        return PairedDeviceModel.decodeFromUserDefault(forKey: key.rawValue)
    }
    // MARK: - Update Methods
    private func updateThermometer(_ device: PairedDeviceModel?) {
        lastPairedThermometer = device
    }
    
    private func updateOximeter(_ device: PairedDeviceModel?) {
        lastPairedOximeter = device
    }
    
    private func updateSphygmometer(_ device: PairedDeviceModel?) {
        lastPairedSphygmometer = device
    }
    
    private func updateJumpRope(_ device: PairedDeviceModel?) {
        lastPairedJumpRope = device
    }
    
    private func updateHeartRate(_ device: PairedDeviceModel?) {
        lastPairedHeartRate = device
    }
    
    private func updateScale(_ device: PairedDeviceModel?) {
        lastPairedScale = device
    }
    
    // MARK: - Save Method
    private func saveDevice(_ device: PairedDeviceModel?, forKey key: StorageKeys) {
        let encoder = JSONEncoder()
        if let device = device, let encoded = try? encoder.encode(device) {
            UserDefaults.standard.set(encoded, forKey: key.rawValue)
        } else {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: CBCentralManagerDelegate
extension iREdBluetooth: @preconcurrency CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            bleDelegate?.bluetoothStateDidChange(state: .unknown)
        case .resetting:
            bleDelegate?.bluetoothStateDidChange(state: .resetting)
        case .unsupported:
            bleDelegate?.bluetoothStateDidChange(state: .unsupported)
        case .unauthorized:
            bleDelegate?.bluetoothStateDidChange(state: .unauthorized)
        case .poweredOff:
            bleDelegate?.bluetoothStateDidChange(state: .poweredOff)
        case .poweredOn:
            bleDelegate?.bluetoothStateDidChange(state: .poweredOn)
        @unknown default:
            bleDelegate?.bluetoothStateDidChange(state: .unknown)
        }
    }
    
    private func addDevice(_ device: iRedDevice) {
        debugPrint("添加设备", device.name)
        devices.appendUnique(device)
    }
}

// MARK: CBPeripheralDelegate
extension iREdBluetooth: @preconcurrency CBPeripheralDelegate {
    // MARK: Discover devices
    @MainActor public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return } // The name is required for the ired Bluetooth device
        let deviceType: iREdBluetoothDeviceType = deviceTypeByPeripheralName(name)
        if currentDeviceType != deviceType && currentDeviceType != .all_ired_devices { return } // Pair only the current device type to avoid filtering all devices
        let uuid = peripheral.identifier.uuidString
        
        let device = iRedDevice(deviceType: deviceType, name: peripheral.name ?? "Unknown equipment", peripheral: peripheral, rssi: RSSI, isConnected: false, macAddress: nil)
        
        if devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).count == 0 {
            addDevice(device)
        }
        
        if let currentUUIDString, uuid == currentUUIDString {
            debugPrint("连接持久化存储的设备: ", uuid, "peripheral name: ", peripheral.name ?? "NO Name")
            // peripheral.delegate = self // ✅ 确保 delegate 设置
            currentPeripheral = peripheral
            guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
            centralManager.connect(per, options: nil)
            self.currentUUIDString = nil
            if deviceType == .scale && lastPairedScale != nil {
                iredDeviceData.oximeterData.state.isConnected = true
                connectingLoadingAlert?.dismiss(animated: true, completion: {
                    self.connectingLoadingAlert = nil
                })
                scaleService.parseWeightData(peripheral: peripheral, advertisementData: advertisementData)
            } else {
                stopPairing()
            }
            // addDevice(iRedDevice(deviceType: deviceType, name: name, peripheral: peripheral, rssi: RSSI, isConnected: true))
            return
        }
        
        if RSSI.intValue < setRSSI { return } // Filter devices that are far away
        
        // In order to adapt the jump rope device to obtain the mac address, process the delegate callback separately
        /*
         if deviceType != .jumpRope {
             bleDelegate?.bleDeviceCallback(callback: .discovered(deviceType: deviceType, device: device))
         }
         */
        
        switch deviceType {
            // HealthKit
        case .thermometer:
            let (uuidString, deviceName, macAddress) = thermometerService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.thermometerData.state.isPairing = false
            iredDeviceData.thermometerData.state.isPaired = true
            lastPairedThermometer = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            stopPairing()
        case .oximeter:
            let (uuidString, deviceName, macAddress) = oximeterService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.oximeterData.state.isPairing = false
            iredDeviceData.oximeterData.state.isPaired = true
            lastPairedOximeter = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            stopPairing()
        case .sphygmometer:
            let (uuidString, deviceName, macAddress) = sphygmometerService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.sphygmometerData.state.isPairing = false
            iredDeviceData.sphygmometerData.state.isPaired = true
            lastPairedSphygmometer = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            stopPairing()
        case .scale:
            let (uuidString, deviceName, macAddress) = scaleService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.scaleData.state.isPairing = false
            iredDeviceData.scaleData.state.isPaired = true
            iredDeviceData.scaleData.data.peripheralName = name
            lastPairedScale = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            // SportKit
        case .jumpRope:
            let (uuidString, deviceName, macAddress) = jumpRopeService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            debugPrint("跳绳-", "配对的UUID: ", uuid, "iREdFramework返回的uuid: ", uuidString)
            iredDeviceData.jumpRopeData.state.isPairing = false
            iredDeviceData.jumpRopeData.state.isPaired = true
            let dev = iRedDevice(deviceType: deviceType, name: deviceName, peripheral: peripheral, rssi: RSSI, isConnected: false, macAddress: macAddress)
            var jumpRopeData = self.iredDeviceData.jumpRopeData.data
            jumpRopeData.peripheralName = name
            jumpRopeData.macAddress = macAddress
            self.iredDeviceData.jumpRopeData.data = jumpRopeData
            self.lastPairedJumpRope = PairedDeviceModel(uuidString: uuid, name: peripheral.name, macAddress: macAddress)
            self.bleDelegate?.bleDeviceCallback(callback: .discovered(deviceType: deviceType, device: dev))
            self.stopPairing()
        case .heartRateBelt:
            let (uuidString, deviceName, macAddress) = heartrateProfile.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.heartRateData.state.isPairing = false
            iredDeviceData.heartRateData.state.isPaired = true
            iredDeviceData.heartRateData.data.peripheralName = name
            lastPairedHeartRate = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            stopPairing()
        default:
            /// print("others")
            break
        }
        startPairingningAlert?.dismiss(animated: true, completion: nil)
        
    }
    
    // MARK: Connect devices
    @MainActor public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugPrint("连接成功", peripheral.name)
        connectingLoadingAlert?.dismiss(animated: true, completion: {
            self.connectingLoadingAlert = nil
        })
        guard let name = peripheral.name else { return }
        currentUUIDString = nil
        // currentPeripheral = nil
        /// print("Connection successful: \(name)")
        let deviceType: iREdBluetoothDeviceType = deviceTypeByPeripheralName(name)
        guard let device = devices.filter({ $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }).first else { return }
        peripheral.delegate = self
        switch deviceType {
        case .thermometer:
            peripheral.discoverServices(nil)
            iredDeviceData.thermometerData.data = .empty
            iredDeviceData.thermometerData.state.isPaired = true
            iredDeviceData.thermometerData.state.isConnected = true
            iredDeviceData.thermometerData.state.isConnecting = false
        case .oximeter:
            peripheral.discoverServices(nil)
            iredDeviceData.oximeterData.data = .empty
            iredDeviceData.oximeterData.state.isConnected = true
            iredDeviceData.oximeterData.state.isConnecting = false
        case .sphygmometer:
            peripheral.discoverServices(nil)
            iredDeviceData.sphygmometerData.data = .empty
            iredDeviceData.sphygmometerData.state.isConnected = true
            iredDeviceData.sphygmometerData.state.isConnecting = false
        case .scale:
            peripheral.discoverServices(nil)
            iredDeviceData.scaleData.data = .empty
            iredDeviceData.scaleData.state.isConnected = true
            iredDeviceData.scaleData.state.isConnecting = false
        case .jumpRope:
            peripheral.discoverServices([JumpRopeService.JumpRopeServiceUUID])
            iredDeviceData.jumpRopeData.data = .empty
            iredDeviceData.jumpRopeData.state.isConnected = true
            iredDeviceData.jumpRopeData.state.isConnecting = false
            /// print("jump rope connected...")
        case .heartRateBelt:
            peripheral.discoverServices([
                HeartrateProfile.HeartrateServiceUUID,
                HeartrateProfile.BatteryServiceUUID,
            ])
            iredDeviceData.heartRateData.data = .empty
            iredDeviceData.heartRateData.state.isConnected = true
            iredDeviceData.heartRateData.state.isConnecting = false
        default:
            /// print("other")
            break
        }
        devices.updateDevice(with: peripheral.identifier.uuidString) { device in
            device.isConnected = true
        }
        bleDelegate?.bleDeviceCallback(callback: .connected(deviceType: deviceTypeByPeripheralName(name), device: device))
    }
    
    // connection failed
    @MainActor public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        debugPrint("连接失败", peripheral.name)
        connectingLoadingAlert?.dismiss(animated: true, completion: {
            self.connectingLoadingAlert = nil
        })
        /// print("Connection failure: \(error?.localizedDescription ?? "Unknown error")")
        // iREdAlert.shared.showAlert(title: "Connection failure", message: error?.localizedDescription ?? "Unknown error")
        guard let name = peripheral.name else { return }
        let deviceType: iREdBluetoothDeviceType = deviceTypeByPeripheralName(name)
        switch deviceType {
        case .thermometer:
            iredDeviceData.thermometerData.state.isConnectionFailure = true
        case .oximeter:
            iredDeviceData.oximeterData.state.isConnectionFailure = true
        case .sphygmometer:
            iredDeviceData.sphygmometerData.state.isConnectionFailure = true
        case .scale:
            iredDeviceData.scaleData.state.isConnectionFailure = true
        case .jumpRope:
            iredDeviceData.jumpRopeData.state.isConnectionFailure = true
        case .heartRateBelt:
            iredDeviceData.heartRateData.state.isConnectionFailure = true
        default:
            /// print("Other")
            break
        }
    }
    
    // MARK: Disconnect devices
    @MainActor public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugPrint("断开连接成功", peripheral.name)
        guard let name = peripheral.name else { return }
        guard let device = devices.filter({ $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }).first else { return }
        /// print("disconnect: \(name)")
        switch device.deviceType {
        case .thermometer:
            // iredDeviceData.thermometerData.data = .empty
            iredDeviceData.thermometerData.state.isPaired = false
            iredDeviceData.thermometerData.state.isConnected = false
            iredDeviceData.thermometerData.state.isDisconnected = true
        case .oximeter:
            // iredDeviceData.oximeterData.data = .empty
            iredDeviceData.oximeterData.state.isConnected = false
            iredDeviceData.oximeterData.state.isDisconnected = true
        case .sphygmometer:
            // iredDeviceData.sphygmometerData.data = .empty
            iredDeviceData.sphygmometerData.state.isConnected = false
            iredDeviceData.sphygmometerData.state.isDisconnected = true
        case .scale:
            // iredDeviceData.scaleData.data = .empty
            iredDeviceData.scaleData.state.isConnected = false
            iredDeviceData.scaleData.state.isDisconnected = true
        case .jumpRope:
            // iredDeviceData.jumpRopeData.data = .empty
            iredDeviceData.jumpRopeData.state.isConnected = false
            iredDeviceData.jumpRopeData.state.isDisconnected = true
            stopJumpRopeRecording()
        case .heartRateBelt:
            // iredDeviceData.heartRateData.data = .empty
            iredDeviceData.heartRateData.state.isConnected = false
            iredDeviceData.heartRateData.state.isDisconnected = true
            stopHeartRateRecording()
        default:
            /// print("Other")
            break
        }
        devices.updateDevice(with: peripheral.identifier.uuidString) { device in
            device.isConnected = false
        }
        bleDelegate?.bleDeviceCallback(callback: .disconnected(deviceType: deviceTypeByPeripheralName(name), device: device))
    }
    
    // MARK: Discover services
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            return
        }
        
        guard let services = peripheral.services else {
            /// print("Service not found")
            return
        }
        
        for service in services {
            switch deviceTypeByPeripheralName(peripheral.name!) {
            case .thermometer:
                peripheral.discoverCharacteristics([ThermometerService.ThermometerNotifyCharacteristicUUID, ThermometerService.ThermometerWriteCharacteristicUUID], for: service)
            case .oximeter:
                peripheral.discoverCharacteristics([OximeterService.OximeterNotifyCharacteristicUUID], for: service)
            case .sphygmometer:
                peripheral.discoverCharacteristics([BloodPressureMonitorService.BloodPressureMonitorNotifyCharacteristicUUID], for: service)
            case .scale:
                peripheral.discoverCharacteristics(nil, for: service)
            case .jumpRope:
                peripheral.discoverCharacteristics([JumpRopeService.JumpRopeWriteCharacteristicUUID, JumpRopeService.JumpRopeNotifyCharacteristicUUID], for: service)
            case .heartRateBelt:
                peripheral.discoverCharacteristics([HeartrateProfile.BatteryServiceCharacteristicUUID, HeartrateProfile.HeartrateServiceNotifyCharacteristicUUID], for: service)
            default:
                /// print("Unknown device")
                break
            }
        }
    }
    
    // MARK: Discover characteristics
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            switch characteristic.uuid {
                
            case ThermometerService.ThermometerNotifyCharacteristicUUID:
                /// print("Discovery feature: \(characteristic.uuid)")
                peripheral.setNotifyValue(true, for: characteristic)
                
            case BloodPressureMonitorService.BloodPressureMonitorNotifyCharacteristicUUID:
                peripheral.setNotifyValue(true, for: characteristic)
                
            case OximeterService.OximeterNotifyCharacteristicUUID:
                peripheral.setNotifyValue(true, for: characteristic)
                
            case ThermometerService.ThermometerWriteCharacteristicUUID:
                /// print("Discovery feature: \(characteristic.uuid)")
                let queryCommand: [UInt8] = [0xAA, 0x01, 0xD5, 0x00, 0xd4]
                let data = Data(queryCommand)
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            case
                // JumpRope
                JumpRopeService.JumpRopeNotifyCharacteristicUUID,
                JumpRopeService.JumpRopeServiceUUID,
                // HeartRate
                HeartrateProfile.HeartrateServiceNotifyCharacteristicUUID,
                HeartrateProfile.BatteryServiceCharacteristicUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case JumpRopeService.JumpRopeWriteCharacteristicUUID:
                peripheral.writeValue(JumpRopeService.queryBatteryLevelCommand, for: characteristic, type: .withoutResponse)
                guard let jumpRopeDevice = devices.filter({ $0.deviceType == .jumpRope }).first?.peripheral else { return }
                jumpRopeService.setMode(peripheral: jumpRopeDevice, mode: 0, setting: 0)
            default:
                /// print("Unknown features discovered: \(characteristic.uuid)")
                break
            }
            peripheral.readValue(for: characteristic)
            
        }
        
        
        
        
        
        
    }
    
    // MARK: Update value for characteristics
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            /// print("Failed to update the feature value: \(error.localizedDescription)")
            return
        }
        
        guard characteristic.value != nil else {
            /// print("No eigenvalues were found")
            return
        }
        
        switch characteristic.uuid {
            
        case ThermometerService.ThermometerNotifyCharacteristicUUID where thermometerService.isThermometer(peripheral: peripheral):
            thermometerService.parseThermometerData(peripheral: peripheral, characteristic: characteristic)
            
        case BloodPressureMonitorService.BloodPressureMonitorNotifyCharacteristicUUID where sphygmometerService.isBloodPressureMonitor(peripheral: peripheral):
            sphygmometerService.parseBloodPressureMonitorData(peripheral: peripheral, characteristic: characteristic)
            
        case OximeterService.OximeterNotifyCharacteristicUUID where oximeterService.isOximeter(peripheral: peripheral):
            oximeterService.parseOximeterData(peripheral: peripheral, characteristic: characteristic)
            
        case JumpRopeService.JumpRopeNotifyCharacteristicUUID where jumpRopeService.isJumpRope(peripheral: peripheral):
            jumpRopeService.parseJumpRopeData(peripheral: peripheral, characteristic: characteristic)
            
        case HeartrateProfile.HeartrateServiceNotifyCharacteristicUUID where heartrateProfile.isHeartRateProfile(peripheral: peripheral):
            heartrateProfile.parseHeartRateProfileData(peripheral: peripheral, characteristic: characteristic)
            
        case HeartrateProfile.BatteryServiceCharacteristicUUID where heartrateProfile.isHeartRateProfile(peripheral: peripheral):
            heartrateProfile.parseHeartRateProfileData(peripheral: peripheral, characteristic: characteristic)
            
        default:
            /// print("Received data with unknown characteristics: \(characteristic.uuid)")
            break
        }
        
    }
}

// Callbacks
// MARK: Scale
extension iREdBluetooth: @preconcurrency SportKitFramework.ScaleServiceDelegate {
    public func scaleWeightCallback(weight: Double, isFinalResult: Bool) {
        hkDelegate?.scaleCallback(callback: .weight(weight: weight, isFinalResult: isFinalResult))
        skDelegate?.scaleCallback(callback: .weight(weight: weight, isFinalResult: isFinalResult))
        iredDeviceData.scaleData.data.weight = weight
        if isFinalResult {
            iredDeviceData.scaleData.state.isMeasurementCompleted = true
            iredDeviceData.scaleData.state.isMeasuring = false
        } else {
            iredDeviceData.scaleData.state.isMeasuring = true
            iredDeviceData.scaleData.state.isMeasurementCompleted = false
        }
    }
}

// MARK: Thermometer
extension iREdBluetooth: @preconcurrency ThermometerServiceDelegate {
    public func thermometerTemperatureCallback(temperature: Double, mode: Int, modeString: String) {
        hkDelegate?.thermometerCallback(callback: .temperature(temperature: temperature, mode: mode, modeString: modeString))
        var thermometerData = iredDeviceData.thermometerData
        thermometerData.state.isConnected = true
        thermometerData.state.isMeasurementCompleted = true
        let data = HealthKitThermometerModel(battery: iredDeviceData.thermometerData.data.battery, temperature: temperature, modeCode: mode, modeDescription: modeString)
        thermometerData.data = data
        Task {
            await MainActor.run {
                self.iredDeviceData.thermometerData = thermometerData
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.iredDeviceData.thermometerData.state.isMeasurementCompleted = false
        }
    }
    
    public func thermometerErrorCallback(error: Int, description: String) {
        hkDelegate?.thermometerCallback(callback: .error(error: error, description: description))
        iredDeviceData.thermometerData.state.isMeasurementError = MeasurementError(errorCode: error, errorDescription: description)
    }
    
    @MainActor public func thermometerBatteryLevelCallback(type: Int, description: String) {
        hkDelegate?.thermometerCallback(callback: .battery(type: type, description: description))
        iredDeviceData.thermometerData.data = .empty
        iredDeviceData.thermometerData.state.isConnected = true
        iredDeviceData.thermometerData.data.battery = description
    }
}

// MARK: Oximeter
extension iREdBluetooth: @preconcurrency OximeterServiceDelegate {
    public func oximeterBatteryCallback(batteryPercentage: Int, pulseData: Data) {
        hkDelegate?.oximeterCallback(callback: .battery(batteryPercentage: batteryPercentage, pulseData: pulseData))
        iredDeviceData.oximeterData.data.battery = batteryPercentage
        iredDeviceData.oximeterData.data.pulsData = pulseData
        iredDeviceData.oximeterData.data.PlethysmographyArray += pulseData.map(Int.init)
    }
    
    public func oximeterMeasurementCallback(pulse: Int, spo2: Int, pi: Double) {
        hkDelegate?.oximeterCallback(callback: .measurement(pulse: pulse, spo2: spo2, pi: pi))
        iredDeviceData.oximeterData.data.pulse = pulse == 255 ? 0 : pulse
        iredDeviceData.oximeterData.data.spo2 = spo2 == 127 ? 0 : spo2
        iredDeviceData.oximeterData.data.pi = pi
        iredDeviceData.oximeterData.data.SpO2Array.append(spo2)
        iredDeviceData.oximeterData.data.BPMArray.append(pulse)
        iredDeviceData.oximeterData.data.PIArray.append(pi)
    }
}
extension iREdBluetooth {
    private func prepareOximeterReportAlert(
        avgSpO2: Int,
        avgBPM: Int,
        avgPi: Double,
        spo2LowerBound: Int = 95,
        spo2UpperBound: Int = 100,
        bpmLowerBound: Int = 60,
        bpmUpperBound: Int = 100,
        piLowerBound: Double = 0.2,
        piUpperBound: Double = 20.0
    ) -> String {
        
        var reportMessage = ""
        
        if (spo2LowerBound...spo2UpperBound).contains(avgSpO2) &&
            (bpmLowerBound...bpmUpperBound).contains(avgBPM) &&
            (piLowerBound...piUpperBound).contains(avgPi) {
            reportMessage = "Your Body is healthy"
        } else if avgSpO2 < spo2LowerBound {
            reportMessage = "Your SpO2 is lower than normal. You have to seek medical attention as soon as possible."
        } else if avgBPM < bpmLowerBound {
            reportMessage = "Your resting heart rate is lower than normal range. You have to seek medical attention as soon as possible."
        } else if avgPi < piLowerBound {
            reportMessage = "Your resting Pi is lower than normal range. You have to seek medical attention as soon as possible."
        } else if avgSpO2 > spo2UpperBound {
            reportMessage = "Your SpO2 is higher than normal. You have to seek medical attention as soon as possible."
        } else if avgBPM > bpmUpperBound {
            reportMessage = "Your resting heart rate is higher than normal range. You have to seek medical attention as soon as possible."
        } else if avgPi > piUpperBound {
            reportMessage = "Your resting Pi is higher than normal range. You have to seek medical attention as soon as possible."
        }
        
        return reportMessage
    }
    public func oximeterMeasurementResultsDetails(data: HealthKitOximeterModel) -> String {
        // Extract the constant for invocation
        let bpmArray = data.BPMArray
        let piArray = data.PIArray
        let spO2Array = data.SpO2Array
        
        let bpmCount = bpmArray.count
        let piCount = Double(piArray.count)
        let spO2Count = spO2Array.count
        
        // Calculate the pi result
        let piValue: Double = piArray.reduce(0, +) / (piCount > 0 ? piCount : 1)
        let resultPI = String(format: "%.1f", piValue)
        
        // Calculate the spo2 result
        let resultSpO2: Int
        if spO2Count > 0 {
            resultSpO2 = spO2Array.reduce(0, +) / spO2Count
        } else {
            resultSpO2 = 999
        }
        
        // Calculate the BPS and m results
        let resultBPM: Int
        if bpmCount > 0 {
            resultBPM = bpmArray.reduce(0, +) / bpmCount
        } else {
            resultBPM = 999
        }
        
        // Examine the data and generate a report message
        var reportMessage = ""
        if bpmCount > 0 && piCount > 0 && spO2Count > 0 {
            reportMessage = """
            SpO2: \(resultSpO2)% (95-100%)
            Heart Rate: \(resultBPM)bpm (60-100bpm)
            PI: \(resultPI)% (0.2-20%)
            """
            let alertMessage = prepareOximeterReportAlert(
                avgSpO2: resultSpO2,
                avgBPM: resultBPM,
                avgPi: piValue
            )
            reportMessage += "\n\(alertMessage)"
        } else {
            reportMessage = "Make sure the array is not empty and the count is greater than 0"
        }
        
        return reportMessage
    }
}

// MARK: Sphygmometer
extension iREdBluetooth: @preconcurrency BloodPressureMonitorServiceDelegate {
    public func bloodPressureMonitorInstantDataCallback(pressure: Int, pulseStatus: Int) {
        hkDelegate?.sphygmometerCallback(callback: .instantData(pressure: pressure, pulseStatus: pulseStatus))
        iredDeviceData.sphygmometerData.data.pressure = pressure
        iredDeviceData.sphygmometerData.data.pulseStatus = pulseStatus
        iredDeviceData.sphygmometerData.state.isMeasurementCompleted = false
        iredDeviceData.sphygmometerData.state.isMeasuring = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.iredDeviceData.sphygmometerData.state.isMeasurementCompleted = false
        }
    }
    
    public func bloodPressureMonitorFinalDataCallback(systolic: Int, diastolic: Int, pulse: Int, irregularPulse: Int) {
        hkDelegate?.sphygmometerCallback(callback: .finalData(systolic: systolic, diastolic: diastolic, pulse: pulse, irregularPulse: irregularPulse))
        iredDeviceData.sphygmometerData.data.systolic = systolic
        iredDeviceData.sphygmometerData.data.diastolic = diastolic
        iredDeviceData.sphygmometerData.data.pulse = pulse
        iredDeviceData.sphygmometerData.data.irregularPulse = irregularPulse
        iredDeviceData.sphygmometerData.state.isMeasurementCompleted = true
    }
}

// MARK: JumpRope
extension iREdBluetooth: @preconcurrency JumpRopeServiceDelegate {
    @MainActor public func jumpRopeStatusCallback(mode: Int, status: Int, setting: Int, count: Int, time: Int, screen: Int, battery: Int) {
        iredDeviceData.jumpRopeData.data.count = count
        iredDeviceData.jumpRopeData.data.time = time
        iredDeviceData.jumpRopeData.data.mode = mode
        iredDeviceData.jumpRopeData.data.status = status
        iredDeviceData.jumpRopeData.data.setting = setting
        iredDeviceData.jumpRopeData.data.screen = screen
        iredDeviceData.jumpRopeData.data.batteryLevel = battery
        var resultMode: JumpRopeMode = .free
        var resultStatus: JumpRopeState = .notJumpingRope
        switch mode {
        case 1:
            resultMode = .free
        case 2:
            resultMode = .time
        case 3:
            resultMode = .count
        default:
            resultMode = .free
        }
        switch status {
        case 0:
            resultStatus = .notJumpingRope
        case 1:
            resultStatus = .jumpingRope
        case 2:
            resultStatus = .pauseRope
        case 3:
            resultStatus = .endOfJumpRope
            if iredDeviceData.jumpRopeData.state.isMeasuring {
                stopJumpRopeRecording()
            }
        default:
            resultStatus = .notJumpingRope
        }
        // print("跳绳状态：", resultStatus)
        skDelegate?.jumpRopeCallback(callback: .result(mode: resultMode, status: resultStatus, setting: setting, count: count, time: time, screen: screen, battery: battery))
    }
}
extension iREdBluetooth {
    public enum SetJumpRopeMode {
        case free
        case time(second: Int)
        case count(count: Int)
    }
}
extension iREdBluetooth {
    @MainActor private static var jumpRopeTimer: Timer?
    
    enum JumpRopeError: LocalizedError {
        case invalidTime
        case invalidCount
        case deviceNotFound
        
        var errorDescription: String? {
            switch self {
            case .invalidTime:
                return "In time mode, time cannot be empty or negative."
            case .invalidCount:
                return "In count mode, the quantity cannot be empty or negative."
            case .deviceNotFound:
                return "No jump rope device found."
            }
        }
    }
    /// 开始跳绳记录，每秒采样一次跳绳数量变化
    public func startJumpRopeRecording(_ mode: SetJumpRopeMode, completion: @escaping (Result<Void, Error>) -> Void) {
        iredDeviceData.jumpRopeData.data.countArray = []
        iredDeviceData.jumpRopeData.data.count = 0
        iredDeviceData.jumpRopeData.state.isMeasurementCompleted = false
        guard let jumpRopeDevice = devices.filter({ $0.deviceType == .jumpRope }).first?.peripheral else { return }
        switch mode {
        case .free:
            jumpRopeService.setMode(peripheral: jumpRopeDevice, mode: 0, setting: 0)
        case .time(let seconds):
            if seconds < 0 {
                completion(.failure(JumpRopeError.invalidTime))
                return
            }
            jumpRopeService.setMode(peripheral: jumpRopeDevice, mode: 1, setting: seconds)
        case .count(let count):
            if count < 0 {
                completion(.failure(JumpRopeError.invalidCount))
                return
            }
            jumpRopeService.setMode(peripheral: jumpRopeDevice, mode: 2, setting: count)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            switch mode {
            case .free:
                self.jumpRopeService.setMode(peripheral: jumpRopeDevice, mode: 0, setting: 0)
            case .time(let seconds):
                if seconds < 0 {
                    completion(.failure(JumpRopeError.invalidTime))
                    return
                }
                self.jumpRopeService.setMode(peripheral: jumpRopeDevice, mode: 1, setting: seconds)
            case .count(let count):
                if count < 0 {
                    completion(.failure(JumpRopeError.invalidCount))
                    return
                }
                self.jumpRopeService.setMode(peripheral: jumpRopeDevice, mode: 2, setting: count)
            }
            
            self.iredDeviceData.jumpRopeData.state.isMeasuring = true
            Self.jumpRopeTimer?.invalidate()
            Self.jumpRopeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    guard self.iredDeviceData.jumpRopeData.state.isMeasuring,
                          let currentCount = self.iredDeviceData.jumpRopeData.data.count else { return }
                    
                    let item = JumpRopeArrayModel(date: Date(), count: currentCount)
                    self.iredDeviceData.jumpRopeData.data.countArray.append(item)
                }
            }
            
            // 成功后返回 success
            completion(.success(()))
        }
    }
    /// 停止跳绳记录
    @MainActor public func stopJumpRopeRecording() {
        print(#function, "停止跳绳记录")
        Self.jumpRopeTimer?.invalidate()
        Self.jumpRopeTimer = nil
        guard let jumpRopeDevice = devices.filter({ $0.deviceType == .jumpRope }).first?.peripheral else { return }
        jumpRopeService.stopCurrentMode(peripheral: jumpRopeDevice)
        iredDeviceData.jumpRopeData.state.isMeasuring = false
        iredDeviceData.jumpRopeData.state.isMeasurementCompleted = true
        // 如果心跳带也正在测量，则自动停止心跳带的记录
        if iredDeviceData.heartRateData.state.isMeasuring {
            stopHeartRateRecording()
        }
        // print("停止时间是否成功", Self.jumpRopeTimer?.isValid)
    }
}

// MARK: Heart Rate Belt
extension iREdBluetooth: @preconcurrency HeartrateProfileDelegate {
    public func HeartRateCallback(heartrate: Int) {
        iredDeviceData.heartRateData.data.heartrate = heartrate
        skDelegate?.heartRateCallback(callback: .heartrate(heartrate: heartrate))
    }
    
    public func HeartRateProfileBatteryLevelCallback(batteryLevel: Int) {
        iredDeviceData.heartRateData.data = HeartRateBeltModel(batteryPercentage: batteryLevel)
        skDelegate?.heartRateCallback(callback: .battery(batteryLevel: batteryLevel))
    }
}
extension iREdBluetooth {
    @MainActor private static var heartRateTimer: Timer?
    
    /// 开始心率记录
    ///
    /// 此函数会设置 `isMeasuring = true`，并启动一个每秒触发的 `Timer`，
    /// 从当前 `HeartRateBeltModel` 中获取最新心率值并追加进 `heartrateArray`，
    /// 每条数据包含心率值和记录时间。
    ///
    /// 使用前应确保已有有效的心率值（`heartrate`）。
    @MainActor public func startHeartRateRecording() {
        self.iredDeviceData.heartRateData.data.heartrateArray = [] // 清空历史数据
        // 标记正在测量
        iredDeviceData.heartRateData.state.isMeasuring = true
        // 清除之前的定时器（如有）
        Self.heartRateTimer?.invalidate()
        
        // 每秒记录一次心率
        Self.heartRateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard self.iredDeviceData.heartRateData.state.isMeasuring,
                      let currentHR = self.iredDeviceData.heartRateData.data.heartrate else { return }
                
                let item = HeartRateBeltArrayModel(date: Date(), heartrate: currentHR)
                self.iredDeviceData.heartRateData.data.heartrateArray.append(item)
            }
        }
        
    }
    
    /// 停止心率记录
    ///
    /// 此函数会停止并释放定时器，
    /// 并设置状态标记 `isMeasuring = false`，`isMeasurementCompleted = true`。
    @MainActor public func stopHeartRateRecording() {
        // print(#function, "停止心跳记录")
        // 停止定时器
        Self.heartRateTimer?.invalidate()
        Self.heartRateTimer = nil
        // 设置状态为测量结束
        iredDeviceData.heartRateData.state.isMeasuring = false
        iredDeviceData.heartRateData.state.isMeasurementCompleted = true
    }
}


extension iREdBluetooth {
    /// Sets the RSSI (Received Signal Strength Indicator) limit for Bluetooth device scanning or filtering.
    ///
    /// - Parameter limit: An integer value representing the minimum acceptable RSSI value. Devices with a weaker signal will be ignored.
    public func setRSSI(limit: Int) {
        setRSSI = limit
    }
}


// MARK: BlueTooth Delegate
public protocol BlueToothDelegate: AnyObject {
    func bluetoothStateDidChange(state: BlueToothState)
    func bleDeviceCallback(callback: BLEDeviceCallback)
}
public extension BlueToothDelegate {
    func bluetoothStateDidChange(state: BlueToothState) {}
}

// MARK: HealthKit Delegate
public protocol HealthKitDelegate: AnyObject {
    func thermometerCallback(callback: ThermometerCallback)
    func oximeterCallback(callback: OximeterCallback)
    func sphygmometerCallback(callback: SphygmometerCallback)
    func scaleCallback(callback: ScaleCallback)
}
public extension HealthKitDelegate {
    func thermometerCallback(callback: ThermometerCallback) {}
    func oximeterCallback(callback: OximeterCallback) {}
    func sphygmometerCallback(callback: SphygmometerCallback) {}
    func scaleCallback(callback: ScaleCallback) {}
}

// MARK: SportKit Delegate
public protocol SportKitDelegate: AnyObject {
    func jumpRopeCallback(callback: JumpRopeCallback)
    func heartRateCallback(callback: HeartRateCallback)
    func scaleCallback(callback: ScaleCallback)
}
public extension SportKitDelegate {
    func jumpRopeCallback(callback: JumpRopeCallback) {}
    func heartRateCallback(callback: HeartRateCallback) {}
    func scaleCallback(callback: ScaleCallback) {}
}


public struct PairedDeviceModel: Codable {
    public var uuidString: String
    public var name: String?
    public var macAddress: String?
    
    public init(uuidString: String, name: String?, macAddress: String?) {
        self.uuidString = uuidString
        self.name = name
        self.macAddress = macAddress
    }
    
    public static func decodeFromUserDefault(forKey key: String) -> PairedDeviceModel? {
        if let data = UserDefaults.standard.data(forKey: key) {
            let decoder = JSONDecoder()
            if let model = try? decoder.decode(PairedDeviceModel.self, from: data) {
                return model
            }
        }
        return nil
    }
}
