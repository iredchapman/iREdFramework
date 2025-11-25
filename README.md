# iREdFramework README (English)

## Package Installation

Add the package through Swift Package Manager:

```
https://github.com/iredchapman/iREdFramework.git
```

In Xcode, choose **File > Add Package Dependency** and enter the URL above to bring the framework into your project.

---

## Permission Configuration

Before accessing Bluetooth peripherals, add the necessary privacy descriptions to your app’s **Info.plist**; otherwise scanning and pairing may fail.

**Steps**
1. Open your target’s **Info** tab.
2. Add the following keys:
   - `Privacy - Bluetooth Always Usage Description`
   - `Required background modes` (optional)
3. Provide user-facing description strings such as:
   - “Bluetooth access is required to connect thermometers, oximeters, etc.”
   - “Allow the app to keep recording Bluetooth data while running in the background.”

**Sample Screenshot**

<p align="center">
  <img src="https://github.com/iredchapman/iREdFramework/blob/main/images/add_permissions.png?raw=true" width="500" alt="Sample Bluetooth permission settings">
</p>

---

## Usage Guide: iREdBluetooth

Before working with `iREdBluetooth` or any provided models (e.g., `iRedDeviceData`, `HealthKitThermometerData`), import the framework at the top of your Swift file:

```swift
import iREdFramework
```

---

## 1. Getting Bluetooth Data Instances

```swift
@StateObject var ble = iREdBluetooth.shared
```

Access every supported device model through `ble.iredDeviceData`:

- `thermometerData`
- `oximeterData`
- `sphygmometerData`
- `scaleData`
- `jumpRopeData`
- `heartRateData`

Each model exposes two sections:
- `state`: connectivity and measurement state
- `data`: domain-specific values such as temperature, SpO₂, weight, etc.

---

## 2. Scanning and Connecting

### Start Pairing

```swift
ble.startPairing(to: .thermometer) // Start pairing thermometer
```

`startPairing(to:)` accepts any of:

- `.thermometer`
- `.oximeter`
- `.sphygmometer`
- `.jumpRope`
- `.heartRateBelt`
- `.scale`

Example:

```swift
ble.startPairing(to: .oximeter)
ble.startPairing(to: .sphygmometer)
ble.startPairing(to: .jumpRope)
```

After a successful pairing, the framework persists device info in `UserDefaults`, allowing you to reconnect automatically via `connect(from:)`.

### RSSI Filtering During Pairing

```swift
ble.setRSSI(limit: -60)
```

RSSI (Received Signal Strength Indicator) measures Bluetooth signal strength in dBm. Values closer to 0 indicate stronger signals. Setting the limit to -60 ensures that only peripherals with stronger signals than -60 dBm can pair, reducing unstable connections.

### Stop Pairing

```swift
ble.stopPairing()
```

### Connect to the Last Paired Device

```swift
ble.connect(from: .thermometer)
```

The same device categories listed above are supported. `connect(from:)` only works if that type has an existing pairing record.

### Disconnect

```swift
ble.disconnect(from: .thermometer)
```

`disconnect(from:)` works for every supported device type.

---

## 3. Reading Device States and Data

### Thermometer

```swift
let thermometer = ble.iredDeviceData.thermometerData

let peripheralName = thermometer.data.peripheralName // peripheral name
let macAddress = thermometer.data.macAddress // MAC address
let temperature = thermometer.data.temperature // Double? temperature (℃)
let mode = thermometer.data.modeDescription // String? mode ("Adult Forehead", "Child Forehead", "Ear Canal", "Object")
let battery = thermometer.data.battery // String? battery: full=0xA0, >=80%=0x80, >=50%=0x50, <=10%=0x10
let lastUpdatedTime = thermometer.data.lastUpdatedTime // Last update time of the data

let isPaired = thermometer.state.isPaired // paired status
let isPairing = thermometer.state.isPairing // currently pairing
let isConnected = thermometer.state.isConnected // currently connected
```

When `thermometer.state.isMeasurementCompleted` toggles to `true` (it resets shortly after), handle SwiftUI’s `onChange` to fetch the reading and update your UI.

### Oximeter

