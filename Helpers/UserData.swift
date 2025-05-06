import Foundation
import SwiftUI
import LocalAuthentication

enum Screen: Hashable {
    case startView, loginView, registerView, menuView, scaleView, dashboardView, historyView
    // SportKit
    case homeView, pairDeviceView, chatBotView, jumpRopeView, heartRateView, improveUsernameInfoView
    // HealthKit
    case thermometerView, oximeterView, sphygmometerView
}

enum Gender: String, CaseIterable {
    case male = "Male"
    case famale = "Famale"
}

class UserData: ObservableObject {
    static let shared = UserData()
    var loadingAlert: UIAlertController? = nil
    // Screen
    @Published var path = NavigationPath()
    // Login/Register
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var secondPassword: String = ""
    let defaultUsername = "username"
    let defaultPassword = "123456"
    // User
    @Published var current_username: String = "UNKNOWN NAME"
    @Published var age: String = "0"
    @Published var height: String = "0"
    @Published var weight: String = "0"
    @Published var gender: Gender = .famale
    // Data
    @MainActor @Published private(set) var isLoadingThermometerData: Bool = false
    @MainActor @Published private(set) var isLoadingOximeterData: Bool = false
    @MainActor @Published private(set) var isLoadingSphygmometerData: Bool = false
    @MainActor @Published private(set) var isLoadingScaleData: Bool = false
    @Published var thermometerData: [ThermometerModel] = []
    @Published var oximeterData: [OximeterModel] = []
    @Published var sphygmometerData: [SphygmometerModel] = []
    @Published var scaleData: [ScaleModel] = []
    // HTTP
    private var googleAppScriptURL: String = "https://script.google.com/macros/s/AKfycbxtpD7CtYSru8QUm3p006zSlWRR4L5VoXXAXzjfvpcBocKN5W141jQgCsE7jQFG9pLnKg/exec"
    private var googleSheetId: String = "1kc0WYQubSVYibpxxZDO6dC_1_ZbsdicKF4pnOI3bdeA"
    
    
    // SportKit
    private let userDefaultsKey = "users"
    @Published var users: [User] = []
    @Published var user: User = .empty
    @Published var current_user: User? = nil
    // Data
    @Published var ropeData: [Rope] = []
    @Published var heartRateData: [HeartRate] = []
    // AI
    @Published var ipt: String = ""
    @Published var isSending: Bool = false
    @Published var dialogueList: [DialogueModel] = []
    private var openRouterKEY = "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"
    private var openRouterModel = "meta-llama/llama-3.3-70b-instruct:free"
    
    init() {
        // set Default account
        UserDefaults.standard.set(defaultUsername, forKey: "default_username")
        UserDefaults.standard.set(defaultPassword, forKey: "default_password")
        
        loadBodyInfo()
    }
    
    public func initSportKit(openRouterKEY: String, openRouterModel: String, googleAppScriptId: String, googleSheetId: String) {
        self.openRouterKEY = openRouterKEY
        self.openRouterModel = openRouterModel
        self.googleAppScriptURL = "https://script.google.com/macros/s/\(googleAppScriptId)/exec"
        self.googleSheetId = "https://script.google.com/macros/s/\(googleSheetId)/exec"
    }
}
// Screen
extension UserData {
    /// Push a new screen onto the navigation stack
    /// - Parameter screen: The destination screen to navigate to
    func changeScreen(to screen: Screen) {
        path.append(screen)
    }
    
    /// Pop the last screen from the navigation stack
    /// - Removes the most recent view in the navigation path, simulating a back action
    func backScreen() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    /// Reset the entire navigation stack
    /// - Clears all views in the navigation path, returning to the root view
    func resetScreen() {
        path.removeLast(path.count)
    }
}

