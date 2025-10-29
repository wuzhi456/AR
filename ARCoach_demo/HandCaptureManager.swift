import Foundation
internal import Combine
import QuartzCore

@MainActor
final class HandCaptureManager: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlayingBack = false
    @Published private(set) var currentPlaybackFrame: HandPoseSample?
    @Published private(set) var lastSavedURL: URL?

    private var samples: [HandPoseSample] = []
    private var recordingStart: TimeInterval = 0
    private var playbackTask: Task<Void, Never>?

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    func startRecording() {
        stopPlayback()
        samples.removeAll()
        recordingStart = CACurrentMediaTime()
        isRecording = true
    }

    func captureFrame(leftJoints: [HandPoseSample.JointPose],
                      rightJoints: [HandPoseSample.JointPose]) {
        guard isRecording else { return }
        guard !leftJoints.isEmpty || !rightJoints.isEmpty else { return }

        let timestamp = CACurrentMediaTime()
        let relativeTime = timestamp - recordingStart
        let sample = HandPoseSample(timestamp: relativeTime, left: leftJoints, right: rightJoints)
        samples.append(sample)
    }

    func stopRecordingAndSave() async {
        guard isRecording else { return }
        isRecording = false

        guard !samples.isEmpty else {
            samples.removeAll()
            return
        }

        let sequence = HandPoseSequence(samples: samples)
        samples.removeAll()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sequence)

            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let filename = "HandPose_\(Self.filenameFormatter.string(from: Date())).json"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            lastSavedURL = url
            print("录制已保存: \(url.path)")
        } catch {
            print("保存手势失败: \(error)")
        }
    }

    func beginPlayback(with sequence: HandPoseSequence) {
        stopPlayback()
        guard !sequence.samples.isEmpty else { return }

        isPlayingBack = true
        let samples = sequence.samples

        playbackTask = Task {
            guard let baseTime = samples.first?.timestamp else {
                await MainActor.run { self.stopPlayback() }
                return
            }
            let startWallClock = CACurrentMediaTime()

            for sample in samples {
                guard !Task.isCancelled else { break }

                let elapsed = CACurrentMediaTime() - startWallClock
                let target = sample.timestamp - baseTime

                if target > elapsed {
                    let delay = target - elapsed
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        // Task was cancelled, so break the loop.
                        break
                    }
                }

                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.currentPlaybackFrame = sample
                }
            }

            await MainActor.run {
                self.isPlayingBack = false
                self.currentPlaybackFrame = nil
            }
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlayingBack = false
        currentPlaybackFrame = nil
    }
}
