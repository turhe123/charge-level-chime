import SwiftUI

/// The dropdown panel: live battery status, inline threshold sliders and app actions.
struct MenuContentView: View {
    @ObservedObject var monitor: BatteryMonitor
    @ObservedObject var engine: AlertEngine
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Keys.low) private var low = 20
    @AppStorage(Keys.high) private var high = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let s = monitor.snapshot {
                status(s)
                Divider()
                thresholdSliders
            } else {
                Label("No battery found", systemImage: "bolt.slash")
                    .font(.headline)
                Text("This Mac has no internal battery, so there is nothing to monitor. Alerts are disabled.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if engine.notificationsDenied {
                Label("Notifications are off — only sounds will play. Enable them in System Settings › Notifications.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            actions
        }
        .padding(14)
        .frame(width: 290)
    }

    private func status(_ s: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: s.symbolName).font(.title2)
                Text("\(s.percent)%").font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(engine.activeAlert == nil ? Color.primary : (engine.activeAlert == .high ? .green : .red))
            }
            Text(s.stateDescription).font(.subheadline)
            Text("Power source: \(s.onAC ? "Power Adapter" : "Battery")").font(.caption).foregroundStyle(.secondary)
            if let minutes = s.minutesRemaining {
                Text("\(s.isCharging ? "Until full" : "Remaining"): \(minutes / 60)h \(minutes % 60)m")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let until = engine.snoozedUntil {
                Text("Snoozed until \(until.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var thresholdSliders: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Low alert: \(low)%").font(.caption)
            Slider(value: Binding(get: { Double(low) }, set: { low = min(Int($0), high - 5) }), in: 5...90, step: 1)
            Text("High alert: \(high)%").font(.caption)
            Slider(value: Binding(get: { Double(high) }, set: { high = max(Int($0), low + 5) }), in: 15...100, step: 1)
        }
        .onChange(of: low) { reevaluate() }
        .onChange(of: high) { reevaluate() }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 6) {
            if engine.snoozedUntil == nil {
                Button("Snooze 30 Minutes") { engine.snooze() }
            } else {
                Button("Cancel Snooze") { engine.cancelSnooze() }
            }
            Button("Test Alert") { engine.fire(.low, percent: monitor.snapshot?.percent ?? low, isTest: true) }
            Button("Settings…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Support / Donate ❤️") { openDonationPage() }
            Divider()
            Button("Quit ChargeLevelChime") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
    }

    private func reevaluate() {
        if let s = monitor.snapshot { engine.evaluate(s) }
    }
}