// Login/Register
extension UserData {
    /// Logs in the user by verifying stored credentials in `UserDefaults`
    /// - Parameter completion: Closure returning `true` if login is successful, otherwise `false`
    func login(completion: @escaping (Bool) -> Void) {
        let temp_username = UserDefaults.standard.string(forKey: "username")?.lowercased()
        let temp_password = UserDefaults.standard.string(forKey: "password")?.lowercased()
        let temp_default_username = UserDefaults.standard.string(forKey: "default_username")?.lowercased()
        let temp_default_password = UserDefaults.standard.string(forKey: "default_password")?.lowercased()
        if (temp_username == username.lowercased() && temp_password == password.lowercased()) || (temp_default_username == username.lowercased() && temp_default_password == password.lowercased()) {
            current_username = username
            changeScreen(to: .menuView)
            completion(true)
        } else {
            completion(false)
        }
        username = ""
        password = ""
    }
    
    /// Registers a new user by storing credentials in `UserDefaults`
    /// - Returns: An `Alert` indicating success or failure
    func register() -> (title: String, message: String) {
        if username.isEmpty || password.isEmpty || secondPassword.isEmpty {
            //            return Alert(title: Text("Error"), message: Text("The registration information cannot be empty."))
            return ("Error", "The registration information cannot be empty.")
        } else if password.count < 6 || secondPassword.count < 6 {
            //            return Alert(title: Text("Error"), message: Text("The password contains a maximum of 6 characters."))
            return ("Error", "The password contains a maximum of 6 characters.")
        } else if password != secondPassword {
            //            return Alert(title: Text("Error"), message: Text("The two passwords are different."))
            return ("Error", "The two passwords are different.")
            
        } else {
            UserDefaults.standard.set(username, forKey: "username")
            UserDefaults.standard.set(password, forKey: "password")
            username = ""
            password = ""
            changeScreen(to: .loginView)
            //            return Alert(title: Text("Success"), message: Text("Registered successfully."))
            return ("Success", "Registered successfully.")
        }
    }
    
    /// Attempts to log in the user using Face ID or Touch ID
    /// - Parameters:
    ///   - noHaveAccount: Closure executed if no account is found in `UserDefaults`
    ///   - faceidError: Closure executed if Face ID authentication fails
    ///   - faceidFailed: Closure executed if the device does not support Face ID authentication
    func faceidLogin(noHaveAccount: @escaping () -> (), faceidError: @escaping () -> (), faceidFailed: @escaping () -> ()) {
        let context = LAContext()
        var error: NSError?
        
        // Check if device supports Face ID
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Please authenticate to log in.") {
                success, _ in
                DispatchQueue.main.async {
                    // Check whether Face ID passes
                    if success {
                        let temp_username = UserDefaults.standard.string(forKey: "username")
                        let temp_password = UserDefaults.standard.string(forKey: "password")
                        // Check for an account
                        if let temp_username, let _ = temp_password {
                            self.current_username = temp_username
                            self.changeScreen(to: .menuView)
                        } else {
                            noHaveAccount()
                        }
                    } else {
                        faceidError()
                    }
                }
            }
        } else {
            faceidFailed()
        }
    }
}


