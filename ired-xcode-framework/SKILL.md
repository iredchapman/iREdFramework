---
name: ired
description: Provides SwiftUI integration patterns and code snippets for the iREdFramework. Use this skill when the user wants to pair, connect, disconnect, or read data from iREd Bluetooth health devices (thermometer, oximeter, sphygmometer(blood pressure monitor)(BPM), scale, jump rope, heart rate belt). It includes UI state management using iREdBluetooth.shared and property extraction for device status, battery, and health metrics.
---

# iREdFramework

This framework simplifies Bluetooth connectivity for iREd health devices (Thermometers, Oximeters, etc.).

## Setup
**Important**: You must import the following packages in every view that uses the framework.
```swift
import SwiftUI
import Combine        // REQUIRED for ObservableObject
import iREdFramework  // The core framework

@StateObject var ble = iREdBluetooth.shared
```

## 1. Device Usage Examples

Copy these patterns to build your views.

### Thermometer

```swift
import SwiftUI
import Combine        // REQUIRED for ObservableObject
import iREdFramework  // The core framework

@StateObject var ble = iREdBluetooth.shared

Text(ble.iredDeviceData.thermometerData.state.isPairing ? "Pairing..." : 
     ble.iredDeviceData.thermometerData.state.isPaired ? "Paired" : "Unpaired")
    .foregroundColor(ble.iredDeviceData.thermometerData.state.isPairing ? .orange : 
                     ble.iredDeviceData.thermometerData.state.isPaired ? .blue : .gray)

Text(ble.iredDeviceData.thermometerData.state.isConnected ? "Connected" : "Disconnected")
    .foregroundColor(ble.iredDeviceData.thermometerData.state.isConnected ? .green : .red)

Button("Pair") { ble.startPairing(to: .thermometer) }
Button("Stop") { ble.stopPairing() }
Button("Connect") { ble.connect(from: .thermometer) }
Button("Disconnect") { ble.disconnect(from: .thermometer) }

if let temp = ble.iredDeviceData.thermometerData.data.temperature {
Text("\(String(format: "%.1f", temp))°C")
    .font(.system(size: 50))
} else {
Text("--.-°C")
    .font(.system(size: 50))
}

Text("Mode: \(ble.iredDeviceData.thermometerData.data.modeDescription ?? "-")")
Text("Mode Code: \(ble.iredDeviceData.thermometerData.data.modeCode ?? -1)")
Text("Battery: \(ble.iredDeviceData.thermometerData.data.battery ?? "-")")
Text("Name: \(ble.iredDeviceData.thermometerData.data.peripheralName ?? "-")")
Text("MAC: \(ble.iredDeviceData.thermometerData.data.macAddress ?? "-")")
Text("Last Updated: \(ble.iredDeviceData.thermometerData.data.lastUpdatedTime.description)")
```

### Oximeter

```swift
import SwiftUI
import Combine        // REQUIRED for ObservableObject
import iREdFramework  // The core framework

@StateObject var ble = iREdBluetooth.shared

Text(ble.iredDeviceData.oximeterData.state.isPairing ? "Pairing..." : 
       ble.iredDeviceData.oximeterData.state.isPaired ? "Paired" : "Unpaired")
Text(ble.iredDeviceData.oximeterData.state.isConnected ? "Connected" : "Disconnected")

Button("Pair") { ble.startPairing(to: .oximeter) }
Button("Stop") { ble.stopPairing() }
Button("Connect") { ble.connect(from: .oximeter) }
Button("Disconnect") { ble.disconnect(from: .oximeter) }

Text("SpO2")
Text("\(ble.iredDeviceData.oximeterData.data.spo2 ?? 0)%").font(.title)

Text("Pulse")
Text("\(ble.iredDeviceData.oximeterData.data.pulse ?? 0) BPM").font(.title)

Text("PI")
Text(String(format: "%.2f", ble.iredDeviceData.oximeterData.data.pi ?? 0.0))

Text("Avg SpO2: \(ble.iredDeviceData.oximeterData.data.averageSpo2())")
Text("Avg BPM: \(ble.iredDeviceData.oximeterData.data.averageBPM())")
Text("Avg PI: \(String(format: "%.2f", ble.iredDeviceData.oximeterData.data.averagePI()))")

Text("Battery: \(ble.iredDeviceData.oximeterData.data.battery ?? 0)%")
Text("Name: \(ble.iredDeviceData.oximeterData.data.peripheralName ?? "-")")
Text("MAC: \(ble.iredDeviceData.oximeterData.data.macAddress ?? "-")")
Text("Last Updated: \(ble.iredDeviceData.oximeterData.data.lastUpdatedTime.description)")


```

