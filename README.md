## Package 安装

你可以通过 Swift Package Manager 添加依赖：

```
https://github.com/iredchapman/iREdFramework.git
```
<table align="center">
  <tr>
    <td align="center">
      <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_dependencies_step01.png?raw=true" width="300" alt="添加依赖步骤01"><br/>
      <sub>步骤 01：打开 Xcode 的 Package 依赖管理</sub>
    </td>
    <td align="center">
      <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_dependencies_step02.png?raw=true" width="300" alt="添加依赖步骤02"><br/>
      <sub>步骤 02：输入仓库地址</sub>
    </td>
    <td align="center">
      <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_dependencies_step03.png?raw=true" width="300" alt="添加依赖步骤03"><br/>
      <sub>步骤 03：选择分支/版本</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_dependencies_step04.png?raw=true" width="300" alt="添加依赖步骤04"><br/>
      <sub>步骤 04：选择要添加的 Package</sub>
    </td>
    <td align="center">
      <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_dependencies_step05.png?raw=true" width="300" alt="添加依赖步骤05"><br/>
      <sub>步骤 05：勾选 iREdFramework</sub>
    </td>
    <td align="center">
      <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_dependencies_step06.png?raw=true" width="300" alt="添加依赖步骤06"><br/>
      <sub>步骤 06：完成添加</sub>
    </td>
  </tr>
</table>

------

## 权限配置

在使用蓝牙设备前，需要在 Xcode 的 **Info.plist** 中添加蓝牙权限描述，否则可能会导致应用无法正常扫描或连接设备。

### 操作步骤
1. 打开项目的 `Info.plist` 文件。
2. 添加以下两个权限键值：
   - `Privacy - Bluetooth Always Usage Description`
   - `Required background modes` [可选]
3. 在值中填写用户可见的提示文案，例如：
   - “需要使用蓝牙来连接体温计、血氧仪等设备”
   - “允许应用在后台允许，持续记录蓝牙数据”

### 示例截图

<p align="center">
  <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_permissions.png?raw=true" width="500" alt="添加蓝牙权限示例">
</p>

------

## 使用说明：iREdBluetooth 蓝牙通信框架

在使用 `iREdBluetooth` 或任何模型如 `iRedDeviceData`、`HealthKitThermometerData` 等之前，**请务必在 Swift 文件顶部导入：**

```swift
import iREdFramework
```

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

**支持的设备类型**

`startPairing(to:)` 可用于以下设备：
- `.thermometer`（体温计）
- `.oximeter`（血氧仪）
- `.sphygmometer`（血压计）
- `.jumpRope`（跳绳）
- `.heartRateBelt`（心率带）
- `.scale`（体重秤）

示例：

```swift
// 任选其一的设备类型开始配对
ble.startPairing(to: .oximeter)
ble.startPairing(to: .sphygmometer)
ble.startPairing(to: .jumpRope)
```

> 提示：框架会在成功配对设备后，自动将配对信息持久化存储到 UserDefaults，下次可通过 `connect(from:)` 自动连接上次配对的设备。

### 停止配对

```swift
ble.stopPairing() // 停止配对
```

### 连接设备（自动查找上次配对设备）

```swift
ble.connect(from: .thermometer) // 连接温度计
```

> 连接同样支持以下设备类型：`.thermometer`、`.oximeter`、`.sphygmometer`、`.jumpRope`、`.heartRateBelt`、`.scale`。  
> 说明：`connect(from:)` 仅在**该设备类型已经完成配对并保存了配对记录**时才会生效。

### 断开设备

```swift
ble.disconnect(from: .thermometer) // 断开连接温度计
```

断开支持所有上面列出的设备类型。

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
let temperature = thermometer.data.temperature // 温度(℃)
let mode = thermometer.data.modeDescription // 模式("Adult Forehead"、"Child Forehead"、"Ear Canal"、"Object")
let battery = thermometer.data.battery // 电池电量
let isPaired = thermometer.state.isPaired // 是否已配对
let isPairing = thermometer.state.isPairing // 是否正在配对
let isConnected = thermometer.state.isConnected // 当前是否已连接
let isDisconnected = thermometer.state.isDisconnected // 是否已断开
```
SwiftUI 监听测量完成：当 `thermometer.state.isMeasurementCompleted` 变为 `true` 时（框架内部会在回调后短暂置为 true 再复位），可以在 `onChange` 中读取温度值并更新 UI。

### 血氧仪数据（Oximeter）

```swift
let oximeter = ble.iredDeviceData.oximeterData
let spo2 = oximeter.data.spo2 // 血氧
let pulse = oximeter.data.pulse // 脉搏
let pi = oximeter.data.pi // 灌注指数
let battery = oximeter.data.battery // 电池电量
let isPaired = oximeter.state.isPaired // 是否已配对
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
let isPaired = sphygmometer.state.isPaired // 是否已配对
let isPairing = sphygmometer.state.isPairing // 是否正在配对
let isConnected = sphygmometer.state.isConnected // 当前是否已连接
let isDisconnected = sphygmometer.state.isDisconnected // 是否已断开
```

### 体重秤数据（Scale）

```swift
let scale = ble.iredDeviceData.scaleData
let weight = scale.data.weight // 体重(kg)
let isFinalResult = scale.data.isFinalResult // 是否最终结果
let isPaired = scale.state.isPaired // 是否已配对
let isPairing = scale.state.isPairing // 是否正在配对
let isConnected = scale.state.isConnected // 当前是否已连接
let isDisconnected = scale.state.isDisconnected // 是否已断开
```

### 跳绳数据（Jump Rope）

```swift
let rope = ble.iredDeviceData.jumpRopeData
let count = rope.data.count // 跳绳次数
let time = rope.data.time // 跳绳时长(秒)
let mode = rope.data.mode // 跳绳模式(0 = 自由跳, 1 = 计时跳, 2 = 计数跳)
let battery = rope.data.batteryLevel // 电池电量（等级：4 >80%，3 >50%，2 >25%，1 >10%，0 ≤10%）
let isPaired = rope.state.isPaired // 是否已配对
let isPairing = rope.state.isPairing // 是否正在配对
let isConnected = rope.state.isConnected // 当前是否已连接
let isDisconnected = rope.state.isDisconnected // 是否已断开
```

### 心率带数据（Heart Rate Belt）

```swift
let heartRate = ble.iredDeviceData.heartRateData
let heartrate = heartRate.data.heartrate // 心率
let battery = heartRate.data.batteryPercentage // 电池电量
let isPaired = heartRate.state.isPaired // 是否已配对
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

ble.stopJumpRopeRecording() // 停止跳绳记录
```

------