// HTTP Request
extension UserData {
    /// Sends an HTTP GET request to the specified URL with the given query parameters.
    ///
    /// - Parameters:
    ///   - url: The endpoint URL as a `String`.
    ///   - data: A dictionary of key-value pairs to be appended as query parameters.
    ///   - completion: A closure that returns a `Result` type containing either a JSON dictionary (`[String: Any]?`) on success or an `Error` on failure.
    ///
    /// - Note: This function executes on the main thread but performs the network request asynchronously.
    /// - Warning: Ensure the `url` is properly encoded and valid; otherwise, the request will fail.
    /// - Example:
    /// ```
    /// let url = "https://api.example.com/data"
    /// let params: [String: Any] = ["user": "john_doe", "age": 25]
    ///
    /// httpRequest(url: url, data: params) { result in
    ///     switch result {
    ///     case .success(let response):
    ///         print("Response:", response ?? [:])
    ///     case .failure(let error):
    ///         print("Error:", error.localizedDescription)
    ///     }
    /// }
    /// ```
    func httpRequest(url: String, data: [String: Any], completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
        DispatchQueue.main.async {
            guard var components = URLComponents(string: url) else {
                completion(.failure(URLError(.badURL)))
                return
            }
            
            // 将数据转换为 URL 查询项
            let queryItems = data.map { key, value in
                URLQueryItem(name: key, value: String(describing: value))
            }
            components.queryItems = queryItems
            
            guard let finalURL = components.url else {
                completion(.failure(URLError(.badURL)))
                return
            }
            
            var request = URLRequest(url: finalURL, timeoutInterval: 15)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                
                do {
                    // 解析 JSON
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    debugPrint("HTTP Request result:", json ?? [:], "request URL: ", finalURL)
                    completion(.success(json ?? [:]))
                } catch {
                    // 解析错误
                    completion(.failure(error))
                }
            }
            task.resume()
        }
    }
    
    /// Fetches thermometer data from the server and updates the thermometer data array.
    /// - Note: This function uses an asynchronous HTTP request to fetch data.
    ///         The data is expected to be a JSON response containing an array of thermometer records.
    /// - Example:
    /// ```
    /// shared.fetchThermometerData()
    /// ```
    func fetchThermometerData() {
        DispatchQueue.main.async {
            self.isLoadingThermometerData = true
        }
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "thermometer",
            "user": current_username
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            DispatchQueue.main.async {
                self.isLoadingThermometerData = false
            }
            switch res {
            case .success(let result):
                /// - Sample data format:
                /// ```
                /// {
                ///     "code": 200,
                ///     "message": "Data fetched successfully",
                ///     "data": [
                ///         {
                ///             "datetime": "2025-02-22_11:33:11",
                ///             "mode": "Child Forehead",
                ///             "temperature": 36.5,
                ///             "user": "test"
                ///         }
                ///     ]
                /// }
                /// ```
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    if let data = result["data"] as? [[String: Any]] {
                        var temp_thermometerData: [ThermometerModel] = []
                        data.forEach { item in
                            if let datetime = item["datetime"] as? String,
                               let mode = item["mode"] as? String,
                               let temperature = item["temperature"] as? Double,
                               let user = item["user"] as? String {
                                temp_thermometerData.append(ThermometerModel(temperature: temperature, mode: mode, datetime: datetime, user: user))
                            }
                        }
                        DispatchQueue.main.async {
                            self.thermometerData = temp_thermometerData
                        }
                    }
                }
            case .failure(_):
                return
            }
        }
    }
    
    /// Fetches oximeter data from the server and updates the oximeter data array.
    /// - Note: This function uses an asynchronous HTTP request to fetch data.
    ///         The data is expected to be a JSON response containing an array of oximeter records.
    /// - Example:
    /// ```
    /// shared.fetchOximeterData()
    /// ```
    func fetchOximeterData() {
        DispatchQueue.main.async {
            self.isLoadingOximeterData = true
        }
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "oximeter",
            "user": current_username
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            DispatchQueue.main.sync {
                self.isLoadingOximeterData = false
            }
            switch res {
            case .success(let result):
                /// - Sample data format:
                /// ```
                /// {
                ///     "code": 200,
                ///     "message": "Data fetched successfully",
                ///     "data": [
                ///         {
                ///             "datetime": "2025-02-22_11:33:22",
                ///             "spo2": 97,
                ///             "bpm": 63,
                ///             "pi": 1.4,
                ///             "user": "test"
                ///         }
                ///     ]
                /// }
                /// ```
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    if let data = result["data"] as? [[String: Any]] {
                        var temp_oximeterData: [OximeterModel] = []
                        data.forEach { item in
                            if let datetime = item["datetime"] as? String,
                               let spo2 = item["spo2"] as? Int,
                               let bpm = item["bpm"] as? Int,
                               let pi = item["pi"] as? Double,
                               let user = item["user"] as? String {
                                temp_oximeterData.append(OximeterModel(spo2: spo2, bpm: bpm, pi: pi, datetime: datetime, user: user))
                            }
                        }
                        DispatchQueue.main.async {
                            self.oximeterData = temp_oximeterData
                        }
                    }
                }
            case .failure(_):
                return
            }
        }
    }
    
    /// Fetches sphygmometer data from the server and updates the sphygmometer data array.
    /// - Note: This function uses an asynchronous HTTP request to fetch data.
    ///         The data is expected to be a JSON response containing an array of sphygmometer records.
    /// - Example:
    /// ```
    /// shared.fetchSphygmometerData()
    /// ```
    func fetchSphygmometerData() {
        DispatchQueue.main.async {
            self.isLoadingSphygmometerData = true
        }
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "sphygmometer",
            "user": current_username
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            DispatchQueue.main.async {
                self.isLoadingSphygmometerData = false
            }
            switch res {
            case .success(let result):
                /// - Sample data format:
                /// ```
                /// {
                ///     "code": 200,
                ///     "message": "Data fetched successfully",
                ///     "data": [
                ///         {
                ///             "datetime": "2025-02-22_11:33:23",
                ///             "diastolic": 76,
                ///             "systolic": 115,
                ///             "pulse": 68,
                ///             "user": "test"
                ///         }
                ///     ]
                /// }
                /// ```
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    if let data = result["data"] as? [[String: Any]] {
                        var temp_sphygmometerData: [SphygmometerModel] = []
                        data.forEach { item in
                            if let datetime = item["datetime"] as? String,
                               let systolic = item["systolic"] as? Int,
                               let diastolic = item["diastolic"] as? Int,
                               let pulse = item["pulse"] as? Int,
                               let user = item["user"] as? String {
                                temp_sphygmometerData.append(SphygmometerModel(diastolic: diastolic, systolic: systolic, pulse: pulse, datetime: datetime, user: user))
                            }
                        }
                        DispatchQueue.main.async {
                            self.sphygmometerData = temp_sphygmometerData
                        }
                    }
                }
            case .failure(_):
                return
            }
        }
    }
    
    /// Fetches scale data from the server and updates the scale data array.
    /// - Note: This function uses an asynchronous HTTP request to fetch data.
    ///         The data is expected to be a JSON response containing an array of scale records.
    /// - Example:
    /// ```
    /// shared.fetchScaleData()
    /// ```
    func fetchScaleData() {
        DispatchQueue.main.async {
            self.isLoadingScaleData = true
        }
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "scale",
            "user": current_username
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            DispatchQueue.main.async {
                self.isLoadingScaleData = false
            }
            switch res {
            case .success(let result):
                /// - Sample data format:
                /// ```
                /// {
                ///     "code": 200,
                ///     "message": "Data fetched successfully",
                ///     "data": [
                ///         {
                ///             "datetime": "2025-02-22_11:23:22",
                ///             "weight": 59.2,
                ///             "bmi": 20.5,
                ///             "bodyfat": 12.7,
                ///             "user": "test"
                ///         }
                ///     ]
                /// }
                /// ```
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    if let data = result["data"] as? [[String: Any]] {
                        var temp_scaleData: [ScaleModel] = []
                        data.forEach { item in
                            if let datetime = item["datetime"] as? String,
                               let weight = item["weight"] as? Double,
                               let bmi = item["bmi"] as? Double,
                               let bodyfat = item["bodyfat"] as? Double,
                               let user = item["user"] as? String {
                                temp_scaleData.append(ScaleModel(weight: weight, bodyfat: bodyfat, bmi: bmi, datetime: datetime, user: user))
                            }
                        }
                        DispatchQueue.main.async {
                            self.scaleData = temp_scaleData
                        }
                    }
                }
            case .failure(_):
                return
            }
        }
    }
    
    /// Saves thermometer measurement data to the server.
    /// - Parameters:
    ///   - temperature: The measured body temperature.
    ///   - mode: The measurement mode (e.g., Adult Forehead, Child Forehead, Ear Canal, Object).
    ///   - completion: A completion handler that returns a success message or an error.
    /// - Note: The data is stored in the "thermometer" sheet.
    /// - Example:
    /// ```
    /// shared.saveThermometerData(temperature: 36.5, mode: "forehead") { result in
    ///     switch result {
    ///     case .success(let message):
    ///         print(message)
    ///     case .failure(let error):
    ///         print(error.localizedDescription)
    ///     }
    /// }
    /// ```
    func saveThermometerData(temperature: Double, mode: String, completion: @escaping (Result<String, Error>) -> Void) {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "thermometer",
            "user": current_username,
            "datetime": Date().toFormattedString(),
            "mode": mode,
            "temperature": temperature
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    completion(.success("The measurement data of the thermometer is saved successfully."))
                }
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /// Saves oximeter measurement data to the server.
    /// - Parameters:
    ///   - spo2: The measured blood oxygen saturation level.
    ///   - bpm: The measured pulse rate.
    ///   - pi: The perfusion index value.
    ///   - completion: A completion handler that returns a success message or an error.
    /// - Note: The data is stored in the "oximeter" sheet.
    /// - Example:
    /// ```
    /// shared.saveOximeterData(spo2: 98, bpm: 72, pi: 2.5) { result in
    ///     switch result {
    ///     case .success(let message):
    ///         print(message)
    ///     case .failure(let error):
    ///         print(error.localizedDescription)
    ///     }
    /// }
    /// ```
    func saveOximeterData(spo2: Int, bpm: Int, pi: Double, completion: @escaping (Result<String, Error>) -> Void) {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "oximeter",
            "user": current_username,
            "datetime": Date().toFormattedString(),
            "spo2": spo2,
            "bpm": bpm,
            "pi": pi
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    completion(.success("The blood oxygen measurement data was saved successfully."))
                }
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    /// Saves blood pressure measurement data to the server.
    /// - Parameters:
    ///   - diastolic: The diastolic blood pressure value.
    ///   - systolic: The systolic blood pressure value.
    ///   - pulse: The measured pulse rate.
    ///   - completion: A completion handler that returns a success message or an error.
    /// - Note: The data is stored in the "sphygmometer" sheet.
    /// - Example:
    /// ```
    /// shared.saveSphygmometerData(diastolic: 80, systolic: 120, pulse: 75) { result in
    ///     switch result {
    ///     case .success(let message):
    ///         print(message)
    ///     case .failure(let error):
    ///         print(error.localizedDescription)
    ///     }
    /// }
    /// ```
    func saveSphygmometerData(diastolic: Int, systolic: Int, pulse: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "sphygmometer",
            "user": current_username,
            "datetime": Date().toFormattedString(),
            "diastolic": diastolic,
            "systolic": systolic,
            "pulse": pulse
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    completion(.success("The blood pressure measurement data was saved successfully."))
                }
            case .failure(let failure):
                completion(.failure(failure))
            }
            
        }
    }
    
    /// Saves weight scale measurement data to the server.
    /// - Parameters:
    ///   - weight: The measured body weight.
    ///   - bmi: The calculated body mass index (BMI).
    ///   - bodyfat: The measured body fat percentage.
    ///   - completion: A completion handler that returns a success message or an error.
    /// - Note: The data is stored in the "scale" sheet.
    /// - Example:
    /// ```
    /// shared.saveScaleData(weight: 70.5, bmi: 22.3, bodyfat: 15.0) { result in
    ///     switch result {
    ///     case .success(let message):
    ///         print(message)
    ///     case .failure(let error):
    ///         print(error.localizedDescription)
    ///     }
    /// }
    /// ```
    func saveScaleData(weight: Double, bmi: Double, bodyfat: Double, completion: @escaping (Result<String, Error>) -> Void) {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "scale",
            "user": current_username,
            "datetime": Date().toFormattedString(),
            "weight": weight,
            "bmi": bmi,
            "bodyfat": bodyfat.toDouble(withDecimalPlaces: 1)
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    completion(.success("The weight scale measurement data is saved successfully."))
                }
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
}

