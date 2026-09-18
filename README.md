---
name: iREdFramework
description: Provides integration patterns, API specifications, and SwiftUI code snippets for iREdFramework. Use this skill when pairing, connecting, disconnecting, controlling, or collecting data from iRED Bluetooth smart health and sport devices (thermometer, oximeter, sphygmometer, scale, jump rope, heart rate belt). Guides state management via iREdBluetooth.shared, data models extraction, and SPM dependency setup.
---

# iREdFramework

## 1. 接入集成全流程 (Workflow)

AI Agent 或开发者请按以下 5 步接入框架：

### 步骤 1：添加 SPM 依赖
- **Package URL**: `https://github.com/iredchapman/iREdFramework.git`

### 步骤 2：配置蓝牙权限 (Info.plist)
在 `Info.plist` 中添加 `Privacy - Bluetooth Always Usage Description` (`NSBluetoothAlwaysUsageDescription`) 权限说明即可。

### 步骤 3：导入模块
在需要使用蓝牙功能的视图或业务文件顶部导入：
```swift
import SwiftUI
import Combine
import iREdFramework
```

### 步骤 4：注入蓝牙管理器单例
在 SwiftUI View 中注入全局单例管理器：
```swift
@StateObject private var ble = iREdBluetooth.shared
```

### 步骤 5：设备控制与数据读取
- **配对**：`ble.startPairing(to: .<deviceType>)`（自动保存 UUID 并停止扫描）
- **停止扫描**：`ble.stopPairing()`
- **连接**：`ble.connect(from: .<deviceType>)`（重连已配对设备）
- **断开**：`ble.disconnect(from: .<deviceType>)` 或 `ble.disconnect(from: .all_ired_devices)`
- **信号过滤**：`ble.setRSSI(limit: -60)`
- **读取数据与状态**：从 `ble.iredDeviceData.<deviceType>Data.state` 读取状态，从 `.data` 读取指标

---

## 2. 统一设备状态机 (`DeviceStatusModel`)

所有外设统一通过 `ble.iredDeviceData.<deviceType>Data.state` 读取运行状态：

| 状态属性 | 类型 | 含义 |
| :--- | :--- | :--- |
| `isPairing` | `Bool` | 是否正在搜索配对中 |
| `isPaired` | `Bool` | 是否已完成配对（本地有持久化记录） |
| `isConnecting` | `Bool` | 是否正在连接中 |
| `isConnected` | `Bool` | 当前是否已连接 |
| `isConnectionFailure` | `Bool` | 最近一次连接是否失败 |
| `isDisconnected` | `Bool` | 是否处于断开状态 |
| `isMeasuring` | `Bool` | 是否处于测量中（如血压计加压、跳绳中） |
| `isMeasurementCompleted` | `Bool` | 测量是否已完成 |
| `isPauseMeasurement` | `Bool` | 测量是否处于暂停状态 |
| `isMeasurementError` | `MeasurementError?` | 测量异常信息（`errorCode: Int`, `errorDescription: String`） |

---

## 3. 六大设备详细说明与数据模型

### 3.1 🌡️ 体温计 (`.thermometer`)

- **访问路径**：`ble.iredDeviceData.thermometerData`
- **控制指令**：`ble.startPairing(to: .thermometer)`、`ble.connect(from: .thermometer)`、`ble.disconnect(from: .thermometer)`
- **数据字段 (`HealthKitThermometerModel`)**：
  - `temperature: Double?`：测得体温数值 (°C)
  - `modeCode: Int?` / `modeDescription: String?`：测量模式代号与描述，`modeDescription` 有 4 种可能返回值：`"Adult Forehead"`, `"Child Forehead"`, `"Ear Canal"`, `"Object"`
  - `battery: String?`：电池电量（百分比字符串，例如 "85%"）
  - `peripheralName: String?` / `macAddress: String?`：设备名称与 MAC 地址
  - `lastUpdatedTime: Date`：最后更新时间
- **测量异常**：读取 `state.isMeasurementError` 获取错误代码与描述。
- **SwiftUI 代码示例**：
```swift
Text("Status: \(ble.iredDeviceData.thermometerData.state.isConnected ? "Connected" : "Disconnected")")
Text("Temperature: \(String(format: "%.1f", ble.iredDeviceData.thermometerData.data.temperature ?? 0)) °C")
Text("Mode: \(ble.iredDeviceData.thermometerData.data.modeDescription ?? "-")")
Button("Pair") { ble.startPairing(to: .thermometer) }
Button("Connect") { ble.connect(from: .thermometer) }
Button("Disconnect") { ble.disconnect(from: .thermometer) }
```

