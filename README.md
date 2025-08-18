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
x



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
ble.startPairing(to: .thermometer) // 开始配对温度计
```

### 停止配对

```swift
ble.stopPairing() // 停止配对
```

### 连接设备（自动查找上次配对设备）

```swift
ble.connect(from: .thermometer) // 连接温度计
```

### 断开设备

```swift
ble.disconnect(from: .thermometer) // 断开连接温度计
```
### 设置 RSSI 过滤（如 -60）

```swift
ble.setRSSI(limit: -60)
```

**RSSI 说明：**  
RSSI（Received Signal Strength Indicator，接收信号强度指示）是用来衡量蓝牙信号强弱的数值，单位通常是 dBm。  
数值越接近 0，表示信号越强；数值越小（如 -90），表示信号越弱。  
例如设置 RSSI 限制为 -60，表示只会连接信号强于 -60 dBm 的设备，可以避免连接过远或信号不稳定的设备。

------

## 3. 读取设备状态与数据

### 体温计数据（Thermometer）

```swift
let thermometer = ble.iredDeviceData.thermometerData
let temperature = thermometer.data.temperature // 温度
let mode = thermometer.data.modeDescription // 模式
let battery = thermometer.data.battery // 电池电量
let isPairing = thermometer.state.isPairing // 是否正在配对
let isConnected = thermometer.state.isConnected // 当前是否已连接
let isDisconnected = thermometer.state.isDisconnected // 是否已断开
```

### 血氧仪数据（Oximeter）

```swift
let oximeter = ble.iredDeviceData.oximeterData
let spo2 = oximeter.data.spo2 // 血氧
let pulse = oximeter.data.pulse // 脉搏
let pi = oximeter.data.pi // 灌注指数
let battery = oximeter.data.battery // 电池电量
let isPairing = oximeter.state.isPairing // 是否正在配对
let isConnected = oximeter.state.isConnected // 当前是否已连接
let isDisconnected = oximeter.state.isDisconnected // 是否已断开
```

### 血压计数据（Sphygmometer）

```swift
let sphygmometer = ble.iredDeviceData.sphygmometerData
let systolic = sphygmometer.data.systolic // 收缩压
let diastolic = sphygmometer.data.diastolic // 舒张压
let pulse = sphygmometer.data.pulse // 脉搏
let isPairing = sphygmometer.state.isPairing // 是否正在配对
let isConnected = sphygmometer.state.isConnected // 当前是否已连接
let isDisconnected = sphygmometer.state.isDisconnected // 是否已断开
```

### 体重秤数据（Scale）

```swift
let scale = ble.iredDeviceData.scaleData
let weight = scale.data.weight // 体重
let isFinalResult = scale.data.isFinalResult // 是否最终结果
let isPairing = scale.state.isPairing // 是否正在配对
let isConnected = scale.state.isConnected // 当前是否已连接
let isDisconnected = scale.state.isDisconnected // 是否已断开
```

### 跳绳数据（Jump Rope）

```swift
let rope = ble.iredDeviceData.jumpRopeData
let count = rope.data.count // 跳绳次数
let time = rope.data.time // 跳绳时长
let mode = rope.data.mode // 跳绳模式
let battery = rope.data.batteryLevel // 电池电量
let isPairing = rope.state.isPairing // 是否正在配对
let isConnected = rope.state.isConnected // 当前是否已连接
let isDisconnected = rope.state.isDisconnected // 是否已断开
```

### 心率带数据（Heart Rate Belt）

```swift
let heartRate = ble.iredDeviceData.heartRateData
let heartrate = heartRate.data.heartrate // 心率
let battery = heartRate.data.batteryPercentage // 电池电量
let isPairing = heartRate.state.isPairing // 是否正在配对
let isConnected = heartRate.state.isConnected // 当前是否已连接
let isDisconnected = heartRate.state.isDisconnected // 是否已断开
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
} // 自由跳绳

ble.startJumpRopeRecording(.time(second: 10)) {...} // 设定跳绳时间10秒为目标
ble.startJumpRopeRecording(.count(count: 10)) {...} // 设定跳绳数量10个为目标

ble.stopJumpRopeRecording()
```

------

## 5. 自定义功能



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
