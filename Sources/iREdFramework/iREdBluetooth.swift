import Foundation
import CoreBluetooth
import HealthKitFramework
import SportKitFramework
import UIKit
import SwiftUI


// MARK: MAIN Method
@MainActor
public final class iREdBluetooth: NSObject, ObservableObject, Sendable {
    /// iREdBluetooth 蓝牙管理器单例实例，负责统一处理所有 iRED 系列设备的配对、连接、数据接收等操作。
    @MainActor public static let shared = iREdBluetooth()
    
    /// 表示各类型设备在 UserDefaults 中的配对信息存储键。
    ///
    /// 用于持久化保存已配对设备的 UUID 和 MAC 地址信息，
    /// 以便下次启动应用时自动恢复连接。
    private enum StorageKeys: String {
        case thermometer = "lastPairedThermometer"
        case oximeter = "lastPairedOximeter"
        case sphygmometer = "lastPairedSphygmometer"
        case jumpRope = "lastPairedJumpRope"
        case heartRate = "lastPairedHeartRate"
        case scale = "lastPairedScale"
    }
    
    // MARK: - 委托代理
    
    /// 接收来自 HealthKit 设备（体温计、血氧仪、血压计、体重秤）的测量数据回调。
    private weak var hkDelegate: HealthKitDelegate?
    
    /// 接收来自 SportKit 设备（跳绳、心率带）的数据回调。
    private weak var skDelegate: SportKitDelegate?
    
    /// 接收通用蓝牙状态变更与设备连接回调。
    private weak var bleDelegate: BlueToothDelegate?
    
    /// CoreBluetooth 中心管理器，用于扫描、连接和管理 BLE 外设。
    private var centralManager: CBCentralManager!
    
    /// 当前已发现的蓝牙设备列表。
    private var devices: [iRedDevice] = []
    
    /// 当前操作的目标设备类型，用于配对或连接时标记上下文。
    private var currentDeviceType: iREdBluetoothDeviceType = .none
    
    // MARK: - 各设备服务实例（对应 BLE 通信协议）
    
    /// 体温计服务，处理其 BLE 通信与数据解析。
    private var thermometerService: ThermometerService!
    
    /// 血氧仪服务。
    private var oximeterService: OximeterService!
    
    /// 血压计服务。
    private var sphygmometerService: BloodPressureMonitorService!
    
    /// 体重秤服务（SportKit 提供）。
    private var scaleService: SportKitFramework.ScaleService!
    
    /// 跳绳设备服务。
    private var jumpRopeService: JumpRopeService!
    
    /// 心率带服务。
    private var heartrateProfile: HeartrateProfile!
    
    /// 所有已连接设备的数据汇总结构体，采用 `@Published` 实时更新。
    @Published private(set) public var iredDeviceData: iRedDeviceData = iRedDeviceData()
    
    // MARK: - 当前配对与连接流程的状态变量
    
    /// 当前配对时展示的提示弹窗（如“正在搜索设备...”）。
    private var startPairingningAlert: UIAlertController? = nil
    
    /// 当前连接中展示的加载弹窗（如“正在连接...”）。
    private var connectingLoadingAlert: UIAlertController? = nil
    
    /// 当前操作的目标设备 UUID（配对或连接时使用）。
    private var currentUUIDString: String? = nil
    
    /// 当前选中的 Peripheral 对象。
    private var currentPeripheral: CBPeripheral? = nil
    
    // MARK: - 已配对设备持久化信息
    
    /// 上次配对的体温计设备。
    private var lastPairedThermometer: PairedDeviceModel? {
        didSet { saveDevice(lastPairedThermometer, forKey: .thermometer) }
    }
    
    /// 上次配对的血氧仪设备。
    private var lastPairedOximeter: PairedDeviceModel? {
        didSet { saveDevice(lastPairedOximeter, forKey: .oximeter) }
    }
    
    /// 上次配对的血压计设备。
    private var lastPairedSphygmometer: PairedDeviceModel? {
        didSet { saveDevice(lastPairedSphygmometer, forKey: .sphygmometer) }
    }
    
    /// 上次配对的跳绳设备。
    private var lastPairedJumpRope: PairedDeviceModel? {
        didSet { saveDevice(lastPairedJumpRope, forKey: .jumpRope) }
    }
    
    /// 上次配对的心率带设备。
    private var lastPairedHeartRate: PairedDeviceModel? {
        didSet { saveDevice(lastPairedHeartRate, forKey: .heartRate) }
    }
    