---

### 3.2 🫁 血氧仪 (`.oximeter`)

- **访问路径**：`ble.iredDeviceData.oximeterData`
- **控制指令**：`ble.startPairing(to: .oximeter)`、`ble.connect(from: .oximeter)`、`ble.disconnect(from: .oximeter)`
- **数据字段 (`HealthKitOximeterModel`)**：
  - `spo2: Int?`：当前实时血氧饱和度 (%)
  - `pulse: Int?`：当前实时脉搏心率 (BPM)
  - `pi: Double?`：灌注指数 (Perfusion Index)
  - `battery: Int?`：电量百分比 (0~100)
- **分析与辅助方法**：
  - `data.averageSpo2() -> Int`：平均血氧
  - `data.averageBPM() -> Int`：平均心率
  - `data.averagePI() -> Double`：平均灌注指数
  - `ble.oximeterMeasurementResultsDetails(data: data) -> String`：根据均值和医学区间生成健康分析文本报告
- **SwiftUI 代码示例**：
```swift
Text("SpO₂: \(ble.iredDeviceData.oximeterData.data.spo2 ?? 0)%")
Text("Pulse: \(ble.iredDeviceData.oximeterData.data.pulse ?? 0) BPM")
Text("PI: \(String(format: "%.1f", ble.iredDeviceData.oximeterData.data.pi ?? 0.0))")
Text("Average SpO₂: \(ble.iredDeviceData.oximeterData.data.averageSpo2())%")
Button("Pair") { ble.startPairing(to: .oximeter) }
Button("Connect") { ble.connect(from: .oximeter) }
Button("Disconnect") { ble.disconnect(from: .oximeter) }
```

---

### 3.3 🩺 血压计 (`.sphygmometer`)

- **访问路径**：`ble.iredDeviceData.sphygmometerData`
- **控制指令**：`ble.startPairing(to: .sphygmometer)`、`ble.connect(from: .sphygmometer)`、`ble.disconnect(from: .sphygmometer)`
- **数据字段 (`HealthKitSphygmometerModel`)**：
  - `pressure: Int?`：**实时加压充气袖带压力** (mmHg)（当 `state.isMeasuring == true` 时持续刷新）
  - `pulseStatus: Int?`：心跳检测状态码
  - `systolic: Int?`：**收缩压 (高压)** (mmHg)（测量完成时输出）
  - `diastolic: Int?`：**舒张压 (低压)** (mmHg)（测量完成时输出）
  - `pulse: Int?`：**最终脉搏** (BPM)
  - `irregularPulse: Int?`：**心律不齐标识**（`1` 表示异常，`0` 表示正常）
- **SwiftUI 代码示例**：
```swift
if ble.iredDeviceData.sphygmometerData.state.isMeasuring {
    Text("Measuring: \(ble.iredDeviceData.sphygmometerData.data.pressure ?? 0) mmHg")
} else {
    Text("Systolic: \(ble.iredDeviceData.sphygmometerData.data.systolic ?? 0) mmHg")
    Text("Diastolic: \(ble.iredDeviceData.sphygmometerData.data.diastolic ?? 0) mmHg")
    Text("Pulse: \(ble.iredDeviceData.sphygmometerData.data.pulse ?? 0) BPM")
    Text("Irregular Pulse: \(ble.iredDeviceData.sphygmometerData.data.irregularPulse == 1 ? "Yes" : "No")")
}
Button("Pair") { ble.startPairing(to: .sphygmometer) }
Button("Connect") { ble.connect(from: .sphygmometer) }
```

---

### 3.4 ⚖️ 体重秤 (`.scale`)

- **访问路径**：`ble.iredDeviceData.scaleData`
- **控制指令**：`ble.startPairing(to: .scale)`、`ble.connect(from: .scale)`、`ble.disconnect(from: .scale)`
- **数据字段 (`HealthKitScaleModel`)**：
  - `weight: Double?`：体重数值 (kg)
  - `isFinalResult: Bool?`：数值是否已稳定锁定（`true` 为锁定最终值，`false` 为测量晃动中）
- **身体指标计算扩展**：
  - `data.toBMI(height: Int, weight: Double) -> Double`：BMI 计算
  - `data.toBodyFat(height: Int, age: Int, gender: String) -> Double`：估算体脂率 (%)
  - `data.healthStatus(height: Int) -> String`：健康等级评估 (`"Underweight"`, `"Normal"`, `"Overweight"`, `"Obese"`)
