# iREdFramework Configuration

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
