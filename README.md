## Package 安裝

你可以透過 Swift Package Manager 添加依賴：

```
https://github.com/iredchapman/iREdFramework.git
```
要在 Xcode 專案中新增套件依賴，請選擇 File > Add Package Dependency，並輸入此 URL。


------

## 權限配置

在使用藍牙設備前，需要在 Xcode 的 **Info.plist** 中添加藍牙權限描述，否則可能會導致應用無法正常掃描或連接設備。

### 操作步驟
1. 打開專案的TARGET>>Info。
2. 添加以下兩個權限鍵值：
   - `Privacy - Bluetooth Always Usage Description`
   - `Required background modes` [可選]
3. 在值中填寫用戶可見的提示文案，例如：
   - “需要使用藍牙來連接體溫計、血氧儀等設備”
   - “允許應用在後台允許，持續記錄藍牙數據”

### 範例截圖

<p align="center">
  <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_permissions.png?raw=true" width="500" alt="添加藍牙權限範例">
</p>

------

## 使用說明：iREdBluetooth 藍牙通信框架

在使用 `iREdBluetooth` 或任何模型如 `iRedDeviceData`、`HealthKitThermometerData` 等之前，**請務必在 Swift 文件頂部導入：**

```swift
import iREdFramework
```

------

## 1. 獲取藍牙數據實例

```swift
@StateObject var ble = iREdBluetooth.shared
```

透過 `ble.iredDeviceData` 可訪問所有支持的藍牙設備數據模型，例如：

- thermometerData（體溫計）
- oximeterData（血氧儀）
- sphygmometerData（血壓計）
- scaleData（體重秤）
- jumpRopeData（跳繩）
- heartRateData（心率帶）

每個設備數據模型都包含兩個部分：

- `state`：設備狀態（是否連接、是否測量中、是否測量完成等）
- `data`：設備業務數據（例如溫度、血氧、心率、重量等）

------

## 2. 藍牙掃描與連接

### 啟動配對

```swift
ble.startPairing(to: .thermometer) // 開始配對溫度計
```

**支持的設備類型**

`startPairing(to:)` 可用於以下設備：
- `.thermometer`（體溫計）
- `.oximeter`（血氧儀）
- `.sphygmometer`（血壓計）
- `.jumpRope`（跳繩）
- `.heartRateBelt`（心率帶）
- `.scale`（體重秤）

範例：

```swift
// 任選其一的設備類型開始配對
ble.startPairing(to: .oximeter)
ble.startPairing(to: .sphygmometer)
ble.startPairing(to: .jumpRope)
```

> 提示：框架會在成功配對設備後，自動將配對資訊持久化存儲到 UserDefaults，下次可透過 `connect(from:)` 自動連接上次配對的設備。

### 配對設置 RSSI 過濾

```swift
ble.setRSSI(limit: -60)
```

**RSSI 說明：**  
RSSI（Received Signal Strength Indicator，接收信號強度指示）是用來衡量藍牙信號強弱的數值，單位通常是 dBm。  
數值越接近 0，表示信號越強；數值越小（如 -90），表示信號越弱。  
例如設置 RSSI 限制為 -60，表示只會配對信號強於 -60 dBm 的設備，可以避免配對過遠或信號不穩定的設備。

### 停止配對

```swift
ble.stopPairing() // 停止配對
```

### 連接設備（自動查找上次配對設備）

```swift
ble.connect(from: .thermometer) // 連接溫度計
```

> 連接同樣支持以下設備類型：`.thermometer`、`.oximeter`、`.sphygmometer`、`.jumpRope`、`.heartRateBelt`、`.scale`。  
> 說明：`connect(from:)` 僅在**該設備類型已經完成配對並保存了配對記錄**時才會生效。

### 斷開設備

```swift
ble.disconnect(from: .thermometer) // 斷開連接溫度計
```

斷開支持所有上面列出的設備類型。



------

## 3. 讀取設備狀態與數據

### 體溫計數據（Thermometer）