// User
extension UserData {
    /// Loads the user's body information from `UserDefaults` and updates the corresponding properties.
    /// - Note: If the values are not found in `UserDefaults`, default values of `"0"` are assigned.
    /// - Example:
    /// ```
    /// shared.loadBodyInfo()
    /// ```
    func loadBodyInfo() {
        self.age = UserDefaults.standard.string(forKey: "age") ?? "12"
        self.height = UserDefaults.standard.string(forKey: "height") ?? "140"
        self.weight = UserDefaults.standard.string(forKey: "weight") ?? "60"
        if let gender = UserDefaults.standard.string(forKey: "gender") {
            if gender.lowercased() == "Male" {
                self.gender = .male
            } else {
                self.gender = .famale
            }
        }
    }
    
    /// Saves the user's body information to UserDefaults.
    /// - Parameters:
    ///   - age: User's age as a string.
    ///   - height: User's height as a string.
    ///   - weight: User's weight as a string.
    ///   - gender: User's gender as a `Gender` enum.
    func saveUserBodyInfo() {
        UserDefaults.standard.set(age, forKey: "age")
        UserDefaults.standard.set(height, forKey: "height")
        UserDefaults.standard.set(weight, forKey: "weight")
        UserDefaults.standard.set(gender.rawValue, forKey: "gender")
    }
}


