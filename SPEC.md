# ChargeLevelChime — specification

**Tagline:** Get a chime and a banner when your battery hits the low or full level you chose, so you plug in or unplug on time.

**Category:** Battery & Power

**Inspired by (paid):** Battery Charge Sound Alarm ($7.99 one-time)

**Frameworks:** SwiftUI, AppKit, IOKit, UserNotifications, AVFoundation, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and evidence of demand. Battery Charge Sound Alarm is a menu bar app that sounds an alert when the battery falls below a level you set and when it reaches a chosen full-charge level, which helps people who want to keep their battery between about 20 and 80 percent for long-term health. It is sold in the Mac App Store at 7.99 dollars as a one-time license, and a crowd of similar cheap alert apps and open source projects exist, showing consistent demand since macOS only warns at very low levels. Our version adds clear thresholds, custom sounds and quiet hours.

Feature set for our clean-room version. A menu bar app that shows the battery percentage and a state icon for charging, discharging or plugged in and full. The user sets a low threshold (default 20 percent) and a high threshold (default 80 percent). When the battery is discharging and crosses the low threshold, the app plays a chosen sound and posts a notification saying to plug in. When the battery is charging and crosses the high threshold, it plays a sound and says to unplug. Alerts repeat at a chosen interval, such as every 5 minutes, until the situation is resolved, with an option to alert only once. Quiet hours suppress sounds in a time window while keeping silent banners. A Snooze for 30 minutes menu action is included. An additional critical alert level at 5 percent can use a louder, repeating sound.

UI spec. A MenuBarExtra whose label shows the percentage, optionally with a tiny colored dot. The dropdown shows the current percentage, charging state, estimated time remaining when available, power source, and the two thresholds as sliders that can be adjusted right there. Menu items: Snooze 30 Minutes, Test Alert, Settings and Quit. The settings window has low and high threshold steppers, repeat interval popup, sound pickers for each alert populated from system sounds with a preview button, quiet hours start and end, a Show percentage in menu bar toggle and launch at login. Empty state: on a desktop Mac with no battery, the app says no battery found and quits gracefully or shows a disabled state.

Technical approach. Read battery data through IOKit power sources: IOPSCopyPowerSourcesInfo and IOPSCopyPowerSourcesList, then IOPSGetPowerSourceDescription for current capacity, max capacity, is charging and the power source state. Subscribe to changes with IOPSNotificationCreateRunLoopSource so updates arrive instantly, and add a one-minute fallback timer. Play sounds with NSSound for system sounds or AVAudioPlayer for chosen files. Post banners using UserNotifications after requesting authorization on first launch, using a time sensitive interruption level for the critical alert. Persist settings in AppStorage and register launch at login with SMAppService. Track which alert has been fired with a small state machine so each crossing triggers once and resets when the battery moves back across the threshold by two percent of hysteresis.

Edge cases and error handling. Do not alert when the threshold has already been crossed at launch unless the situation persists, to avoid a startup blast. Handle thresholds where low is not below high by validating the sliders. If notifications are denied, rely on sounds and an in-menu warning color. Respect the system output volume being muted by also showing a visible banner. Handle wake from sleep by re-evaluating the state with a short delay. Charging complete states where the system reports a full 100 percent but the user set 80 should still alert once. Keep the code near 350 lines.
