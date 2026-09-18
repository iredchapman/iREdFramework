---
name: ired-framework
description: "Provides integration patterns, API specifications, and SwiftUI code snippets for iREdFramework. Use this skill when pairing, connecting, disconnecting, controlling, or collecting data from iRED Bluetooth health and sports devices: thermometer/體溫計, oximeter/血氧儀 (SpO2, pulse), sphygmometer/血壓計 (pressure, systolic, diastolic), scale/體重秤/體重磅 (weight, BMI), jump rope/跳繩 (count, time, modes), and heart rate belt/心率帶 (BPM). Guides reactive state management via iREdBluetooth.shared, data models, and SPM setup."
---

# iREdFramework

## 1. Integration Workflow

Follow these 5 steps to integrate the framework:

### Step 1: Add SPM Dependency
- **Package URL**: `https://github.com/iredchapman/iREdFramework.git`

### Step 2: Configure Bluetooth Permissions (Info.plist)

Add `Privacy - Bluetooth Always Usage Description` (`NSBluetoothAlwaysUsageDescription`) to `Info.plist` (configure via the target's **Info** tab; do not add a physical `Info.plist` to **Copy Bundle Resources** to prevent `Multiple commands produce` build conflicts).

### Step 3: Import Modules
Import the required modules at the top of your SwiftUI views or service files:
```swift
import SwiftUI
import Combine
import iREdFramework
```

### Step 4: Inject the Bluetooth Manager Singleton
Inject the global singleton manager into your SwiftUI View:
```swift
@StateObject private var ble = iREdBluetooth.shared
```

### Step 5: Device Control and Data Observation
- **Pairing**: `ble.startPairing(to: .<deviceType>)` (automatically persists UUID and stops scanning)
- **Stop Scanning**: `ble.stopPairing()`
- **Connect**: `ble.connect(from: .<deviceType>)` (reconnect to an already paired device)
- **Disconnect**: `ble.disconnect(from: .<deviceType>)` or `ble.disconnect(from: .all_ired_devices)`
- **Read State & Data**: Read state from `ble.iredDeviceData.<deviceType>Data.state` and telemetry from `.data`

---

## 2. Unified Device State Machine (`DeviceStatusModel`)

All peripherals observe device state via `ble.iredDeviceData.<deviceType>Data.state`:

| State Property | Type | Description |
| :--- | :--- | :--- |
| `isPairing` | `Bool` | Whether the device is scanning/pairing |
| `isPaired` | `Bool` | Whether pairing has succeeded (persisted locally) |
| `isConnecting` | `Bool` | Whether connection is in progress |
| `isConnected` | `Bool` | Whether the device is currently connected |
| `isConnectionFailure` | `Bool` | Whether the last connection attempt failed |
| `isDisconnected` | `Bool` | Whether the device is disconnected |
| `isMeasuring` | `Bool` | Whether measurement is in progress (e.g. cuff inflating, jumping) |
| `isMeasurementCompleted` | `Bool` | Whether measurement has completed |
| `isPauseMeasurement` | `Bool` | Whether measurement is paused |
| `isMeasurementError` | `MeasurementError?` | Measurement error details (`errorCode: Int`, `errorDescription: String`) |

---

## 3. Device Specifications and Data Models

### 3.1 🌡️ Thermometer (`.thermometer`)

- **Access Path**: `ble.iredDeviceData.thermometerData`
- **Control APIs**: `ble.startPairing(to: .thermometer)`, `ble.connect(from: .thermometer)`, `ble.disconnect(from: .thermometer)`
- **Data Fields (`HealthKitThermometerModel`)**:
  - `temperature: Double?`: Measured body temperature in °C
  - `modeCode: Int?` / `modeDescription: String?`: Measurement mode code and description. Possible values for `modeDescription`: `"Adult Forehead"`, `"Child Forehead"`, `"Ear Canal"`, `"Object"`
  - `battery: String?`: Battery percentage string (e.g., `"85%"`)
  - `peripheralName: String?` / `macAddress: String?`: Peripheral name and MAC address
  - `lastUpdatedTime: Date`: Timestamp of the last received update
- **Measurement Errors**: Inspect `state.isMeasurementError` for error code and description.
- **SwiftUI Example**:
```swift
Text("Status: \(ble.iredDeviceData.thermometerData.state.isConnected ? "Connected" : "Disconnected")")
Text("Temperature: \(String(format: "%.1f", ble.iredDeviceData.thermometerData.data.temperature ?? 0)) °C")
Text("Mode: \(ble.iredDeviceData.thermometerData.data.modeDescription ?? "-")")
Button("Pair") { ble.startPairing(to: .thermometer) }
Button("Connect") { ble.connect(from: .thermometer) }
Button("Disconnect") { ble.disconnect(from: .thermometer) }
```

---

### 3.2 🫁 Oximeter (`.oximeter`)

- **Access Path**: `ble.iredDeviceData.oximeterData`
- **Control APIs**: `ble.startPairing(to: .oximeter)`, `ble.connect(from: .oximeter)`, `ble.disconnect(from: .oximeter)`
- **Data Fields (`HealthKitOximeterModel`)**:
  - `spo2: Int?`: Real-time blood oxygen saturation level (%)
  - `pulse: Int?`: Real-time pulse rate (BPM)
  - `pi: Double?`: Perfusion Index (PI)
  - `battery: Int?`: Battery percentage (0 ~ 100)
- **SwiftUI Example**:
```swift
Text("SpO₂: \(ble.iredDeviceData.oximeterData.data.spo2 ?? 0)%")
Text("Pulse: \(ble.iredDeviceData.oximeterData.data.pulse ?? 0) BPM")
Text("PI: \(String(format: "%.1f", ble.iredDeviceData.oximeterData.data.pi ?? 0.0))")
Button("Pair") { ble.startPairing(to: .oximeter) }
Button("Connect") { ble.connect(from: .oximeter) }
Button("Disconnect") { ble.disconnect(from: .oximeter) }
```

---

### 3.3 🩺 Sphygmometer (`.sphygmometer`)

- **Access Path**: `ble.iredDeviceData.sphygmometerData`
- **Control APIs**: `ble.startPairing(to: .sphygmometer)`, `ble.connect(from: .sphygmometer)`, `ble.disconnect(from: .sphygmometer)`
- **Data Fields (`HealthKitSphygmometerModel`)**:
  - `pressure: Int?`: **Real-time cuff inflation pressure** (mmHg) (continuously updated while `state.isMeasuring == true`)
  - `pulseStatus: Int?`: Pulse heartbeat detection during measurement (`0` = no beat detected, `1` = heartbeat pulse detected; used for pulsing heart animation or beep)
  - `systolic: Int?`: **Systolic blood pressure (high)** (mmHg) (available upon completion)
  - `diastolic: Int?`: **Diastolic blood pressure (low)** (mmHg) (available upon completion)
  - `pulse: Int?`: **Final pulse rate** (BPM)
  - `irregularPulse: Int?`: **Irregular heartbeat flag** (`1` = irregular/arrhythmia, `0` = normal)
- **SwiftUI Example**:
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

### 3.4 ⚖️ Scale (`.scale`)

- **Access Path**: `ble.iredDeviceData.scaleData`
- **Control APIs**: `ble.startPairing(to: .scale)`, `ble.connect(from: .scale)`, `ble.disconnect(from: .scale)`
- **Data Fields (`HealthKitScaleModel`)**:
  - `weight: Double?`: Measured weight (kg)
  - `isFinalResult: Bool?`: Whether the reading has stabilized and locked (`true` = final locked value, `false` = stabilizing)
- **Body Metric Extensions**:
  - `data.toBMI(height: Int, weight: Double) -> Double`: Calculates BMI
  - `data.toBodyFat(height: Int, age: Int, gender: String) -> Double`: Estimates body fat percentage (%)
  - `data.healthStatus(height: Int) -> String`: Health status evaluation (`"Underweight"`, `"Normal"`, `"Overweight"`, `"Obese"`)
- **SwiftUI Example**:
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

### 3.5 🪢 Jump Rope (`.jumpRope`)

- **Access Path**: `ble.iredDeviceData.jumpRopeData`
- **Operating Modes (`SetJumpRopeMode`)**:
  - `.free`: Free jump
  - `.time(second: Int)`: Countdown jump (seconds)
  - `.count(count: Int)`: Target count jump (repetitions)
- **Control APIs**: `ble.startPairing(to: .jumpRope)`, `ble.connect(from: .jumpRope)`, `ble.disconnect(from: .jumpRope)`, `ble.setJumpRopeMode(mode)`, `ble.stopJumpRopeMode()`
- **Data Fields (`JumpRopeModel`)**:
  - `mode: Int?`: Mode code (`0` = Free, `1` = Time, `2` = Count)
  - `modeString() -> String`: Returns mode string (`"Free"`, `"Time"`, `"Count"`, default `"Free"`)
  - `status: Int?`: Current jumping status (e.g. active jump or customizable state)
  - `setting: Int?`: User-configured target parameter (target time or target count)
  - `count: Int?`: Current completed jump count
  - `time: Int?`: Current jumping elapsed time (in seconds)
  - `batteryLevel: Int?`: Battery level code (0 ~ 4):
    - `4`: Battery > 80%
    - `3`: Battery > 50%
    - `2`: Battery > 25%
    - `1`: Battery > 10%
    - `0`: Battery <= 10%
  - `batteryLevelDescription: String`: Battery level textual description
- **SwiftUI Example**:
```swift
let rope = ble.iredDeviceData.jumpRopeData.data
Text("Mode: \(rope.modeString()) | Count: \(rope.count ?? 0) | Time: \(rope.time ?? 0)s")
Text("Battery: \(rope.batteryLevelDescription)")
Button("Pair") { ble.startPairing(to: .jumpRope) }
Button("Connect") { ble.connect(from: .jumpRope) }
Button("Start Free Jump") { ble.setJumpRopeMode(.free) }
Button("Start 60s Jump") { ble.setJumpRopeMode(.time(second: 60)) }
Button("Start 100 Count Jump") { ble.setJumpRopeMode(.count(count: 100)) }
Button("Stop Jump") { ble.stopJumpRopeMode() }
```

---

### 3.6 💓 Heart Rate Belt (`.heartRateBelt`)

- **Access Path**: `ble.iredDeviceData.heartRateData`
- **Control APIs**: `ble.startPairing(to: .heartRateBelt)`, `ble.connect(from: .heartRateBelt)`, `ble.disconnect(from: .heartRateBelt)`
- **Data Fields (`HeartRateBeltModel`)**:
  - `heartrate: Int?`: Current real-time heart rate (BPM)
  - `batteryPercentage: Int?`: Battery percentage (0 ~ 100)
- **SwiftUI Example**:
```swift
let hr = ble.iredDeviceData.heartRateData.data
Text("Heart Rate: \(hr.heartrate ?? 0) BPM | Battery: \(hr.batteryPercentage ?? 0)%")
Button("Pair") { ble.startPairing(to: .heartRateBelt) }
Button("Connect") { ble.connect(from: .heartRateBelt) }
Button("Disconnect") { ble.disconnect(from: .heartRateBelt) }
```
