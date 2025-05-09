import Foundation
import CoreBluetooth

public typealias iRedPeripheral = CBPeripheral

// MARK: Models
/// 表示一个 iRED 蓝牙设备的基本信息模型。
///
/// 包含设备类型、设备名称、蓝牙外设对象、信号强度、连接状态和 MAC 地址。
public struct iRedDevice: Equatable {
    
    /// 设备类型，例如体温计、血氧仪等。
    public var deviceType: iREdBluetoothDeviceType
    
    /// 设备的蓝牙名称。
    public var name: String
    
    /// 蓝牙外设对象。
    public var peripheral: iRedPeripheral
    
    /// 信号强度（RSSI），可选。
    public var rssi: NSNumber?
    
    /// 当前是否已连接。
    public var isConnected: Bool
    
    /// 设备的 MAC 地址（如有）。
    public var macAddress: String?
}

extension Array where Element == iRedDevice {
    
    /// 向设备列表中添加一个唯一的新设备（若不存在相同 UUID）。
    /// - Parameter device: 要添加的蓝牙设备。
    mutating func appendUnique(_ device: iRedDevice) {
        if !self.contains(where: { $0.peripheral.identifier.uuidString == device.peripheral.identifier.uuidString }) {
            self.append(device)
        }
    }
    
    /// 根据设备的 UUID 更新列表中对应的设备。
    /// - Parameters:
    ///   - uuidString: 要更新的设备 UUID 字符串。
    ///   - update: 更新操作闭包，传入待更新的设备引用。
    mutating func updateDevice(with uuidString: String, update: (inout iRedDevice) -> Void) {
        if let index = self.firstIndex(where: { $0.peripheral.identifier.uuidString == uuidString }) {
            var device = self[index]
            update(&device)
            self[index] = device
        }
    }
}


/// 表示当前蓝牙状态的枚举。
public enum BlueToothState: String {
    /// 未知状态。
    case unknown = "Unknown state"
    /// 蓝牙正在重置。
    case resetting = "Resetting"
    /// 当前设备不支持蓝牙。
    case unsupported = "Unsupported"
    /// 应用未授权使用蓝牙。
    case unauthorized = "Unauthorized"
    /// 蓝牙已关闭。
    case poweredOff = "Powered off"
    /// 蓝牙已开启，可使用。
    case poweredOn = "Powered on"
}



/// 用于控制蓝牙扫描和连接行为的配置项。
public struct Config {
    
    /// 是否扫描到设备后自动连接。
    public var isScannedAutoConnect: Bool = false
    
    /// 是否连接成功后自动停止扫描。
    public var isConnectedAutoStopScan: Bool = false
    
    /// 是否在扫描到设备时弹出提示。
    public var isScannedShowAlert: Bool = false
    
    /// 是否在连接成功时弹出提示。
    public var isConnectedShowAlert: Bool = false
    
    /// 是否自动显示测量结果提示弹窗。
    public var isAutoShowResultAlert: Bool = false
    
    /// 是否扫描到设备后自动停止扫描。
    public var isScannedAutoStopScan: Bool = false
    
    /// 是否在扫描中显示加载提示。
    public var isShowScanningAlert: Bool = false
    
    /// 初始化方法，支持各项配置设置。
    public init(isScannedAutoConnect: Bool = false, isConnectedAutoStopScan: Bool = false, isScannedShowAlert: Bool = false, isConnectedShowAlert: Bool = false, isAutoShowResultAlert: Bool = false, isScannedAutoStopScan: Bool = false, isShowScanningAlert: Bool = false) {
        self.isScannedAutoConnect = isScannedAutoConnect
        self.isConnectedAutoStopScan = isConnectedAutoStopScan
        self.isScannedShowAlert = isScannedShowAlert
        self.isConnectedShowAlert = isConnectedShowAlert
        self.isAutoShowResultAlert = isAutoShowResultAlert
        self.isScannedAutoStopScan = isScannedAutoStopScan
        self.isShowScanningAlert = isShowScanningAlert
    }
}