    /// 上次配对的体重秤设备。
    private var lastPairedScale: PairedDeviceModel? {
        didSet { saveDevice(lastPairedScale, forKey: .scale) }
    }
    
    /// 当前扫描设备时的 RSSI 信号强度过滤阈值，默认 -60。
    ///
    /// 仅保留 RSSI 值大于该阈值的设备，用于避免连接信号较弱的设备。
    @Published private var setRSSI: Int = -60
    
    /// 默认初始化方法，构建 iREdBluetooth 蓝牙管理器实例。
    ///
    /// 此构造函数会完成以下初始化操作：
    ///
    /// 1. 从本地持久化数据中加载所有设备的配对记录；
    /// 2. 初始化 CoreBluetooth 中心管理器 `CBCentralManager`，设置代理为当前实例；
    /// 3. 初始化所有支持的蓝牙设备服务（体温计、血氧仪、血压计、体重秤、跳绳、心率带）；
    /// 4. 为每个服务设置代理为当前蓝牙管理器，以接收数据与事件回调。
    ///
    /// > ⚠️ 本构造器仅应通过 `iREdBluetooth.shared` 单例调用，避免重复初始化多个实例。
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
    
    /// 开始配对指定类型的 iRED 蓝牙设备（清空历史数据并开启扫描）
    ///
    /// - Parameter deviceType: 需要配对的蓝牙设备类型，例如 `.thermometer`, `.scale` 等。
    ///
    /// 此方法用于触发新设备的配对流程，主要操作包括：
    /// 1. 重置当前设备的数据为 `.empty`；
    /// 2. 设置对应设备的 `isPairing` 状态为 `true`；
    /// 3. 清除当前保存的已配对设备 UUID；
    /// 4. 启动扫描所有外围设备（允许重复结果）；
    /// 5. 设置 `currentDeviceType` 与 `currentUUIDString` 为当前配对目标。
    ///
    /// ⚠️ 注意事项：
    /// - 本方法需在主线程调用（已使用 `@MainActor` 注解）
    /// - 会影响之前的配对状态和连接状态，请确保用户意图明确再调用此方法
    /// - `didDiscoverPeripheral` 回调中需要根据设备类型和 `isPairing` 状态判断是否允许连接
    ///
    /// - Example:
    /// ```swift
    /// let bleManager = iREdBluetooth.shared
    /// await bleManager.startPairing(to: .oximeter)
    /// ```
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
    
    /// 停止所有 iRED 蓝牙设备的配对与连接流程
    ///
    /// 此方法会统一重置所有设备的状态标志，包括：
    /// - 停止配对状态 `isPairing`
    /// - 停止连接中状态 `isConnecting`
    /// - 停止体重秤的测量状态 `isMeasuring` 和 `isMeasurementCompleted`
    /// - 停止正在进行的蓝牙扫描
    ///
    /// 该方法适用于用户主动取消配对流程，或当需强制中止所有设备连接尝试时使用。
    ///
    /// - Example:
    /// ```swift
    /// let bleManager = iREdBluetooth.shared
    /// bleManager.stopPairing()
    /// ```
    public func stopPairing() {
        iredDeviceData.thermometerData.state.isPairing = false
        iredDeviceData.oximeterData.state.isPairing = false
        iredDeviceData.sphygmometerData.state.isPairing = false
        iredDeviceData.jumpRopeData.state.isPairing = false
        iredDeviceData.heartRateData.state.isPairing = false
        iredDeviceData.scaleData.state.isPairing = false
        
        iredDeviceData.thermometerData.state.isConnecting = false
        iredDeviceData.oximeterData.state.isConnecting = false
        iredDeviceData.sphygmometerData.state.isConnecting = false
        iredDeviceData.jumpRopeData.state.isConnecting = false
        iredDeviceData.heartRateData.state.isConnecting = false
        iredDeviceData.scaleData.state.isConnecting = false
        
        iredDeviceData.scaleData.state.isMeasuring = false
        iredDeviceData.scaleData.state.isMeasurementCompleted = false
        centralManager.stopScan()
        debugPrint("stop pairing")
    }
    
