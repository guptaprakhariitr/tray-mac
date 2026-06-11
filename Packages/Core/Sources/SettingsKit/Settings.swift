import Foundation
import SwiftUI

/// Lightweight typed access to UserDefaults shared across apps. Each app uses
/// its own suite (bundle id) so settings never collide.
public final class SettingsStore {
    public let defaults: UserDefaults
    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    public func get<T>(_ key: String, default def: T) -> T {
        (defaults.object(forKey: key) as? T) ?? def
    }
    public func set<T>(_ key: String, _ value: T) {
        defaults.set(value, forKey: key)
    }
    public func bool(_ key: String, default def: Bool = false) -> Bool {
        defaults.object(forKey: key) == nil ? def : defaults.bool(forKey: key)
    }
}

/// A `@AppStorage`-style property wrapper that reads/writes a Codable value as JSON.
@propertyWrapper
public struct CodableStorage<Value: Codable>: DynamicProperty {
    @AppStorage private var raw: Data
    private let fallback: Value

    public init(_ key: String, default def: Value, store: UserDefaults? = nil) {
        self.fallback = def
        let encoded = (try? JSONEncoder().encode(def)) ?? Data()
        if let store {
            _raw = AppStorage(wrappedValue: encoded, key, store: store)
        } else {
            _raw = AppStorage(wrappedValue: encoded, key)
        }
    }

    public var wrappedValue: Value {
        get { (try? JSONDecoder().decode(Value.self, from: raw)) ?? fallback }
        nonmutating set { raw = (try? JSONEncoder().encode(newValue)) ?? raw }
    }

    public var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