/// 蓝牙设备连接过程中的回调事件，用于上层监听发现、连接、断开等状态。
public enum BLEDeviceCallback {
    
    /// 扫描到设备。
    /// - Parameters:
    ///   - deviceType: 设备类型。
    ///   - device: 扫描到的设备信息。
    case discovered(deviceType: iREdBluetoothDeviceType, device: iRedDevice)
    
    /// 设备连接成功。
    /// - Parameters:
    ///   - deviceType: 设备类型。
    ///   - device: 连接的设备信息。
    case connected(deviceType: iREdBluetoothDeviceType, device: iRedDevice)
    
    /// 设备已断开连接。
    /// - Parameters:
    ///   - deviceType: 设备类型。
    ///   - device: 断开的设备信息。
    case disconnected(deviceType: iREdBluetoothDeviceType, device: iRedDevice)
}

/// 体温计测量过程的回调事件。
public enum ThermometerCallback {
    /// 温度数据回调。
    case temperature(temperature: Double, mode: Int, modeString: String)
    /// 电池状态回调。
    case battery(type: Int, description: String)
    /// 错误回调。
    case error(error: Int, description: String)
}

/// 血氧仪测量过程的回调事件。
public enum OximeterCallback {
    /// 电池信息回调（包含脉搏波形原始数据）。
    case battery(batteryPercentage: Int, pulseData: Data)
    /// 血氧测量结果回调。
    case measurement(pulse: Int, spo2: Int, pi: Double)
}

/// 血压计测量过程的回调事件。
public enum SphygmometerCallback {
    /// 实时测量压力值。
    case instantData(pressure: Int, pulseStatus: Int)
    /// 测量结束后的最终数据。
    case finalData(systolic: Int, diastolic: Int, pulse: Int, irregularPulse: Int)
}

/// 体重秤测量过程的回调事件。
public enum ScaleCallback {
    /// 重量变化或最终结果。
    case weight(weight: Double, isFinalResult: Bool)
}

/// 跳绳设备的工作模式。
public enum JumpRopeMode: String, CaseIterable  {
    /// 自由跳（无计时/计数限制）。
    case free = "Free Mode"
    /// 计时跳模式。
    case time = "Time Mode"
    /// 计数跳模式。
    case count = "Count Mode"
    /// 未设置模式。
    case none = "None Mode"
}

/// 跳绳设备的当前状态。
public enum JumpRopeState {
    /// 未开始跳绳。
    case notJumpingRope
    /// 正在跳绳。
    case jumpingRope
    /// 跳绳暂停。
    case pauseRope
    /// 跳绳已结束。
    case endOfJumpRope
}

/// 跳绳设备数据回调事件。
public enum JumpRopeCallback {
    /// 跳绳数据更新。
    /// - Parameters:
    ///   - mode: 当前模式。
    ///   - status: 当前状态。
    ///   - setting: 用户设置值（如目标时间/次数）。
    ///   - count: 当前跳绳次数。
    ///   - time: 当前跳绳时长。
    ///   - screen: 当前屏显状态。
    ///   - battery: 电池电量等级。
    case result(mode: JumpRopeMode, status: JumpRopeState, setting: Int, count: Int, time: Int, screen: Int, battery: Int)
}
/// 心率带设备回调事件。
public enum HeartRateCallback {
    /// 心率更新回调。
    case heartrate(heartrate: Int)
    /// 电池电量更新回调。
    case battery(batteryLevel: Int)
}


/// 用户基本体型信息，用于计算 BMI 或脂肪率等指标。
public struct BodyInfo {
    /// 身高（厘米）。
    public let height: Int
    /// 年龄（岁）。
    public let age: Int
    /// 性别（如 "male", "female"）。
    public let gender: String
    /// 目标体重（kg）。
    public let targetWeight: Int
}

// MARK: Data

