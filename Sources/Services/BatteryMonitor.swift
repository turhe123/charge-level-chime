import Foundation
import AppKit
import IOKit.ps

/// A point-in-time reading of the internal battery.
struct BatterySnapshot: Equatable {
    var percent: Int
    var isCharging: Bool
    var onAC: Bool
    var isCharged: Bool
    /// Minutes to empty (discharging) or to full (charging); nil while macOS is still estimating.
    var minutesRemaining: Int?

    var stateDescription: String {
        if onAC { return isCharging ? "Charging" : (isCharged || percent >= 100 ? "Fully charged" : "Plugged in, not charging") }
        return "On battery"
    }

    var symbolName: String {
        if onAC { return isCharging ? "battery.100percent.bolt" : "powerplug" }
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

/// Reads battery data through IOKit power sources and publishes changes instantly
/// (run-loop notification), with a one-minute fallback timer and a re-check after wake.
final class BatteryMonitor: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot?
    @Published private(set) var hasBattery = true

    private let onUpdate: (BatterySnapshot) -> Void
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(onUpdate: @escaping (BatterySnapshot) -> Void) {
        self.onUpdate = onUpdate
        refresh()
        start()
    }

    deinit {
        timer?.invalidate()
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    private func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue().refresh()
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self?.refresh() }
        }
    }

    /// Re-reads the power sources and notifies the alert engine.
    func refresh() {
        let reading = Self.readBattery()
        hasBattery = reading != nil
        snapshot = reading
        if let reading { onUpdate(reading) }
    }

    private static func readBattery() -> BatterySnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let maxCap = desc[kIOPSMaxCapacityKey] as? Int, maxCap > 0 else { continue }
            let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let onAC = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let minutesKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let minutes = desc[minutesKey] as? Int
            return BatterySnapshot(
                percent: min(100, max(0, Int((Double(current) / Double(maxCap) * 100).rounded()))),
                isCharging: charging,
                onAC: onAC,
                isCharged: desc[kIOPSIsChargedKey] as? Bool ?? false,
                minutesRemaining: (minutes ?? -1) > 0 && (charging || !onAC) ? minutes : nil
            )
        }
        return nil
    }
}