// MARK: - SportKit

// MARK: User
extension UserData {
    // Load users from UserDefaults
    func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedUsers = try? JSONDecoder().decode([User].self, from: data) {
            self.users = savedUsers
            print("users:", savedUsers)
        }
    }
    
    // Save users to UserDefaults
    func saveUsers() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    // Get user by username
    func getUser(by username: String) -> User? {
        return users.first { $0.username == username }
    }
    
    // Add user
    func addUser(_ user: User) -> Bool {
        // Check if the user already exists
        if !users.contains(where: { $0.username == user.username }) {
            current_user = user
            users.append(user)
            saveUsers() // Save to UserDefaults
            return true
        }
        return false
    }
    
    // Delete user by username
    func deleteUser(by username: String) {
        if let index = users.firstIndex(where: { $0.username == username }) {
            users.remove(at: index)
            saveUsers() // Save to UserDefaults
        }
    }
    
    // 覆盖更新整个用户信息
    func updateUser(_ updatedUser: User) {
        if let index = users.firstIndex(where: { $0.username == updatedUser.username }) {
            users[index] = updatedUser
            saveUsers() // 保存到 UserDefaults
        }
    }
}

// MARK: - Login / Register
extension UserData {
    func loginByFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Please authenticate to log in") {
                //
                success, authenticationError in
                Task { @MainActor in
                    if success {
                        print("FaceID Success")
                        if !self.users.isEmpty {
                            self.current_user = self.users.last
                            // Login current user
                            self.changeScreen(to: .homeView)
                            return
                        } else {
                            self.changeScreen(to: .improveUsernameInfoView)
                        }
                    } else {
                        print("FaceID Fail")
                    }
                }
            }
        } else {
            print("Face ID not available")
        }
    }
}