/// 表示设备当前状态，如是否连接、是否测量中等。
public struct DeviceStatusModel: Equatable {
    /// 正在配对中。
    public var isPairing: Bool = false
    /// 是否已配对。
    public var isPaired: Bool = false
    /// 正在尝试连接。
    public var isConnecting: Bool = false
    /// 当前是否已连接。
    public var isConnected: Bool = false
    /// 上一次连接是否失败。
    public var isConnectionFailure: Bool = false
    /// 是否处于断开状态。
    public var isDisconnected: Bool = false
    
    /// 是否正在进行测量。
    public var isMeasuring: Bool = false
    /// 测量是否已完成。
    public var isMeasurementCompleted: Bool = false
    /// 测量是否处于暂停状态。
    public var isPauseMeasurement: Bool = false
    /// 是否出现测量错误。
    public var isMeasurementError: MeasurementError? = nil
}

/// 表示测量过程中发生的错误信息。
public struct MeasurementError: Equatable {
    /// 错误码。
    let errorCode: Int
    /// 错误描述。
    let errorDescription: String
    
    /// 初始化测量错误。
    /// - Parameters:
    ///   - errorCode: 错误码。
    ///   - errorDescription: 描述。
    public init(errorCode: Int, errorDescription: String) {
        self.errorCode = errorCode
        self.errorDescription = errorDescription
    }
}

public protocol HealthDeviceModel {
    var state: DeviceStatusModel { get set }
}

/// 体温计设备数据模型，封装测量温度、电池、电源模式等信息。
public struct HealthKitThermometerModel {
    
    /// 蓝牙设备名称。
    public var peripheralName: String? = nil
    
    /// 设备 MAC 地址。
    public var macAddress: String? = nil
    
    /// 当前电池状态描述。
    public var battery: String? = nil
    
    /// 当前测量的温度（摄氏度）。
    public var temperature: Double? = nil
    
    /// 当前温度测量模式代码。
    public var modeCode: Int? = nil
    
    /// 模式描述，如“额温”、“耳温”等。
    public var modeDescription: String? = nil
    
    /// 空模型初始化。
    @MainActor public static let empty = HealthKitThermometerModel()
}

/// 封装体温计设备状态和数据的结构体。
public struct HealthKitThermometerData {
    
    /// 当前设备连接与测量状态。
    public var state: DeviceStatusModel = DeviceStatusModel()
    
    /// 当前体温计的数据模型。
    public var data: HealthKitThermometerModel = HealthKitThermometerModel()
    
    /// 空数据模型。
    @MainActor public static let empty = HealthKitThermometerData()
}


/// 血氧仪设备数据模型，封装 SpO2、PI、BPM 及脉搏波形等信息。
public struct HealthKitOximeterModel {
    
    /// 蓝牙设备名称。
    public var peripheralName: String? = nil
    
    /// MAC 地址。
    public var macAddress: String? = nil
    
    /// 当前电池电量（百分比）。
    public var battery: Int? = nil
    
    /// 原始脉搏波数据（用于图形绘制）。
    public var pulsData: Data? = nil
    
    /// 当前脉搏值（BPM）。
    public var pulse: Int? = nil
    
    /// 当前血氧饱和度（SpO2）。
    public var spo2: Int? = nil
    
    /// 灌注指数（PI）。
    public var pi: Double? = nil
    
    /// 历史 SpO2 数组。
    public var SpO2Array: [Int] = []
    
    /// 历史 PI 数组。
    public var PIArray: [Double] = []
    
    /// 历史心率数组。
    public var BPMArray: [Int] = []
    
    /// 有效记录次数（心率）。
    public var bpmCount: Int? = nil
    
    /// 有效记录 PI 次数。
    public var piCount: Double? = nil
    
    /// 有效记录 SpO2 次数。
    public var spo2Count: Int? = nil
    
    /// 分析后最终结果 PI。
    public var resultPI: String? = nil
    
    /// 脉搏波形数据（用于图表绘制）。
    public var PlethysmographyArray: [Int] = []
    
    /// 空模型初始化。
    @MainActor public static let empty = HealthKitOximeterModel()
    
