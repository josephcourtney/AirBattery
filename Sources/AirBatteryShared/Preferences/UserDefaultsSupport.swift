import Foundation

// Foundation synchronizes UserDefaults access internally, but does not yet
// annotate it Sendable. AirBattery shares read-mostly app-group defaults across
// app and widget helpers, so keep the existing Swift 6 compatibility shim in
// the preferences layer rather than in an unrelated UI file.
extension UserDefaults: @retroactive @unchecked Sendable {}

extension UserDefaults {
    package func set<T: Codable>(object: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        set(data, forKey: key)
    }

    package func get<T: Codable>(objectType: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(objectType, from: data)
    }
}