    /// 根据指定设备类型发起蓝牙连接请求（仅连接已配对设备）
    ///
    /// - Parameter deviceType: 要连接的 iRED 蓝牙设备类型（如 `.oximeter`, `.scale` 等）
    ///
    /// 此方法会：
    /// 1. 初始化已配对设备信息；
    /// 2. 设置当前操作的设备类型；
    /// 3. 根据设备类型判断对应设备是否已连接，若未连接则发起连接扫描。
    ///
    /// 发起连接的前提是设备已配对（已存储 UUID），
    /// 若存在配对记录且当前未连接状态，则会设置为连接中并启动扫描（允许重复扫描）。
    ///
    /// - 注意事项：
    ///   - 本方法在 `@MainActor` 上运行，需确保在主线程调用；
    ///   - 若对应设备数据状态已为已连接（`isConnected == true`），则不会重新扫描；
    ///   - 扫描使用 `scanForPeripherals(withServices: nil)`，匹配设备后应通过 `didDiscover` 回调判断 UUID 并连接。
    ///
    /// - Example:
    /// ```swift
    /// let bleManager = iREdBluetooth.shared
    ///
    /// // 发起连接体温计
    /// await bleManager.connect(from: .thermometer)
    ///
    /// // 发起连接心率带
    /// await bleManager.connect(from: .heartRateBelt)
    /// ```
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
    
    /// 断开指定类型的蓝牙设备连接
    ///
    /// - Parameter deviceType: 需要断开的设备类型，支持单个设备类型（如 `.oximeter`），
    ///                         或 `.all_ired_devices` 表示断开所有 iRED 蓝牙设备。
    ///
    /// 当 `deviceType == .all_ired_devices` 时，会遍历并断开所有当前已连接的设备；
    /// 否则仅断开与指定类型匹配的第一个设备。
    ///
    /// - Note:
    /// 此方法基于 `iREdBluetoothDeviceType` 枚举进行匹配，
    /// 并使用 `centralManager.cancelPeripheralConnection()` 进行断开操作。
    ///
    /// - Example:
    /// ```swift
    /// let bleManager = iREdBluetooth.shared
    ///
    /// // 断开体温计设备
    /// bleManager.disconnect(from: .thermometer)
    ///
    /// // 断开所有已连接的 iRED 设备
    /// bleManager.disconnect(from: .all_ired_devices)
    /// ```
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
        if currentUUIDString != uuid {
            if RSSI.intValue < setRSSI { return } // 过滤信号弱的设备
        }
        