    /// 计算平均 SpO2（排除无效值）。
    public func averageSpo2() -> Int {
        if SpO2Array.isEmpty {
            return 0
        }
        let temp_SpO2Array = SpO2Array.map({ $0 == 127 ? 0 : $0 })
        return temp_SpO2Array.reduce(0, +) / temp_SpO2Array.count
    }
    
    /// 计算平均 BPM（排除无效值）。
    public func averageBPM() -> Int {
        if BPMArray.isEmpty {
            return 0
        }
        let temp_BPMArray = BPMArray.filter({ $0 != 255 })
        if temp_BPMArray.isEmpty {
            return 0
        }
        return temp_BPMArray.reduce(0, +) / temp_BPMArray.count
    }
    
    /// 计算平均 PI。
    public func averagePI() -> Double {
        PIArray.reduce(0, +) / Double(PIArray.count)
    }
}

/// 血氧仪数据和状态包装。
public struct HealthKitOximeterData {
    
    /// 当前设备连接与测量状态。
    public var state: DeviceStatusModel = DeviceStatusModel()
    
    /// 血氧仪数据模型。
    public var data: HealthKitOximeterModel = HealthKitOximeterModel()
    
    /// 空模型初始化。
    @MainActor public static let empty = HealthKitOximeterData()
}

/// 血压计设备数据模型，用于封装一次测量过程中的所有关键信息。
public struct HealthKitSphygmometerModel {
    
    /// 蓝牙设备名称（如 "iRED BP Monitor"）。
    public var peripheralName: String? = nil
    
    /// 设备的 MAC 地址。
    public var macAddress: String? = nil
    
    /// 实时测量中的压力值（单位：mmHg）。
    public var pressure: Int? = nil
    
    /// 心跳检测状态码（取值根据设备定义，一般表示节律状态）。
    public var pulseStatus: Int? = nil
    
    /// 测量结果中的收缩压（高压，单位：mmHg）。
    public var systolic: Int? = nil
    
    /// 测量结果中的舒张压（低压，单位：mmHg）。
    public var diastolic: Int? = nil
    
    /// 测量结果中的脉搏值（单位：BPM）。
    public var pulse: Int? = nil
    
    /// 是否检测到心律不齐（1 表示有，0 表示无）。
    public var irregularPulse: Int? = nil
    
    /// 空模型初始化（用于清空或重置数据）。
    @MainActor public static let empty = HealthKitSphygmometerModel()
}

/// 封装血压计设备的状态与测量数据。
public struct HealthKitSphygmometerData {
    
    /// 当前设备的连接与测量状态（如是否正在配对、连接、测量中等）。
    public var state: DeviceStatusModel = DeviceStatusModel()
    
    /// 当前血压计采集到的数据。
    public var data: HealthKitSphygmometerModel = HealthKitSphygmometerModel()
    
    /// 空数据模型，用于初始化或重置。
    @MainActor public static let empty = HealthKitSphygmometerData()
}

/// 体重秤数据模型，包含体重值、BMI 计算、体脂率评估等功能。
public struct HealthKitScaleModel {
    
    /// 蓝牙设备名称。
    public var peripheralName: String? = nil
    
    /// MAC 地址。
    public var macAddress: String? = nil
    
    /// 当前体重（单位：kg）。
    public var weight: Double? = nil
    
    /// 是否为最终稳定结果。
    public var isFinalResult: Bool? = nil
    
    /// 将当前体重和身高转换为 BMI 值。
    /// - Parameters:
    ///   - height: 身高（单位：cm）。
    ///   - weight: 体重（单位：kg）。
    /// - Returns: 计算出的 BMI 值。
    public func toBMI(height: Int, weight: Double) -> Double {
        if height == 0 {
            return 0
        }
        let heightInMeters = Double(height) / 100.0
        let result = Double(String(format: "%.2f", weight / pow(heightInMeters, 2)))
        return result ?? 0
    }
    