### Sphygmometer (Blood Pressure)

```swift
import SwiftUI
import Combine        // REQUIRED for ObservableObject
import iREdFramework  // The core framework

@StateObject var ble = iREdBluetooth.shared

Text(ble.iredDeviceData.sphygmometerData.state.isPairing ? "Pairing..." : 
         ble.iredDeviceData.sphygmometerData.state.isPaired ? "Paired" : "Unpaired")

Text(ble.iredDeviceData.sphygmometerData.state.isConnected ? "Connected" : "Disconnected")
    .foregroundColor(ble.iredDeviceData.sphygmometerData.state.isConnected ? .green : .red)

Button("Pair") { ble.startPairing(to: .sphygmometer) }
Button("Stop") { ble.stopPairing() }
Button("Connect") { ble.connect(from: .sphygmometer) }
Button("Disconnect") { ble.disconnect(from: .sphygmometer) }

if ble.iredDeviceData.sphygmometerData.state.isMeasuring {
    Text("Measuring: \(ble.iredDeviceData.sphygmometerData.data.pressure ?? 0) mmHg")
        .font(.title)
        .foregroundColor(.orange)
    Text("Pulse Status: \(ble.iredDeviceData.sphygmometerData.data.pulseStatus ?? 0)")
} else {
    Text("\(ble.iredDeviceData.sphygmometerData.data.systolic ?? 0)")
    Text("\(ble.iredDeviceData.sphygmometerData.data.diastolic ?? 0)")
    Text("\(ble.iredDeviceData.sphygmometerData.data.pulse ?? 0)")
}

Text("Irregular Pulse: \(ble.iredDeviceData.sphygmometerData.data.irregularPulse == 1 ? "Yes" : "No")")
Text("Name: \(ble.iredDeviceData.sphygmometerData.data.peripheralName ?? "-")")
Text("MAC: \(ble.iredDeviceData.sphygmometerData.data.macAddress ?? "-")")
Text("Last Updated: \(ble.iredDeviceData.sphygmometerData.data.lastUpdatedTime.description)")

```

### ⚖️ Scale

```swift
import SwiftUI
import Combine        // REQUIRED for ObservableObject
import iREdFramework  // The core framework

@StateObject var ble = iREdBluetooth.shared

Text(ble.iredDeviceData.scaleData.state.isPairing ? "Pairing..." : 
     ble.iredDeviceData.scaleData.state.isPaired ? "Paired" : "Unpaired")

Text(ble.iredDeviceData.scaleData.state.isConnected ? "Connected" : "Disconnected")

Button("Pair") { ble.startPairing(to: .scale) }
Button("Stop") { ble.stopPairing() }
Button("Connect") { ble.connect(from: .scale) }
Button("Disconnect") { ble.disconnect(from: .scale) }

Text("\(String(format: "%.2f", ble.iredDeviceData.scaleData.data.weight ?? 0.0)) kg")
    .font(.system(size: 50))

if ble.iredDeviceData.scaleData.data.isFinalResult == true {
    Text("Stable").foregroundColor(.green)
} else {
    Text("Measuring...").foregroundColor(.orange)
}

Text("Name: \(ble.iredDeviceData.scaleData.data.peripheralName ?? "-")")
Text("MAC: \(ble.iredDeviceData.scaleData.data.macAddress ?? "-")")
Text("Last Updated: \(ble.iredDeviceData.scaleData.data.lastUpdatedTime.description)")
```

