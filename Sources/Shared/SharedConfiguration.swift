import Foundation
import FamilyControls

/// Change both the app-group and bundle prefix before signing.
enum IgnitionConfig {
    static let group = "group.com.example.ignition"
    static let shieldStore = "ignition-active-session"
    static let selectionKey = "blockedSelection"
    static let leaseKey = "protectionLease"
    static let widgetKey = "widgetSummary"
    static var groupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil
    }
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
}

struct ProtectionLease: Codable {
    var sessionID: UUID
    var monitorName: String
    var expiresAt: Date
}

struct WidgetSummary: Codable {
    var task: String
    var detail: String
    var sessionStart: Date?
    var expectedEnd: Date?
    var isActive: Bool
    static let empty = WidgetSummary(task: "Ready to focus?", detail: "Open Ignition to start", sessionStart: nil, expectedEnd: nil, isActive: false)
}

enum SharedConfiguration {
    static func store<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { IgnitionConfig.defaults.set(data, forKey: key) }
    }
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = IgnitionConfig.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    static var selection: FamilyActivitySelection {
        get { load(FamilyActivitySelection.self, key: IgnitionConfig.selectionKey) ?? FamilyActivitySelection() }
        set { store(newValue, key: IgnitionConfig.selectionKey) }
    }
    static var lease: ProtectionLease? {
        get { load(ProtectionLease.self, key: IgnitionConfig.leaseKey) }
        set {
            if let newValue { store(newValue, key: IgnitionConfig.leaseKey) }
            else { IgnitionConfig.defaults.removeObject(forKey: IgnitionConfig.leaseKey) }
        }
    }
    static var widgetSummary: WidgetSummary {
        get { load(WidgetSummary.self, key: IgnitionConfig.widgetKey) ?? .empty }
        set { store(newValue, key: IgnitionConfig.widgetKey) }
    }
}
