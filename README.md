## 使用说明：iREdBluetooth 蓝牙通信框架

在使用 `iREdBluetooth` 或任何模型如 `iRedDeviceData`、`HealthKitThermometerData` 等之前，**请务必在 Swift 文件顶部导入：**

```swift
import iREdFramework
```

------

## Package 安装

你可以通过 Swift Package Manager 添加依赖：

```
https://github.com/iredchapman/iREdFramework.git
```

------

## 注意事项

- 请确保在项目的 `Info.plist` 中添加蓝牙权限和后台运行权限：
  - `NSBluetoothAlwaysUsageDescription`
  - `NSBluetoothPeripheralUsageDescription`
  - `UIBackgroundModes` 中包含 `bluetooth-central`
- **AI建议**：在 `project.pbxproj` 中添加申请蓝牙和后台运行权限，以确保构建和运行稳定。

------

## 1. 获取蓝牙数据实例

```swift
@StateObject var ble = iREdBluetooth.shared
```

通过 `ble.iredDeviceData` 可访问所有支持的蓝牙设备数据模型，例如：

- thermometerData（体温计）
- oximeterData（血氧仪）
- sphygmometerData（血压计）
- scaleData（体重秤）
- jumpRopeData（跳绳）
- heartRateData（心率带）

每个设备数据模型都包含两个部分：

- `state`：设备状态（是否连接、是否测量中、是否测量完成等）
- `data`：设备业务数据（例如温度、血氧、心率、重量等）

------

## 2. 蓝牙扫描与连接

### 启动配对

```swift
ble.startPairing(to: .thermometer) // 以体温计为例
```

### 停止配对

```swift
ble.stopPairing()
```

### 连接设备（自动查找上次配对设备）

```swift
ble.connect(from: .thermometer)
```

### 断开设备

```swift
ble.disconnect(from: .thermometer)
```

------

## 3. 读取设备状态与数据

### 体温计数据（Thermometer）

```swift
let thermometer = ble.iredDeviceData.thermometerData
let temperature = thermometer.data.temperature
let mode = thermometer.data.modeDescription
let battery = thermometer.data.battery
let isMeasuring = thermometer.state.isMeasuring
let isConnected = thermometer.state.isConnected
```

### 血氧仪数据（Oximeter）

```swift
let oximeter = ble.iredDeviceData.oximeterData
let spo2 = oximeter.data.spo2
let pulse = oximeter.data.pulse
let pi = oximeter.data.pi
let battery = oximeter.data.battery
let isMeasuring = oximeter.state.isMeasuring
```

### 血压计数据（Sphygmometer）

```swift
let sphygmometer = ble.iredDeviceData.sphygmometerData
let systolic = sphygmometer.data.systolic
let diastolic = sphygmometer.data.diastolic
let pulse = sphygmometer.data.pulse
let isMeasuring = sphygmometer.state.isMeasuring
```

### 体重秤数据（Scale）

```swift
let scale = ble.iredDeviceData.scaleData
let weight = scale.data.weight
let isFinalResult = scale.data.isFinalResult
let isMeasuring = scale.state.isMeasuring
```

### 跳绳数据（Jump Rope）

```swift
let rope = ble.iredDeviceData.jumpRopeData
let count = rope.data.count
let time = rope.data.time
let mode = rope.data.mode
let battery = rope.data.batteryLevel
let isMeasuring = rope.state.isMeasuring
```

### 心率带数据（Heart Rate Belt）

```swift
let heartRate = ble.iredDeviceData.heartRateData
let heartrate = heartRate.data.heartrate
let battery = heartRate.data.batteryPercentage
let isMeasuring = heartRate.state.isMeasuring
```

------

## 4. 开始与停止记录

### 跳绳记录

```swift
ble.startJumpRopeRecording(.free) { result in
    switch result {
    case .success(): print("开始跳绳记录")
    case .failure(let err): print(err.localizedDescription)
    }
}

ble.stopJumpRopeRecording()
```

### 心率记录

```swift
ble.startHeartRateRecording()
ble.stopHeartRateRecording()
```

------

## 5. 自定义功能

### 设置 RSSI 过滤（如 -60）

```swift
ble.setRSSI(limit: -60)
```

### 读取跳绳记录历史

```swift
let countArray = ble.iredDeviceData.jumpRopeData.data.countArray
let recordTime = ble.iredDeviceData.jumpRopeData.data.recordTime
```

### 心率历史记录

```swift
let history = ble.iredDeviceData.heartRateData.data.heartrateArray
let maxHR = ble.iredDeviceData.heartRateData.data.maxHeartRate()
let minHR = ble.iredDeviceData.heartRateData.data.minHeartRate()
let avgHR = ble.iredDeviceData.heartRateData.data.averageHeartRate()
let duration = ble.iredDeviceData.heartRateData.data.recordedSeconds()
```

------