        switch deviceType {
            // HealthKit
        case .thermometer:
            let (uuidString, deviceName, macAddress) = thermometerService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.thermometerData.state.isPairing = false
            iredDeviceData.thermometerData.state.isPaired = true
            lastPairedThermometer = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            if let currentUUIDString, currentUUIDString == uuidString {
                guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
                centralManager.connect(per, options: nil)
            }
            stopPairing()
        case .oximeter:
            let (uuidString, deviceName, macAddress) = oximeterService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.oximeterData.state.isPairing = false
            iredDeviceData.oximeterData.state.isPaired = true
            lastPairedOximeter = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            if let currentUUIDString, currentUUIDString == uuidString {
                guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
                centralManager.connect(per, options: nil)
            }
            stopPairing()
        case .sphygmometer:
            let (uuidString, deviceName, macAddress) = sphygmometerService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.sphygmometerData.state.isPairing = false
            iredDeviceData.sphygmometerData.state.isPaired = true
            lastPairedSphygmometer = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            if let currentUUIDString, currentUUIDString == uuidString {
                guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
                centralManager.connect(per, options: nil)
            }
            stopPairing()
        case .scale:
            let (uuidString, deviceName, macAddress) = scaleService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty {
                print("配对，uuidString是空的")
                return }
            if iredDeviceData.scaleData.state.isPaired {
                print("配对了，尝试连接")
                guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
                centralManager.connect(per, options: nil)
                iredDeviceData.scaleData.state.isConnected = true
                scaleService.parseWeightData(peripheral: peripheral, advertisementData: advertisementData)
            } else {
                print("配对配对配对")
                iredDeviceData.scaleData.state.isPairing = false
                iredDeviceData.scaleData.state.isPaired = true
                iredDeviceData.scaleData.data.peripheralName = name
                lastPairedScale = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            }
//            if deviceType == .scale && lastPairedScale != nil {
//                guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
//                centralManager.connect(per, options: nil)
//                iredDeviceData.scaleData.state.isConnected = true
//                scaleService.parseWeightData(peripheral: peripheral, advertisementData: advertisementData)
//            }
            
            // SportKit
        case .jumpRope:
            let (uuidString, deviceName, macAddress) = jumpRopeService.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.jumpRopeData.state.isPairing = false
            iredDeviceData.jumpRopeData.state.isPaired = true
            let dev = iRedDevice(deviceType: deviceType, name: deviceName, peripheral: peripheral, rssi: RSSI, isConnected: false, macAddress: macAddress)
            var jumpRopeData = self.iredDeviceData.jumpRopeData.data
            jumpRopeData.peripheralName = name
            jumpRopeData.macAddress = macAddress
            self.iredDeviceData.jumpRopeData.data = jumpRopeData
            self.lastPairedJumpRope = PairedDeviceModel(uuidString: uuid, name: peripheral.name, macAddress: macAddress)
            self.bleDelegate?.bleDeviceCallback(callback: .discovered(deviceType: deviceType, device: dev))
            
            if let currentUUIDString, currentUUIDString == uuidString {
                guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
                centralManager.connect(per, options: nil)
            }
            
            stopPairing()
        case .heartRateBelt:
            let (uuidString, deviceName, macAddress) = heartrateProfile.setPairedDevice(peripheral: peripheral, advertisementData: advertisementData)
            if uuidString.isEmpty { return }
            iredDeviceData.heartRateData.state.isPairing = false
            iredDeviceData.heartRateData.state.isPaired = true
            iredDeviceData.heartRateData.data.peripheralName = name
            lastPairedHeartRate = PairedDeviceModel(uuidString: uuid, name: deviceName, macAddress: macAddress)
            
            if let currentUUIDString, currentUUIDString == uuidString {
                guard let per = devices.filter({ $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }).first?.peripheral else { return }
                centralManager.connect(per, options: nil)
            }
            
            stopPairing()
        default:
            /// print("others")
            break
        }
        startPairingningAlert?.dismiss(animated: true, completion: nil)
        
    }
    
    // MARK: Connect devices
    @MainActor public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectingLoadingAlert?.dismiss(animated: true, completion: {
            self.connectingLoadingAlert = nil
        })
        guard let name = peripheral.name else { return }
        currentUUIDString = nil
        /// print("Connection successful: \(name)")
        let deviceType: iREdBluetoothDeviceType = deviceTypeByPeripheralName(name)
        guard let device = devices.filter({ $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }).first else { return }
        peripheral.delegate = self
        switch deviceType {
        case .thermometer:
            peripheral.discoverServices(nil)
            iredDeviceData.thermometerData.data = .empty
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
            break
        }
        devices.updateDevice(with: peripheral.identifier.uuidString) { device in
            device.isConnected = true
        }
        bleDelegate?.bleDeviceCallback(callback: .connected(deviceType: deviceTypeByPeripheralName(name), device: device))
    }
    
    // connection failed
    @MainActor public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectingLoadingAlert?.dismiss(animated: true, completion: {
            self.connectingLoadingAlert = nil
        })
        /// print("Connection failure: \(error?.localizedDescription ?? "Unknown error")")
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
        guard let name = peripheral.name else { return }
        guard let device = devices.filter({ $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }).first else { return }
        /// print("disconnect: \(name)")
        switch device.deviceType {
        case .thermometer:
            // iredDeviceData.thermometerData.data = .empty
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
        var scaleState = iredDeviceData.scaleData.state
        if isFinalResult {
            scaleState.isMeasurementCompleted = true
            scaleState.isMeasuring = false
        } else {
            scaleState.isMeasuring = true
            scaleState.isMeasurementCompleted = false
        }
        DispatchQueue.main.async {
            self.iredDeviceData.scaleData.data.weight = weight
            self.iredDeviceData.scaleData.state = scaleState
        }
        hkDelegate?.scaleCallback(callback: .weight(weight: weight, isFinalResult: isFinalResult))
        skDelegate?.scaleCallback(callback: .weight(weight: weight, isFinalResult: isFinalResult))
    }
}

// MARK: Thermometer
extension iREdBluetooth: @preconcurrency ThermometerServiceDelegate {
    /// - Parameters:
    ///   - temperature: Temperature
    ///   - mode: Mode
    ///   - modeString: Mode description
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
    
    /// - Parameters:
    ///   - error: Error code
    ///   - description: Error description
    public func thermometerErrorCallback(error: Int, description: String) {
        hkDelegate?.thermometerCallback(callback: .error(error: error, description: description))
        iredDeviceData.thermometerData.state.isMeasurementError = MeasurementError(errorCode: error, errorDescription: description)
    }
    
