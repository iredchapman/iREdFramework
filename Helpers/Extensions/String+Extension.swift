import Foundation

extension String {
    /// Converts the string to a `Date` object.
    ///
    /// - Parameter format: The date format string, default is `"yyyy-MM-dd_HH:mm:ss"`.
    /// - Returns: A `Date` object if the conversion is successful, otherwise `nil`.
    func toDate(withFormat format: String = "yyyy-MM-dd_HH:mm:ss") -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.date(from: self) ?? Date()
    }
}
