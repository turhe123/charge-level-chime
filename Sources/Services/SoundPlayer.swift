import AppKit
import AVFoundation

/// Lists available system/user sounds and plays them (AVAudioPlayer, NSSound as fallback).
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var player: AVAudioPlayer?

    private static let folders = [
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Sounds"),
        URL(fileURLWithPath: "/Library/Sounds"),
        URL(fileURLWithPath: "/System/Library/Sounds"),
    ]
    private static let extensions: Set<String> = ["aiff", "aif", "caf", "wav", "m4a", "mp3"]

    /// Sorted, de-duplicated sound names found in the standard sound folders.
    static let availableSounds: [String] = {
        var names = Set<String>()
        for folder in folders {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where extensions.contains(file.pathExtension.lowercased()) {
                names.insert(file.deletingPathExtension().lastPathComponent)
            }
        }
        return names.isEmpty ? ["Glass", "Basso", "Sosumi"] : names.sorted()
    }()

    /// Resolves a sound name, or an absolute file path chosen by the user, to a file URL.
    private func url(for sound: String) -> URL? {
        if sound.hasPrefix("/") { return FileManager.default.fileExists(atPath: sound) ? URL(fileURLWithPath: sound) : nil }
        for folder in Self.folders {
            for ext in Self.extensions {
                let candidate = folder.appendingPathComponent(sound).appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }

    /// Plays `sound` `times` times in a row at full volume.
    func play(_ sound: String, times: Int = 1) {
        player?.stop()
        if let url = url(for: sound), let newPlayer = try? AVAudioPlayer(contentsOf: url) {
            newPlayer.numberOfLoops = max(0, times - 1)
            newPlayer.volume = 1
            newPlayer.play()
            player = newPlayer
        } else {
            if NSSound(named: NSSound.Name(sound))?.play() != true { NSSound.beep() }
        }
    }
}