    /// - Parameters:
    ///   - type: Battery type
    ///   - description: Battery description
    @MainActor public func thermometerBatteryLevelCallback(type: Int, description: String) {
        hkDelegate?.thermometerCallback(callback: .battery(type: type, description: description))
        iredDeviceData.thermometerData.data = .empty
        iredDeviceData.thermometerData.state.isConnected = true
        iredDeviceData.thermometerData.data.battery = description
    }
}

// MARK: Oximeter
extension iREdBluetooth: @preconcurrency OximeterServiceDelegate {
    /// 处理血氧仪设备电池电量及脉搏波形数据的回调。
    ///
    /// 当设备返回电量和脉搏原始数据时，更新对应数据模型并发送回调。
    ///
    /// - Parameters:
    ///   - batteryPercentage: 当前设备电池电量（0~100）。
    ///   - pulseData: 原始脉搏波形数据（`Data` 类型，每字节代表一个强度值）。
    public func oximeterBatteryCallback(batteryPercentage: Int, pulseData: Data) {
        hkDelegate?.oximeterCallback(callback: .battery(batteryPercentage: batteryPercentage, pulseData: pulseData))
        iredDeviceData.oximeterData.data.battery = batteryPercentage
        iredDeviceData.oximeterData.data.pulsData = pulseData
        iredDeviceData.oximeterData.data.PlethysmographyArray += pulseData.map(Int.init)
    }
    
    /// 处理血氧仪测量数据的回调，包括脉搏、血氧饱和度和灌注指数。
    ///
    /// 该方法用于接收设备实时返回的测量结果并更新数据模型，同时触发回调传递给上层。
    ///
    /// - Parameters:
    ///   - pulse: 脉搏值（单位：BPM），当值为 `255` 时视为无效脉搏，将重置为 `0`。
    ///   - spo2: 血氧饱和度（单位：%），当值为 `127` 时视为无效，将重置为 `0`。
    ///   - pi: 灌注指数（Perfusion Index），表示脉搏强度。
    public func oximeterMeasurementCallback(pulse: Int, spo2: Int, pi: Double) {
        // 上报数据至代理
        hkDelegate?.oximeterCallback(callback: .measurement(pulse: pulse, spo2: spo2, pi: pi))
        
        // 处理异常值：255 表示无效脉搏，127 表示无效 SpO2
        iredDeviceData.oximeterData.data.pulse = pulse == 255 ? 0 : pulse
        iredDeviceData.oximeterData.data.spo2 = spo2 == 127 ? 0 : spo2
        iredDeviceData.oximeterData.data.pi = pi
        
        // 存储历史数据
        iredDeviceData.oximeterData.data.SpO2Array.append(spo2)
        iredDeviceData.oximeterData.data.BPMArray.append(pulse)
        iredDeviceData.oximeterData.data.PIArray.append(pi)
    }
}
extension iREdBluetooth {
    /// 生成基于血氧仪测量结果的健康状态评估报告文本。
    ///
    /// 此方法会根据提供的平均 SpO₂、BPM、PI 值与设定的正常范围，生成一段用户友好的健康提示文字。
    ///
    /// - Parameters:
    ///   - avgSpO2: 平均血氧饱和度（百分比），通常正常范围为 95~100%。
    ///   - avgBPM: 平均脉搏数（每分钟心跳次数），通常正常范围为 60~100。
    ///   - avgPi: 平均灌注指数，表示血液流动强度，正常范围大致在 0.2~20.0。
    ///   - spo2LowerBound: 血氧饱和度的下界（默认：95）。
    ///   - spo2UpperBound: 血氧饱和度的上界（默认：100）。
    ///   - bpmLowerBound: 脉搏的下界（默认：60）。
    ///   - bpmUpperBound: 脉搏的上界（默认：100）。
    ///   - piLowerBound: 灌注指数的下界（默认：0.2）。
    ///   - piUpperBound: 灌注指数的上界（默认：20.0）。
    ///
    /// - Returns: 一段表示健康评估结果的字符串，如“Your body is healthy”或相关医学建议。
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
    /// 生成血氧仪测量结果的详细文字报告。
    ///
    /// 此函数将计算并格式化用户的平均血氧饱和度（SpO₂）、平均心率（BPM）、平均灌注指数（PI），
    /// 并生成带有正常参考范围的可读字符串。如果数据不足，将提示用户重新测量。
    ///
    /// - Parameter data: 来自 `HealthKitOximeterModel` 的完整测量数据模型，包含多个历史采样值。
    ///
    /// - Returns: 字符串形式的测量结果摘要，附带健康建议或错误提示。
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
    /// 表示跳绳设备的工作模式设置。
    ///
    /// 跳绳设备支持三种不同的工作模式：自由跳、定时跳、计数跳。
    /// 每种模式都可以在调用开始跳绳测量时进行配置。
    public enum SetJumpRopeMode {
        
