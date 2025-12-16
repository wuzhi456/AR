import Foundation
import Combine

@MainActor
final class AVPlayerViewModel: ObservableObject {
    @Published var isReplaying: Bool = false
    @Published var playbackTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    // Hook points for replay data
    var recording: HandPoseRecording?

    func loadRecording(_ recording: HandPoseRecording) {
        self.recording = recording
        self.duration = recording.frames.last?.timestamp ?? 0
        self.playbackTime = 0
        self.isReplaying = false
    }

    func play() {
        self.isReplaying = true
    }

    func pause() {
        self.isReplaying = false
    }

    func stop() {
        self.isReplaying = false
        self.playbackTime = 0
    }
}