```swift
let oximeter = ble.iredDeviceData.oximeterData

let peripheralName = oximeter.data.peripheralName // peripheral name
let macAddress = oximeter.data.macAddress // MAC address
let spo2 = oximeter.data.spo2 // Int? blood oxygen (SpO₂)
let pulse = oximeter.data.pulse // Int? pulse rate
let pi = oximeter.data.pi // Double? perfusion index
let pi = oximeter.data.PlethysmographyArray // 
let battery = oximeter.data.battery // Int? battery level 0-100
let lastUpdatedTime = oximeter.data.lastUpdatedTime // Last update time of the data

let isPaired = oximeter.state.isPaired // paired status
let isPairing = oximeter.state.isPairing // currently pairing
let isConnected = oximeter.state.isConnected // currently connected
```

### Sphygmometer

```swift
let sphygmometer = ble.iredDeviceData.sphygmometerData

let peripheralName = sphygmometer.data.peripheralName // peripheral name
let macAddress = sphygmometer.data.macAddress // MAC address
let pressure = sphygmometer.data.pressure // Int? cuff pressure while measuring (mmHg)
let systolic = sphygmometer.data.systolic // Int? systolic pressure
let diastolic = sphygmometer.data.diastolic // Int? diastolic pressure
let pulse = sphygmometer.data.pulse // Int? pulse rate
let lastUpdatedTime = sphygmometer.data.lastUpdatedTime // Last update time of the data

let isPaired = sphygmometer.state.isPaired // paired status
let isPairing = sphygmometer.state.isPairing // currently pairing
let isConnected = sphygmometer.state.isConnected // currently connected
```

Monitor `sphygmometer.state.isMeasurementCompleted` to know when measurement results are available.

### Scale

```swift
let scale = ble.iredDeviceData.scaleData

let peripheralName = scale.data.peripheralName // peripheral name
let macAddress = scale.data.macAddress // MAC address
let weight = scale.data.weight // Double? weight (kg)
let isFinalResult = scale.data.isFinalResult // Bool? indicates whether this is the final reading
let bmi = scale.data.toBMI(height: Int, weight: Double) // Double BMI computed from height and weight
let body_fat = scale.data.toBodyFat(height: Int, age: Int, gender: String) // Double body fat result (gender: "male"/"female")
let lastUpdatedTime = scale.data.lastUpdatedTime // Last update time of the data

let isPaired = scale.state.isPaired // paired status
let isPairing = scale.state.isPairing // currently pairing
let isConnected = scale.state.isConnected // currently connected
```

Use SwiftUI’s `onChange` with `scale.state.isMeasurementCompleted` to capture final weight, BMI, and body fat readings.

### Jump Rope

```swift
let rope = ble.iredDeviceData.jumpRopeData

let peripheralName = rope.data.peripheralName // peripheral name
let macAddress = rope.data.macAddress // MAC address
let count = rope.data.count // Int? jump count
let time = rope.data.time // Int? jump duration (seconds)
let mode = rope.data.mode // Int? mode (0 free, 1 timed, 2 counted)
let battery = rope.data.batteryLevel // Int? battery level tier (4>80%, 3>50%, 2>25%, 1>10%, 0≤10%) convert to %
let setting = rope.data.setting // Int? user-configured parameters (target time/count, etc.)
let status = rope.data.status // Int? current status (e.g., actively jumping)
let lastUpdatedTime = rope.data.lastUpdatedTime // Last update time of the data

let isPaired = rope.state.isPaired // paired status
let isPairing = rope.state.isPairing // currently pairing
let isConnected = rope.state.isConnected // currently connected

// Jump rope supports free, timed, and counted modes; control recording via commands
ble.startJumpRopeRecording(.free) // Free mode

ble.startJumpRopeRecording(.time(second: 10)) // Set target time to 10 seconds
ble.startJumpRopeRecording(.count(count: 10)) // Set target count to 10 jumps

ble.stopJumpRopeMode() // Stop jump rope recording
```

### Heart Rate Belt

```swift
let heartRate = ble.iredDeviceData.heartRateData

let peripheralName = heartRate.data.peripheralName // peripheral name
let macAddress = heartRate.data.macAddress // MAC address
let heartrate = heartRate.data.heartrate // Int? heart rate (bpm)
let battery = heartRate.data.batteryPercentage // Int? battery level (%)
let lastUpdatedTime = heartRate.data.lastUpdatedTime // Last update time of the data

let isPaired = heartRate.state.isPaired // paired status
let isPairing = heartRate.state.isPairing // currently pairing
let isConnected = heartRate.state.isConnected // currently connected
```

---