    /// 根据 BMI、年龄和性别估算体脂率。
    /// - Parameters:
    ///   - height: 身高（cm）。
    ///   - age: 年龄（岁）。
    ///   - tempGender: 性别（"male"/"female"）。
    /// - Returns: 估算的体脂率百分比。
    public func toBodyFat(height: Int, age: Int, gender tempGender: String) -> Double {
        if height == 0 {
            return 0
        }
        let gender: Double = tempGender.lowercased() == "male" ? 1 : 0
        let bmi = toBMI(height: height, weight: weight ?? 0)
        let bodyfat = (1.39 * bmi) + (0.16 * Double(age)) - (10.34 * gender) - 9
        let result = Double(String(format: "%.2f", max(bodyfat, 0)))
        return result ?? 0
    }
    
    /// 根据 BMI 值评估健康状态。
    /// - Parameter height: 身高（cm）。
    /// - Returns: 健康状态描述。
    public func healthStatus(height: Int) -> String {
        switch toBMI(height: height, weight: weight ?? 0) {
        case 0..<18.5:
            "Underweight"
        case 18.5..<22.9:
            "Normal"
        case 22.9..<24.9:
            "Overweight"
        default:
            "Obese"
        }
    }
    
    /// 空模型初始化。
    @MainActor public static let empty = HealthKitScaleModel()
}

/// 体重秤设备状态和数据封装。
public struct HealthKitScalerData {
    
    /// 当前设备状态。
    public var state: DeviceStatusModel = DeviceStatusModel()
    
    /// 当前数据模型。
    public var data: HealthKitScaleModel = HealthKitScaleModel()
    
    /// 空数据模型。
    @MainActor public static let empty = HealthKitScalerData()
}


/// 跳绳设备数据模型
public struct JumpRopeModel: Equatable {
    /// 蓝牙外设名称
    public var peripheralName: String? = nil
    
    /// 设备 MAC 地址
    public var macAddress: String? = nil
    
    /// 模式：0 = 自由跳, 1 = 计时跳, 2 = 计数跳
    public var mode: Int? = nil
    
    /// 当前状态（例如是否在跳跃中，可自定义）
    public var status: Int? = nil
    
    /// 用户设置的参数（如目标时间/计数等）
    public var setting: Int? = nil
    
    /// 当前已跳绳次数
    public var count: Int? = nil
    
    /// 当前已跳绳时间（单位：秒）
    public var time: Int? = nil
    
    /// 当前设备屏幕显示状态
    public var screen: Int? = nil
    
    /// 电池电量等级：
    /// - 4: 电量 > 80%
    /// - 3: 电量 > 50%
    /// - 2: 电量 > 25%
    /// - 1: 电量 > 10%
    /// - 0: 电量 <= 10%
    public var batteryLevel: Int? = nil
    
    /// 空模型，用于初始化或清空状态
    @MainActor public static let empty = JumpRopeModel()
    
    /// 返回模式对应的字符串（Free / Time / Count）
    public func modeString() -> String {
        return mode == 0 ? "Free" : mode == 1 ? "Time" : mode == 2 ? "Count" : "Free"
    }
    
    /// 电池电量描述字符串
    public var batteryLevelDescription: String {
        guard let level = batteryLevel else { return "Unknown" }
        switch level {
        case 4:
            return "电量充足（>80%）"
        case 3:
            return "电量良好（>50%）"
        case 2:
            return "电量一般（>25%）"
        case 1:
            return "电量较低（>10%）"
        case 0:
            return "电量极低（<=10%）"
        default:
            return "未知电量等级"
        }
    }
    /// 跳绳历史记录数组（每秒记录）
    public var countArray: [JumpRopeArrayModel] = []
    /// 跳绳单次记录时长（单位：秒）
    public var recordTime: Int {
        countArray.count
    }
}
/// 单条跳绳记录
public struct JumpRopeArrayModel: Identifiable, Equatable {
    public let id = UUID()
    public let date: Date
    public let count: Int
    
    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

/// 跳绳设备的完整数据结构，包括状态与数据。
public struct JumpRopeData: Equatable {
    