### 🪢 Jump Rope
```swift
import SwiftUI
import Combine        // REQUIRED for ObservableObject
import iREdFramework  // The core framework

@StateObject var ble = iREdBluetooth.shared

Text(ble.iredDeviceData.jumpRopeData.state.isPairing ? "Pairing..." : 
     ble.iredDeviceData.jumpRopeData.state.isPaired ? "Paired" : "Unpaired")

Text(ble.iredDeviceData.jumpRopeData.state.isConnected ? "Connected" : "Disconnected")

Button("Pair") { ble.startPairing(to: .jumpRope) }
Button("Stop") { ble.stopPairing() }
Button("Connect") { ble.connect(from: .jumpRope) }
Button("Disconnect") { ble.disconnect(from: .jumpRope) }

Text("Count: \(ble.iredDeviceData.jumpRopeData.data.count ?? 0)")
Text("Time: \(ble.iredDeviceData.jumpRopeData.data.time ?? 0)")
Text("Setting: \(ble.iredDeviceData.jumpRopeData.data.setting ?? 0)")
Text("Status: \(ble.iredDeviceData.jumpRopeData.data.status.flatMap { [0: "Not Jumping", 1: "Jumping", 2: "Paused", 3: "Ended"][$0] } ?? "N/A")")

Text("Mode: \(ble.iredDeviceData.jumpRopeData.data.mode.flatMap { [0: "Free", 1: "Time", 2: "Count"][$0] } ?? "N/A")")
Text("Battery: \(ble.iredDeviceData.jumpRopeData.data.batteryLevel.map { ["≤10%", ">10%", ">25%", ">50%", ">80%"][$0 <= 4 && $0 >= 0 ? $0 : 0] } ?? "N/A")")

Button("Set Free Mode") { ble.setJumpRopeMode(.free) }
Button("Set Count Mode(30)") { ble.setJumpRopeMode(.count(count: 30)) }
Button("Set Time Mode(30)") { ble.setJumpRopeMode(.time(second: 30)) }

Text("Name: \(ble.iredDeviceData.jumpRopeData.data.peripheralName ?? "-")")
Text("MAC: \(ble.iredDeviceData.jumpRopeData.data.macAddress ?? "-")")
Text("Last Updated: \(ble.iredDeviceData.jumpRopeData.data.lastUpdatedTime.description)")
```

### 💓 Heart Rate Belt
```swift
import SwiftUI
import Combine        // REQUIRED for ObservableObject
import iREdFramework  // The core framework

@StateObject var ble = iREdBluetooth.shared

Text(ble.iredDeviceData.heartRateData.state.isPairing ? "Pairing..." : 
     ble.iredDeviceData.heartRateData.state.isPaired ? "Paired" : "Unpaired")

Text(ble.iredDeviceData.heartRateData.state.isConnected ? "Connected" : "Disconnected")

Button("Pair") { ble.startPairing(to: .heartRateBelt) }
Button("Stop") { ble.stopPairing() }
Button("Connect") { ble.connect(from: .heartRateBelt) }
Button("Disconnect") { ble.disconnect(from: .heartRateBelt) }

Text("\(ble.iredDeviceData.heartRateData.data.heartrate ?? 0) BPM")
Text("Battery: \(ble.iredDeviceData.heartRateData.data.batteryPercentage ?? 0)%")

Text("Name: \(ble.iredDeviceData.heartRateData.data.peripheralName ?? "-")")
Text("MAC: \(ble.iredDeviceData.heartRateData.data.macAddress ?? "-")")
Text("Last Updated: \(ble.iredDeviceData.heartRateData.data.lastUpdatedTime.description)")
```


### Swift / SwiftUI Code Formatting Rules
When generating Swift and SwiftUI code, you must output native, compilable code directly. Over-escaping special characters is strictly prohibited. Please strictly adhere to the following rules:

1. **No Escaping for Closure Arguments:** Shorthand arguments in Swift closures must be output exactly as `$0`, `$1`, etc. Never prepend a backslash to the dollar sign. Outputting `\$0` is strictly forbidden.
2. **String Interpolation Handling:** Inside Swift's string interpolation `\(...)`, use standard double quotes `"` normally. Do not escape them as `\"` unless it is genuinely required by native Swift syntax (e.g., deeply nested strings).
3. **Do Not Mix Syntax Rules:** Do not apply your underlying JSON (JavaScript Object Notation) or Markdown escaping logic inside Swift code blocks.

#### Example Comparison:
[Incorrect Output ❌] (Contains erroneous backslash escaping)
Text("Status: \(status.flatMap { [0: \"Not Jumping\", 1: \"Jumping\"][\$0] } ?? \"N/A\")")

[Correct Output ✅] (Clean, native Swift code)
Text("Status: \(status.flatMap { [0: "Not Jumping", 1: "Jumping"][$0] } ?? "N/A")")