```swift
let thermometer = ble.iredDeviceData.thermometerData
let temperature = thermometer.data.temperature // 溫度(℃)
let mode = thermometer.data.modeDescription // 模式("Adult Forehead"、"Child Forehead"、"Ear Canal"、"Object")
let battery = thermometer.data.battery // 電池電量
let isPaired = thermometer.state.isPaired // 是否已配對
let isPairing = thermometer.state.isPairing // 是否正在配對
let isConnected = thermometer.state.isConnected // 當前是否已連接
```
SwiftUI 監聽測量完成：當 `thermometer.state.isMeasurementCompleted` 變為 `true` 時（框架內部會在回調後短暫置為 true 再復位），可以在 `onChange` 中讀取溫度值並更新 UI。

### 血氧儀數據（Oximeter）

```swift
let oximeter = ble.iredDeviceData.oximeterData
let spo2 = oximeter.data.spo2 // 血氧
let pulse = oximeter.data.pulse // 脈搏
let pi = oximeter.data.pi // 灌注指數
let battery = oximeter.data.battery // 電池電量
let isPaired = oximeter.state.isPaired // 是否已配對
let isPairing = oximeter.state.isPairing // 是否正在配對
let isConnected = oximeter.state.isConnected // 當前是否已連接
```

### 血壓計數據（Sphygmometer）

```swift
let sphygmometer = ble.iredDeviceData.sphygmometerData
let pressure = sphygmometerData.data.pressure // 壓力
let systolic = sphygmometer.data.systolic // 收縮壓
let diastolic = sphygmometer.data.diastolic // 舒張壓
let pulse = sphygmometer.data.pulse // 脈搏
let isPaired = sphygmometer.state.isPaired // 是否已配對
let isPairing = sphygmometer.state.isPairing // 是否正在配對
let isConnected = sphygmometer.state.isConnected // 當前是否已連接
```
SwiftUI 監聽測量完成：當 `sphygmometer.state.isMeasurementCompleted` 變為 `true` 時（框架內部會在回調後短暫置為 true 再復位），可以在 `onChange` 中讀取數值並更新 UI。

### 體重秤數據（Scale）

```swift
let scale = ble.iredDeviceData.scaleData
let weight = scale.data.weight // 體重(kg)
let isFinalResult = scale.data.isFinalResult // 是否最終結果
let isPaired = scale.state.isPaired // 是否已配對
let isPairing = scale.state.isPairing // 是否正在配對
let isConnected = scale.state.isConnected // 當前是否已連接
```
SwiftUI 監聽測量完成：當 `sphygmometer.state.isMeasurementCompleted` 變為 `true` 時（框架內部會在回調後短暫置為 true 再復位），可以在 `onChange` 中讀取數值並更新 UI。

### 跳繩數據（Jump Rope）

```swift
let rope = ble.iredDeviceData.jumpRopeData
let count = rope.data.count // 跳繩次數
let time = rope.data.time // 跳繩時長(秒)
let mode = rope.data.mode // 跳繩模式(0 = 自由跳, 1 = 計時跳, 2 = 計數跳)
let battery = rope.data.batteryLevel // 電池電量（等級：4 >80%，3 >50%，2 >25%，1 >10%，0 ≤10%）
let isPaired = rope.state.isPaired // 是否已配對
let isPairing = rope.state.isPairing // 是否正在配對
let isConnected = rope.state.isConnected // 當前是否已連接
```

### 心率帶數據（Heart Rate Belt）

```swift
let heartRate = ble.iredDeviceData.heartRateData
let heartrate = heartRate.data.heartrate // 心率
let battery = heartRate.data.batteryPercentage // 電池電量
let isPaired = heartRate.state.isPaired // 是否已配對
let isPairing = heartRate.state.isPairing // 是否正在配對
let isConnected = heartRate.state.isConnected // 當前是否已連接
```

------

## 4. 開始與停止記錄

### 跳繩記錄
跳繩支持三種模式：自由跳、計時跳、計數跳。可以發送指令

```swift
ble.startJumpRopeRecording(.free) { result in
    switch result {
    case .success(): print("開始跳繩記錄")
    case .failure(let err): print(err.localizedDescription)
    }
} // 自由跳繩

ble.startJumpRopeRecording(.time(second: 10)) {...} // 設定跳繩時間10秒為目標
ble.startJumpRopeRecording(.count(count: 10)) {...} // 設定跳繩數量10個為目標

ble.stopJumpRopeRecording() // 停止跳繩記錄
```

------