    /// 当前状态信息（连接、测量等）。
    public var state: DeviceStatusModel = DeviceStatusModel()
    
    /// 跳绳数据内容。
    public var data: JumpRopeModel = JumpRopeModel()
    
    /// 空数据模型。
    @MainActor public static let empty = JumpRopeData()
}

/// 心率带数据模型，用于记录当前心率、设备信息、电量及历史记录
public struct HeartRateBeltModel: Equatable {
    /// 蓝牙设备名称
    public var peripheralName: String? = nil
    /// 设备 MAC 地址
    public var macAddress: String? = nil
    /// 当前心率值（最新一次）
    public var heartrate: Int? = nil
    /// 当前电池电量（百分比）
    public var batteryPercentage: Int? = nil
    /// 心率变化历史记录（每秒记录一次）
    public var heartrateArray: [HeartRateBeltArrayModel] = []
    
    /// 获取记录期间所有心率值的总和
    /// - Returns: 心率值累加总和（用于计算平均心率等）
    public func totalHeartrate() -> Int {
        return heartrateArray.reduce(0) { $0 + $1.heartrate }
    }
    
    /// 获取记录期间的最高心率值
    /// - Returns: 最高心率，若无记录则返回 nil
    public func maxHeartRate() -> Int? {
        return heartrateArray.max { $0.heartrate < $1.heartrate }?.heartrate
    }
    
    /// 获取记录期间的最低心率值
    /// - Returns: 最低心率，若无记录则返回 nil
    public func minHeartRate() -> Int? {
        return heartrateArray.min { $0.heartrate < $1.heartrate }?.heartrate
    }
    
    /// 获取已记录的总秒数
    /// - Returns: 心率数组的长度，即代表已记录的秒数
    public func recordedSeconds() -> Int {
        return heartrateArray.count
    }
    
    /// 获取记录期间的平均心率
    /// - Returns: 平均心率，若无记录则返回 nil
    public func averageHeartRate() -> Double? {
        guard !heartrateArray.isEmpty else { return nil }
        let total = totalHeartrate()
        let avg = Double(total) / Double(heartrateArray.count)
        return (avg * 100).rounded() / 100
    }
    
    /// 空模型初始化（默认值）
    @MainActor static let empty = HeartRateBeltModel()
}
/// 心率带设备中的单条心率记录，用于统计变化趋势。
public struct HeartRateBeltArrayModel: Equatable {
    
    /// 心率记录时间。
    public var date: Date = Date()
    
    /// 心率值（单位：BPM）。
    public var heartrate: Int
    
    /// 初始化方法。
    /// - Parameters:
    ///   - date: 记录时间，默认为当前时间。
    ///   - heartrate: 心率值。
    public init(date: Date = Date(), heartrate: Int) {
        self.date = date
        self.heartrate = heartrate
    }
}
/// 封装心率带设备的状态与实时数据。
public struct HeartRateBeltData: Equatable {
    
    /// 设备的连接与测量状态。
    public var state: DeviceStatusModel = DeviceStatusModel()
    
    /// 心率带的测量数据（当前心率、电量、历史记录等）。
    public var data: HeartRateBeltModel = HeartRateBeltModel()
    
    /// 空数据模型（用于初始化或重置）。
    @MainActor public static let empty = HeartRateBeltData()
}


/// 封装所有 iRED 蓝牙设备的数据集合，按设备类型划分。
///
/// 每个设备对应一个 `xxxData` 成员，包含当前状态和测量数据。
public struct iRedDeviceData {
    
    /// 体温计数据。
    public var thermometerData: HealthKitThermometerData = HealthKitThermometerData()
    
    /// 血氧仪数据。
    public var oximeterData: HealthKitOximeterData = HealthKitOximeterData()
    
    /// 血压计数据。
    public var sphygmometerData: HealthKitSphygmometerData = HealthKitSphygmometerData()
    
    /// 跳绳设备数据。
    public var jumpRopeData: JumpRopeData = JumpRopeData()
    
