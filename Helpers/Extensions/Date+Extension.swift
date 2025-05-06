import Foundation

extension Date {
    /// Converts the date to a string formatted as "yyyy-MM-dd_HH:mm:ss".
    ///
    /// - Returns: A string representing the date in "yyyy-MM-dd_HH:mm:ss" format.
    func toFormattedString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}
