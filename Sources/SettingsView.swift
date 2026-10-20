import SwiftUI
import AppKit
import ServiceManagement

/// The Settings window: thresholds, repeat interval, sounds, quiet hours, menu bar and login options.
struct SettingsView: View {
    @AppStorage(Keys.low) private var low = 20
    @AppStorage(Keys.high) private var high = 80
    @AppStorage(Keys.criticalEnabled) private var criticalEnabled = true
    @AppStorage(Keys.critical) private var critical = 5
    @AppStorage(Keys.repeatMinutes) private var repeatMinutes = 5
    @AppStorage(Keys.lowSound) private var lowSound = "Basso"
    @AppStorage(Keys.highSound) private var highSound = "Glass"
    @AppStorage(Keys.criticalSound) private var criticalSound = "Sosumi"
    @AppStorage(Keys.quietEnabled) private var quietEnabled = false
    @AppStorage(Keys.quietStart) private var quietStart = 22 * 60
    @AppStorage(Keys.quietEnd) private var quietEnd = 7 * 60
    @AppStorage(Keys.showPercent) private var showPercent = true
    @AppStorage(Keys.showDot) private var showDot = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Thresholds") {
                Stepper("Low alert: \(low)%", value: $low, in: 5...max(5, high - 5))
                Stepper("High alert: \(high)%", value: $high, in: min(100, low + 5)...100)
                Toggle("Critical alert (louder, repeating)", isOn: $criticalEnabled)
                if criticalEnabled {
                    Stepper("Critical level: \(critical)%", value: $critical, in: 1...max(1, low - 1))
                }
                Picker("Repeat alerts", selection: $repeatMinutes) {
                    Text("Only once").tag(0)
                    ForEach([1, 2, 5, 10, 15, 30], id: \.self) { Text("Every \($0) min").tag($0) }
                }
            }
            Section("Sounds") {
                SoundRow(title: "Low battery", sound: $lowSound)
                SoundRow(title: "Charged", sound: $highSound)
                SoundRow(title: "Critical", sound: $criticalSound, times: 3)
            }
            Section("Quiet Hours") {
                Toggle("Silence sounds (banners still appear)", isOn: $quietEnabled)
                if quietEnabled {
                    DatePicker("From", selection: timeBinding($quietStart), displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: timeBinding($quietEnd), displayedComponents: .hourAndMinute)
                }
            }
            Section("General") {
                Toggle("Show percentage in menu bar", isOn: $showPercent)
                Toggle("Show coloured status dot", isOn: $showDot)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                HStack {
                    Text("ChargeLevelChime is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { openDonationPage() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: low) { _, value in if critical >= value { critical = max(1, value - 1) } }
    }

    /// Bridges a "minutes since midnight" integer to a Date for DatePicker.
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60,
                                         second: 0, of: Date()) ?? Date() },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// A sound picker (system sounds plus a custom file) with a preview button.
struct SoundRow: View {
    let title: String
    @Binding var sound: String
    var times = 1

    var body: some View {
        HStack {
            Picker(title, selection: $sound) {
                ForEach(SoundPlayer.availableSounds, id: \.self) { Text($0).tag($0) }
                if sound.hasPrefix("/") {
                    Text((sound as NSString).lastPathComponent).tag(sound)
                }
            }
            Button("Choose…") { chooseFile() }
            Button { SoundPlayer.shared.play(sound, times: times) } label: { Image(systemName: "play.fill") }
                .help("Preview")
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { sound = url.path }
    }
}
