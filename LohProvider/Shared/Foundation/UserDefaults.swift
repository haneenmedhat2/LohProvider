//
//  UserDefaults.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 22/07/2025.
//

import Foundation

@propertyWrapper
struct ValueDefault<Value> {
    
    let key: String
    let defaultValue: Value
    let container: UserDefaults = .standard
    
    var wrappedValue: Value {
        get {
            return container.value(forKey: key) as? Value ?? defaultValue
        }
        set {
            container.setValue(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct ModelsDefault<Model: Codable> {
    
    let key: String
    let defaultValue: Model
    let container: UserDefaults = .standard
    
    var wrappedValue: Model {
        get {
            let decoder = JSONDecoder()
            guard let decoded = container.object(forKey: key) as? Data else {return defaultValue}
            let loadedValue = try? decoder.decode(Model.self, from: decoded)
            return loadedValue ?? defaultValue
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                container.set(encoded, forKey: key)
                container.synchronize()
            }
        }
    }
}

extension UserDefaults {
    
    private enum Keys: String {
        case googleMapKey
        case accessToken
        case pushNotificationToken
        case isFirstTime
        case isLogin
        case user
    }
    
    @ValueDefault(key: Keys.googleMapKey.rawValue, defaultValue: "AIzaSyBd2QY3Km15ITvDCR9Rl6-68HfqqcX0ZqI")
    static var googleMapKey: String
    
    static var accessToken: String? {
        get { AuthTokenStore().read() }
        set {
            if let newValue { try? AuthTokenStore().write(newValue) }
            else { try? AuthTokenStore().delete() }
        }
    }
    
    @ValueDefault(key: Keys.pushNotificationToken.rawValue, defaultValue: nil)
    static var pushNotificationToken: String?
    
    @ValueDefault(key: Keys.isFirstTime.rawValue, defaultValue: true)
    static var isFirstTime: Bool
    
    @ValueDefault(key: Keys.isLogin.rawValue, defaultValue: false)
    static var isLogin: Bool {
        didSet {
            NotificationCenter.default.post(name: .isLoginChanged, object: nil)
        }
    }
    @ModelsDefault(key: Keys.user.rawValue, defaultValue: nil)
    static var user: MerchantProfile?

    static func save(_ profile: MerchantProfile) {
        user = profile
        NotificationCenter.default.post(name: .profileUpdated, object: nil)
    }

    static func clearAuthentication() throws {
        try AuthTokenStore().delete()
        standard.removeObject(forKey: Keys.user.rawValue)
        isLogin = false
        NotificationCenter.default.post(name: .profileUpdated, object: nil)
    }
}

struct AuthTokenStore {
    private let key = "accessToken"

    func read() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func write(_ token: String) throws {
        UserDefaults.standard.set(token, forKey: key)
    }

    func delete() throws {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
