import Foundation

extension Double {
    /// Converts the double value to a string with a specified number of decimal places, rounding the value.
    ///
    /// - Parameter places: The number of decimal places to keep.
    /// - Returns: A string representation of the number formatted to the given decimal places.
    ///
    /// ## Example:
    /// ```swift
    /// let value: Double = 3.1415926
    /// print(value.toString(withDecimalPlaces: 2))  // Output: "3.14"
    /// print(value.toString(withDecimalPlaces: 4))  // Output: "3.1416"
    /// ```
    func toString(withDecimalPlaces places: Int) -> String {
        return String(format: "%.\(places)f", self)
    }
    
    /// Converts the double value to a specified number of decimal places without rounding.
    ///
    /// - Parameter places: The number of decimal places to keep.
    /// - Returns: A new `Double` value truncated to the given number of decimal places.
    ///
    /// If the truncation fails, the original value is returned.
    ///
    /// ## Example:
    /// ```swift
    /// let value: Double = 3.1415926
    /// print(value.toDouble(withDecimalPlaces: 2))  // Output: 3.14
    /// print(value.toDouble(withDecimalPlaces: 4))  // Output: 3.1415
    /// ```
    func toDouble(withDecimalPlaces places: Int) -> Double {
        return Double(String(format: "%.\(places)f", self)) ?? self
    }
}