        /// 自由跳模式，无时间或次数限制，用户可随意跳绳。
        case free
        
        /// 定时跳模式，用户设定跳绳时长（单位：秒）。
        /// - Parameter second: 跳绳持续时间（秒），需为非负值。
        case time(second: Int)
        
        /// 计数跳模式，用户设定跳绳目标次数。
        /// - Parameter count: 跳绳次数目标，需为非负值。
        case count(count: Int)
    }
}
extension iREdBluetooth {
    /// 跳绳记录时使用的全局定时器，每秒触发一次，用于记录跳绳次数快照。
    ///
    /// 该定时器会在调用 `startJumpRopeRecording` 时启动，
    /// 并在 `stopJumpRopeRecording` 中停止，用于每秒采样当前跳绳计数。
    ///
    /// > 注意：由于定时器涉及 UI 和数据更新，因此必须在主线程中运行（受 `@MainActor` 约束）。
    @MainActor private static var jumpRopeTimer: Timer?
    
    /// 跳绳设备操作过程中可能出现的错误类型。
    ///
    /// 用于在设置跳绳模式或启动测量时进行错误处理，
    /// 并通过 `LocalizedError` 提供用户可读的错误提示信息。
    enum JumpRopeError: LocalizedError {
        
        /// 在定时跳模式下传入了非法时间（如负数）。
        case invalidTime
        
        /// 在计数跳模式下传入了非法计数（如负数）。
        case invalidCount
        
        /// 未找到已连接的跳绳设备。
        case deviceNotFound
        
        /// 错误描述（用于提示用户）。
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
    
    /// 启动跳绳设备的记录功能，根据指定模式进行设置，并开启计时器记录每秒跳绳次数。
    ///
    /// 支持三种跳绳模式：自由跳、定时跳、计数跳。函数会根据模式设置蓝牙设备工作方式，并清空旧记录数据。
    /// 若参数无效（如负数时间或次数），将通过 `completion` 返回错误。
    ///
    /// - Parameters:
    ///   - mode: 跳绳模式，使用 `SetJumpRopeMode` 枚举，支持 `.free`（自由跳）、`.time(seconds)`（定时跳）、`.count(times)`（计数跳）。
    ///   - completion: 设置完成后的回调，返回 `.success` 表示设置成功，`.failure` 表示传入参数无效。
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
    
    /// 停止跳绳记录，并清理定时器与设备状态。
    ///
    /// 此函数会结束当前跳绳测量，停止跳绳蓝牙设备的工作模式，
    /// 标记测量状态为完成，并自动停止心率带记录（如果其处于测量中状态）。
    ///
    /// 需在主线程执行（通过 `@MainActor` 保证），通常配合 `startJumpRopeRecording()` 使用。
    @MainActor public func stopJumpRopeRecording() {
        // print(#function, "停止跳绳记录")
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
    /// 心率带记录用的全局定时器，每秒触发一次，用于采集当前心率快照。
    ///
    /// 此定时器在调用 `startHeartRateRecording()` 时启动，
    /// 每秒将当前心率值封装成 `HeartRateBeltArrayModel` 并追加至历史记录数组中，
    /// 在调用 `stopHeartRateRecording()` 时停止并释放资源。
    ///
    /// > ⚠️ 注意：由于定时器涉及 UI 更新与数据写入，需在主线程执行（受 `@MainActor` 保护）。
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
    /// 设置蓝牙设备扫描时的 RSSI 信号强度过滤阈值。
    ///
    /// 此方法用于设定一个 RSSI（Received Signal Strength Indicator）下限值，
    /// 在设备扫描过程中仅保留信号强度高于该值的设备，用于过滤过远或信号弱的设备。
    ///
    /// - Parameter limit: RSSI 阈值（通常为负数，例如 -70 表示只保留信号强于 -70dBm 的设备）。
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
