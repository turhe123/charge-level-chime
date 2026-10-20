import Foundation
import UserNotifications

/// The kind of battery alert, in priority order.
enum AlertKind: String {
    case critical, low, high
}

/// Decides when to alert: a small state machine per alert kind that fires once per crossing,
/// repeats at the chosen interval while the situation persists, and re-arms after 2% of hysteresis.
final class AlertEngine: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var notificationsDenied = false
    @Published private(set) var activeAlert: AlertKind?

    private let defaults = UserDefaults.standard
    private let hysteresis = 2
    private let launchGrace: TimeInterval = 90
    private let launchDate = Date()
    /// Last time each alert fired; presence means the alert is "latched" until the crossing is undone.
    private var lastFired: [AlertKind: Date] = [:]
    private var lastSnapshot: BatterySnapshot?

    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.notificationsDenied = !granted }
        }
    }

    /// Show banners even while the menu is open (the app is then frontmost).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    var snoozedUntil: Date? {
        let until = Date(timeIntervalSince1970: defaults.double(forKey: Keys.snoozeUntil))
        return until > Date() ? until : nil
    }

    func snooze(minutes: Int = 30) {
        defaults.set(Date().addingTimeInterval(TimeInterval(minutes * 60)).timeIntervalSince1970, forKey: Keys.snoozeUntil)
        objectWillChange.send()
    }

    func cancelSnooze() {
        defaults.set(0.0, forKey: Keys.snoozeUntil)
        objectWillChange.send()
        if let lastSnapshot { evaluate(lastSnapshot) }
    }

    /// True if "now" falls inside the configured quiet-hours window (which may wrap past midnight).
    var inQuietHours: Bool {
        guard defaults.bool(forKey: Keys.quietEnabled) else { return false }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = defaults.integer(forKey: Keys.quietStart), end = defaults.integer(forKey: Keys.quietEnd)
        if start == end { return false }
        return start < end ? (now >= start && now < end) : (now >= start || now < end)
    }

    /// Whether the condition for `kind` currently holds; uses hysteresis when the alert is already latched.
    private func conditionHolds(_ kind: AlertKind, _ s: BatterySnapshot) -> Bool {
        let latched = lastFired[kind] != nil
        let slack = latched ? hysteresis : 0
        switch kind {
        case .critical:
            return defaults.bool(forKey: Keys.criticalEnabled) && !s.onAC
                && s.percent <= defaults.integer(forKey: Keys.critical) + slack
        case .low:
            return !s.onAC && s.percent <= defaults.integer(forKey: Keys.low) + slack
        case .high:
            // Plugged in and at/above the target — includes "full at 100%" when the target is lower.
            return s.onAC && s.percent >= defaults.integer(forKey: Keys.high) - slack
        }
    }

    /// Called on every battery update and on the one-minute fallback tick.
    func evaluate(_ s: BatterySnapshot) {
        lastSnapshot = s
        var current: AlertKind?
        for kind in [AlertKind.critical, .low, .high] {
            if conditionHolds(kind, s) {
                if current == nil { current = kind } else { lastFired[kind] = nil }
            } else {
                lastFired[kind] = nil   // resolved: re-arm
            }
        }
        activeAlert = current
        guard let kind = current else { return }
        // Avoid a startup blast: only alert at launch if the situation persists past the grace period.
        guard Date().timeIntervalSince(launchDate) >= launchGrace, snoozedUntil == nil else { return }

        let repeatMinutes = defaults.integer(forKey: Keys.repeatMinutes)
        let interval = TimeInterval(max(1, kind == .critical ? min(repeatMinutes, 2) : repeatMinutes) * 60)
        if let last = lastFired[kind] {
            guard repeatMinutes > 0 || kind == .critical, Date().timeIntervalSince(last) >= interval - 5 else { return }
        }
        lastFired[kind] = Date()
        fire(kind, percent: s.percent)
    }

    /// Plays the sound (unless in quiet hours) and posts a banner.
    func fire(_ kind: AlertKind, percent: Int, isTest: Bool = false) {
        if !inQuietHours || isTest {
            let key = kind == .critical ? Keys.criticalSound : kind == .low ? Keys.lowSound : Keys.highSound
            SoundPlayer.shared.play(defaults.string(forKey: key) ?? "Glass", times: kind == .critical ? 3 : 1)
        }
        let content = UNMutableNotificationContent()
        switch kind {
        case .critical:
            content.title = "Battery critically low: \(percent)%"
            content.body = "Plug in now — your Mac will sleep soon."
            content.interruptionLevel = .timeSensitive
        case .low:
            content.title = "Battery low: \(percent)%"
            content.body = "Time to plug in your charger."
        case .high:
            content.title = "Battery charged to \(percent)%"
            content.body = "You can unplug the charger now."
        }
        if isTest { content.subtitle = "Test alert" }
        let request = UNNotificationRequest(identifier: "chime.\(kind.rawValue)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil { DispatchQueue.main.async { self.notificationsDenied = true } }
        }
    }
}