// MARK: - HTTP Client
extension UserData {
    
    func fetchRopeData() {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "rope",
            "user": current_user?.username ?? ""
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    if let data = result["data"] as? [[String: Any]] {
                        var temp_rope_data: [Rope] = []
                        for item in data {
                            if let datetime = item["datetime"] as? String,
                               let user = item["user"] as? String,
                               let count = item["count"] as? Int,
                               let mode = item["mode"] as? String,
                               let completiontime = item["completiontime"] as? Int {
                                let ropeData = Rope(datetime: datetime, user: user, mode: mode, count: count, completiontime: completiontime)
                                temp_rope_data.append(ropeData)
                            }
                        }
                        Task { @MainActor in
                            self.ropeData = temp_rope_data
                        }
                        // print("\(#function): \(temp_rope_data)")
                    }
                }
            case .failure(let failure):
                print(failure.localizedDescription)
            }
        }
    }
    
    func fetchHeartRateData() {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "belt",
            "user": current_user?.username ?? ""
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    if let data = result["data"] as? [[String: Any]] {
                        var temp_heartRate_data: [HeartRate] = []
                        for item in data {
                            if let datetime = item["datetime"] as? String,
                               let user = item["user"] as? String,
                               let averagehr = item["averagehr"] as? Double,
                               let maxhr = item["maxhr"] as? Int,
                               let minhr = item["minhr"] as? Int {
                                let ropeData = HeartRate(datetime: datetime, user: user, averagehr: averagehr, maxhr: maxhr, minhr: minhr)
                                temp_heartRate_data.append(ropeData)
                            }
                        }
                        Task { @MainActor in
                            self.heartRateData = temp_heartRate_data
                        }
                        // print("\(#function): \(temp_heartRate_data)")
                    }
                }
            case .failure(let failure):
                print(failure.localizedDescription)
            }
        }
    }
    
    func saveRopeData(count: Int, completionTime: Int, mode: String, completion: @escaping (Result<String, Error>) -> Void) {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "rope",
            "user": current_user?.username ?? "",
            "datetime": Date().toFormattedString(),
            "count": count,
            "mode": mode,
            "completionTime": completionTime
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    completion(.success("The rope skipping data was saved successfully."))
                }
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    func saveHeartRateData(averagehr: Double, maxhr: Int, minhr: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let data: [String: Any] = [
            "sheetId": googleSheetId,
            "sheetName": "belt",
            "user": current_user?.username ?? "",
            "datetime": Date().toFormattedString(),
            "averagehr": Double(String(format: "%.1f", averagehr)) ?? 0,
            "maxhr": maxhr,
            "minhr": minhr
        ]
        httpRequest(url: googleAppScriptURL, data: data) { res in
            switch res {
            case .success(let result):
                if let result,
                   let code = result["code"] as? Int,
                   code == 200 {
                    completion(.success("The rope skipping data was saved successfully."))
                }
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
    
    func httpRequestOpenRouterAI(question: String, completion: @escaping (Result<String?, Error>) -> Void) {
        let startTime = Date().timeIntervalSince1970 // 请求开始时间戳
        
        // 定义请求的URL
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        
        // 设置请求头
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(openRouterKEY)", forHTTPHeaderField: "Authorization")
        
        // 请求体
        let requestBody: [String: Any] = [
            "model": openRouterModel,
            "messages": [
                [
                    "role": "user",
                    "content": question
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let endTime = Date().timeIntervalSince1970 // 请求结束时间戳
            print("AI 请求耗时：\(endTime - startTime) 秒")
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    let statusError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    completion(.failure(statusError))
                    return
                }
            }
            
            if let data = data {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let choices = jsonResponse["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content))
                    } else {
                        let parsingError = NSError(domain: "ParsingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
                        completion(.failure(parsingError))
                    }
                } catch {
                    completion(.failure(error))
                }
            } else {
                let noDataError = NSError(domain: "NoDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])
                completion(.failure(noDataError))
            }
        }
        
        task.resume()
    }
}

// MARK: - AI
extension UserData {
    func sendMessage(_ msg: String) {
        if msg.isEmpty {
            //            alert = AlertModel(title: "Send error", message: "The sent content cannot be empty.")
            //            isShowAlert = true
            return
        }
        isSending = true
        Task { @MainActor in
            withAnimation(.spring) {
                self.dialogueList.append(DialogueModel(type: .user, content: ipt))
                ipt = ""
            }
        }
        
        httpRequestOpenRouterAI(question: msg) { res in
            switch res {
            case .success(let result):
                if let result {
                    print("AI result: \(result)")
                    Task { @MainActor in
                        withAnimation {
                            self.dialogueList.append(DialogueModel(type: .bot, content: result))
                            self.isSending = false
                        }
                    }
                }
            case .failure(let failure):
                print("AI failure: \(failure.localizedDescription)")
            }
        }
    }
}

struct User: Codable {
    var username: String
    var password: String
    var confirmPassword: String
    
    var height: String
    var age: String
    var weight: String
    var gender: String
    
    static let empty = User(username: "", password: "", confirmPassword: "", height: "140", age: "12", weight: "60", gender: Gender.famale.rawValue)
}


// MARK: - Rope / HeartRate / Scale
struct Rope: Identifiable {
    let id = UUID()
    let datetime: String
    let user: String
    let mode: String
    let count: Int
    let completiontime: Int
}

struct HeartRate: Identifiable {
    let id = UUID()
    let datetime: String
    let user: String
    let averagehr: Double
    let maxhr: Int
    let minhr: Int
}

struct Scale: Identifiable {
    let id = UUID()
    let datetime: String
    let user: String
    let weight: Double
    let bmi: Double
    let bodyfat: Double
}

// MARK: - AI
struct DialogueModel: Codable, Equatable {
    var id: String = UUID().uuidString
    let type: Dialogue
    let content: String
    
    
    enum Dialogue: Codable {
        case user
        case bot
    }
}