- **SwiftUI 代码示例**：
```swift
let scale = ble.iredDeviceData.scaleData
Text("Weight: \(String(format: "%.2f", scale.data.weight ?? 0.0)) kg")
Text("Status: \(scale.data.isFinalResult == true ? "Locked" : "Measuring...")")
if let w = scale.data.weight, scale.data.isFinalResult == true {
    Text("BMI: \(String(format: "%.1f", scale.data.toBMI(height: 175, weight: w)))")
    Text("Body Fat: \(String(format: "%.1f", scale.data.toBodyFat(height: 175, age: 25, gender: "male")))%")
}
Button("Pair") { ble.startPairing(to: .scale) }
Button("Connect") { ble.connect(from: .scale) }
```

---

### 3.5 🪢 智能跳绳 (`.jumpRope`)

- **访问路径**：`ble.iredDeviceData.jumpRopeData`
- **工作模式枚举 (`SetJumpRopeMode`)**：
  - `.free`：自由跳
  - `.time(second: Int)`：倒计时跳（秒）
  - `.count(count: Int)`：计数跳（目标次数）
- **控制指令**：
  - `ble.startJumpRopeRecording(mode, completion: { result in ... })`：下发模式，清空历史并启动每秒定时间隔快照记录
  - `ble.stopJumpRopeRecording()`：停止工作模式与定时器（**若心率带也处于测量中会自动联动停止**）
  - `ble.setJumpRopeMode(mode)` / `ble.stopJumpRopeMode()`：单纯下发模式不启动秒级采样
- **数据字段 (`JumpRopeModel`)**：
  - `mode: Int?`：模式：`0` = 自由跳, `1` = 计时跳, `2` = 计数跳
  - `modeString() -> String`：返回模式对应的字符串（`"Free"` / `"Time"` / `"Count"`，默认 `"Free"`）
  - `status: Int?`：当前状态（例如是否在跳跃中，可自定义）
  - `setting: Int?`：用户设置的参数（如目标时间/计数等）
  - `count: Int?`：当前已跳绳次数
  - `time: Int?`：当前已跳绳时间（单位：秒）
  - `batteryLevel: Int?`：电池电量等级（0 ~ 4）：
    - `4`: 电量 > 80%
    - `3`: 电量 > 50%
    - `2`: 电量 > 25%
    - `1`: 电量 > 10%
    - `0`: 电量 <= 10%
  - `batteryLevelDescription: String`：电量等级文字描述（如 `"电量充足（>80%）"`）
  - `countArray: [JumpRopeArrayModel]`：**每秒快照数组**（包含 `date: Date`, `count: Int`），用于绘制跳绳速率曲线
  - `recordTime: Int`：有效记录总秒数
- **SwiftUI 代码示例**：
```swift
let rope = ble.iredDeviceData.jumpRopeData.data
Text("Mode: \(rope.modeString()) | Count: \(rope.count ?? 0) | Time: \(rope.time ?? 0)s")
Text("Battery: \(rope.batteryLevelDescription)")
Button("Start Free Jump") { ble.startJumpRopeRecording(.free) { _ in } }
Button("Start 60s Jump") { ble.startJumpRopeRecording(.time(second: 60)) { _ in } }
Button("Start 100 Count Jump") { ble.startJumpRopeRecording(.count(count: 100)) { _ in } }
Button("Stop Jump") { ble.stopJumpRopeRecording() }
```

---

### 3.6 💓 心率带 (`.heartRateBelt`)

- **访问路径**：`ble.iredDeviceData.heartRateData`
- **控制指令**：`ble.startPairing(to: .heartRateBelt)`、`ble.connect(from: .heartRateBelt)`、`ble.disconnect(from: .heartRateBelt)`
- **数据字段 (`HeartRateBeltModel`)**：
  - `heartrate: Int?`：当前实时心率值 (BPM)
  - `batteryPercentage: Int?`：电量百分比 (0~100)
- **SwiftUI 代码示例**：
```swift
let hr = ble.iredDeviceData.heartRateData.data
Text("Heart Rate: \(hr.heartrate ?? 0) BPM | Battery: \(hr.batteryPercentage ?? 0)%")
Button("Pair") { ble.startPairing(to: .heartRateBelt) }
Button("Connect") { ble.connect(from: .heartRateBelt) }
Button("Disconnect") { ble.disconnect(from: .heartRateBelt) }
```