    /// 心率带数据。
    public var heartRateData: HeartRateBeltData = HeartRateBeltData()
    
    /// 体重秤数据。
    public var scaleData: HealthKitScalerData = HealthKitScalerData()
}


// MARK: ---------- HTTPClient ----------

/// 泛型请求响应结果，用于描述接口返回的成功或失败情况。
/// - success: 表示请求成功，包含返回码、信息和数据（可为 nil）。
/// - failure: 表示请求失败，包含返回码和错误信息。
public enum RequestResult<T> {
    
    /// 请求成功。
    /// - Parameters:
    ///   - code: 状态码。
    ///   - message: 成功描述信息。
    ///   - data: 实际返回数据。
    case success(code: Int, message: String, data: T?)
    
    /// 请求失败。
    /// - Parameters:
    ///   - code: 错误码。
    ///   - message: 错误描述。
    case failure(code: Int, message: String)
}

/// 上传用的血压计测量模型。
public struct SphygmometerModel: Decodable {
    
    /// 舒张压（低压，单位 mmHg）。
    public let diastolic: Int
    
    /// 收缩压（高压，单位 mmHg）。
    public let systolic: Int
    
    /// 脉搏（单位 BPM）。
    public let pulse: Int
    
    /// 测量时间（格式如 "2025-05-09 09:00:00"）。
    public let datetime: String
    
    /// 用户唯一标识。
    public let user: String
    
    /// 构造器。
    public init(diastolic: Int, systolic: Int, pulse: Int, datetime: String, user: String) {
        self.diastolic = diastolic
        self.systolic = systolic
        self.pulse = pulse
        self.datetime = datetime
        self.user = user
    }
}

/// 上传用的体重秤测量模型。
public struct ScaleModel: Decodable {
    
    /// 当前体重（kg）。
    public let weight: Double
    
    /// 当前体脂率（%）。
    public let bodyfat: Double
    
    /// 当前 BMI。
    public let bmi: Double
    
    /// 测量时间。
    public let datetime: String
    
    /// 用户标识。
    public let user: String
    
    public init(weight: Double, bodyfat: Double, bmi: Double, datetime: String, user: String) {
        self.weight = weight
        self.bodyfat = bodyfat
        self.bmi = bmi
        self.datetime = datetime
        self.user = user
    }
}

/// 上传用的血氧仪测量模型。
public struct OximeterModel: Decodable {
    
    /// 血氧饱和度（SpO₂）。
    public let spo2: Int
    
    /// 心率（BPM）。
    public let bpm: Int
    
    /// 灌注指数（PI）。
    public let pi: Double
    
    /// 测量时间。
    public let datetime: String
    
    /// 用户标识。
    public let user: String
    
    public init(spo2: Int, bpm: Int, pi: Double, datetime: String, user: String) {
        self.spo2 = spo2
        self.bpm = bpm
        self.pi = pi
        self.datetime = datetime
        self.user = user
    }
}


/// 上传用的体温计测量模型。
public struct ThermometerModel: Decodable {
    
    /// 测量温度（摄氏度）。
    public let temperature: Double
    
    /// 模式描述（如 "Forehead"、"Ear"）。
    public let mode: String
    
    /// 测量时间。
    public let datetime: String
    
    /// 用户标识。
    public let user: String
    
    public init(temperature: Double, mode: String, datetime: String, user: String) {
        self.temperature = temperature
        self.mode = mode
        self.datetime = datetime
        self.user = user
    }
    
    /// 错误数据占位（用于初始化失败）。
    @MainActor static let error = ThermometerModel(temperature: -1, mode: "Error", datetime: "", user: "Error")
}

/// 上传用的跳绳数据模型。
public struct RopeModel: Decodable {
    
    /// 跳绳次数。
    public let count: Int
    
    /// 测量时间。
    public let datetime: String
    
    /// 完成耗时（秒）。
    public let completiontime: Int
    
    /// 跳绳模式（如 "Free"、"Time"、"Count"）。
    public let mode: String
    
