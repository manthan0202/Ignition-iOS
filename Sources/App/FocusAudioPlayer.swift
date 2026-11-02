import Foundation
import AVFoundation

@MainActor
final class FocusAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var selection: String = UserDefaults.standard.string(forKey: "ignition.focus.preferredTrack") ?? "Silence" {
        didSet { UserDefaults.standard.set(selection, forKey: "ignition.focus.preferredTrack") }
    }
    @Published var volume: Float = {
        guard UserDefaults.standard.object(forKey: "ignition.focus.volume") != nil else { return 0.35 }
        return min(1, max(0, UserDefaults.standard.float(forKey: "ignition.focus.volume")))
    }() {
        didSet { UserDefaults.standard.set(volume, forKey: "ignition.focus.volume") }
    }
    @Published var autoPlay: Bool = UserDefaults.standard.object(forKey: "ignition.focus.autoplay") == nil
        ? true : UserDefaults.standard.bool(forKey: "ignition.focus.autoplay") {
        didSet { UserDefaults.standard.set(autoPlay, forKey: "ignition.focus.autoplay") }
    }
    @Published var errorMessage: String?
    private var player: AVAudioPlayer?
    private var resumeAfterInterruption = false
    private var suspendedForDictation = false
    private var observers: [NSObjectProtocol] = []
    let tracks = ["Silence", "Original Piano", "Soft Rain", "Brown Noise"]

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main,
                                            using: Self.interruptionHandler(owner: self)))
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main,
                                            using: Self.routeHandler(owner: self)))
    }

    // Handlers are built in nonisolated factories so they do not inherit main-actor isolation.
    private nonisolated static func interruptionHandler(owner: FocusAudioPlayer) -> @Sendable (Notification) -> Void {
        return { [weak owner] note in
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in owner?.handleInterruption(typeRaw: typeRaw, optionRaw: optionRaw) }
        }
    }
    private nonisolated static func routeHandler(owner: FocusAudioPlayer) -> @Sendable (Notification) -> Void {
        return { [weak owner] note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in owner?.handleRouteChange(reasonRaw: reasonRaw) }
        }
    }

    private func handleInterruption(typeRaw: UInt?, optionRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            resumeAfterInterruption = isPlaying
            player?.pause()
            isPlaying = false
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionRaw ?? 0)
            if resumeAfterInterruption, options.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true)
                isPlaying = player?.play() ?? false
            }
            resumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt?) {
        guard let reasonRaw, let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }
        // Headphones unplugged: pause instead of suddenly playing through the speaker.
        if reason == .oldDeviceUnavailable, isPlaying {
            player?.pause()
            isPlaying = false
        }
    }

    func play(_ name: String) {
        stop()
        selection = name
        guard name != "Silence" else { return }
        let filename = name == "Original Piano" ? "original-piano" : name == "Soft Rain" ? "rain" : "brown-noise"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "wav") else {
            errorMessage = "Audio file missing"
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = volume
            player?.prepareToPlay()
            isPlaying = player?.play() ?? false
        } catch { errorMessage = error.localizedDescription }
    }
    /// Pauses only the sound, preserving both session choice and playback position.
    func pauseForSession() {
        player?.pause()
        isPlaying = false
    }
    func resumeForSession() {
        guard selection != "Silence" else { return }
        if let player {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                isPlaying = player.play()
            } catch { errorMessage = error.localizedDescription }
        } else if autoPlay { play(selection) }
    }
    /// Changing the saved sound in Settings does NOT start playback outside focus.
    func choosePreferredTrack(_ name: String, sessionActive: Bool) {
        selection = name
        if sessionActive {
            if name == "Silence" { stop() }
            else { play(name) }
        } else { stop() }
    }
    func stop() { player?.stop(); player = nil; isPlaying = false; resumeAfterInterruption = false; suspendedForDictation = false }
    func updateVolume(_ level: Float) { volume = level; player?.volume = level }

    /// Dictation switches the shared audio session to record; park music first and bring it back afterwards.
    func suspendForDictation() {
        suspendedForDictation = isPlaying
        player?.pause()
        isPlaying = false
    }
    func resumeAfterDictation() {
        guard suspendedForDictation else { return }
        suspendedForDictation = false
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            isPlaying = player?.play() ?? false
        } catch { errorMessage = error.localizedDescription }
    }
}
