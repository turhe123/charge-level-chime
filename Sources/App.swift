import SwiftUI
import AppKit

/// Opens the donation page; shared by the menu and the Settings window.
func openDonationPage() {
    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
}

/// App entry point: a menu-bar-only app with a dropdown panel and a Settings window.
@main
struct ChargeLevelChimeApp: App {
    @StateObject private var monitor: BatteryMonitor
    @StateObject private var engine: AlertEngine
    @AppStorage(Keys.showPercent) private var showPercent = true
    @AppStorage(Keys.showDot) private var showDot = true
    @AppStorage(Keys.low) private var low = 20
    @AppStorage(Keys.high) private var high = 80

    init() {
        Keys.register()
        let engine = AlertEngine()
        _engine = StateObject(wrappedValue: engine)
        _monitor = StateObject(wrappedValue: BatteryMonitor { engine.evaluate($0) })
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(monitor: monitor, engine: engine)
        } label: {
            MenuBarLabel(snapshot: monitor.snapshot, showPercent: showPercent,
                         dotColor: showDot ? dotColor : nil)
        }
        .menuBarExtraStyle(.window)

        Window("ChargeLevelChime Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }

    /// Red below the low threshold, orange near it, green above the high threshold.
    private var dotColor: NSColor? {
        guard let s = monitor.snapshot else { return nil }
        if s.percent <= low { return .systemRed }
        if s.percent >= high { return .systemGreen }
        if s.percent <= low + 10 { return .systemOrange }
        return nil
    }
}

/// The menu bar label: state icon, optional percentage and an optional coloured status dot.
struct MenuBarLabel: View {
    let snapshot: BatterySnapshot?
    let showPercent: Bool
    let dotColor: NSColor?

    var body: some View {
        if let snapshot {
            HStack(spacing: 3) {
                Image(systemName: snapshot.symbolName)
                if showPercent { Text("\(snapshot.percent)%") }
                if let dotColor { Image(nsImage: Self.dot(dotColor)) }
            }
        } else {
            Image(systemName: "powerplug")
        }
    }

    /// A non-template image so the menu bar keeps the colour.
    private static func dot(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 7, height: 7), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
