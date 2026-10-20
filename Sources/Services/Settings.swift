import Foundation

/// Central list of persisted setting keys and their defaults, shared by @AppStorage and the alert engine.
enum Keys {
    static let low = "lowThreshold", high = "highThreshold"
    static let criticalEnabled = "criticalEnabled", critical = "criticalThreshold"
    static let repeatMinutes = "repeatMinutes"   // 0 = alert only once
    static let lowSound = "lowSound", highSound = "highSound", criticalSound = "criticalSound"
    static let quietEnabled = "quietEnabled", quietStart = "quietStart", quietEnd = "quietEnd" // minutes from midnight
    static let showPercent = "showPercent", showDot = "showDot"
    static let snoozeUntil = "snoozeUntil"

    static let defaults: [String: Any] = [
        low: 20, high: 80, criticalEnabled: true, critical: 5, repeatMinutes: 5,
        lowSound: "Basso", highSound: "Glass", criticalSound: "Sosumi",
        quietEnabled: false, quietStart: 22 * 60, quietEnd: 7 * 60,
        showPercent: true, showDot: true, snoozeUntil: 0.0,
    ]

    static func register() { UserDefaults.standard.register(defaults: defaults) }
}