    /// 用户标识。
    public let user: String
    
    public init(count: Int, datetime: String, completiontime: Int, mode: String, user: String) {
        self.count = count
        self.datetime = datetime
        self.completiontime = completiontime
        self.mode = mode
        self.user = user
    }
}

/// 上传用的心率带数据模型。
public struct HeartRateModel: Decodable {
    
    /// 平均心率（BPM）。
    public let averagehr: Double
    
    /// 最低心率。
    public let minhr: Int
    
    /// 最高心率。
    public let maxhr: Int
    
    /// 记录时间。
    public let datetime: String
    
    /// 用户标识。
    public let user: String
    
    public init(averagehr: Double, minhr: Int, maxhr: Int, datetime: String, user: String) {
        self.averagehr = averagehr
        self.minhr = minhr
        self.maxhr = maxhr
        self.datetime = datetime
        self.user = user
    }
}

/// 通用 HTTP 接口返回结构体（支持泛型数据）。
/// 用于对接服务器标准 JSON 格式：
/// {
///   "code": Int,
///   "message": String,
///   "data": ...
/// }
public struct RequestModel<T: Decodable>: Decodable {
    
    /// 状态码。
    public let code: Int
    
    /// 状态信息。
    public let message: String
    
    /// 泛型数据部分。
    public let data: T
    
    public init(code: Int, message: String, data: T) {
        self.code = code
        self.message = message
        self.data = data
    }
}


public extension Int {
    /// 将时间戳（秒）转换为 `Date` 对象。
    var timestampToDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(self))
    }
}


/// 表示 iRED 系统支持的蓝牙设备类型。
///
/// 此枚举用于区分不同的设备类型，以便在配对、连接、数据处理等流程中进行分类处理。
/// 所有类型均符合 `Codable` 协议，支持编码与解码。
public enum iREdBluetoothDeviceType: String, Codable {
    
    /// 体温计设备，用于测量体温。
    case thermometer = "Thermometer"
    
    /// 血氧仪设备，用于测量血氧饱和度（SpO2）。
    case oximeter = "Oximeter"
    
    /// 血压计设备，用于测量血压。
    case sphygmometer = "Sphygmometer"
    
    /// 跳绳设备，支持跳绳计数、时间等运动数据采集。
    case jumpRope = "JumpRope"
    
    /// 心率带设备，用于持续监测心率。
    case heartRateBelt = "HeartRate"
    
    /// 体重秤设备，用于测量体重和身体成分。
    case scale = "Scale"
    
    /// 无设备类型，用于占位或初始状态。
    case none = "None"
    
    /// 所有 iRED 支持的设备类型的集合，用于调试或批量操作。
    case all_ired_devices = "All iRED Devices"
}


/// 表示已配对蓝牙设备的模型，用于本地持久化存储。
///
/// 包含设备的唯一标识符（UUID 字符串）、名称和可选的 MAC 地址信息。
public struct PairedDeviceModel: Codable {
    
    /// 蓝牙设备的 UUID 字符串（`CBPeripheral.identifier.uuidString`）。
    public var uuidString: String
    
    /// 设备名称（可选）。
    public var name: String?
    
    /// 设备的 MAC 地址（可选，部分设备可读取）。
    public var macAddress: String?

    /// 初始化方法。
    /// - Parameters:
    ///   - uuidString: 蓝牙设备 UUID 字符串。
    ///   - name: 蓝牙设备名称。
    ///   - macAddress: MAC 地址（如可用）。
    public init(uuidString: String, name: String?, macAddress: String?) {
        self.uuidString = uuidString
        self.name = name
        self.macAddress = macAddress
    }

    /// 从 `UserDefaults` 中解码并恢复 `PairedDeviceModel` 对象。
    ///
    /// 用于从本地持久化的数据中恢复配对设备信息。
    ///
    /// - Parameter key: 存储在 `UserDefaults` 中的键名。
    /// - Returns: 成功时返回解码后的 `PairedDeviceModel`，失败时返回 `nil`。
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
