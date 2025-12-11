/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Manager for recording and playing back hand pose data.
*/

import Foundation
import Combine
import QuartzCore

/// Manages recording and playback of hand pose data.
@MainActor
final class HandCaptureManager: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlayingBack = false
    @Published private(set) var currentPlaybackFrame: HandPoseFrame?
    @Published private(set) var lastSavedURL: URL?
    
    /// Indicates whether there is unsaved recording data.
    @Published private(set) var hasUnsavedRecording = false
    
    /// The elapsed time since recording started (in seconds).
    @Published private(set) var recordingElapsedTime: TimeInterval = 0
    
    private var frames: [HandPoseFrame] = []
    private var recordingStart: TimeInterval = 0
    private var playbackTask: Task<Void, Never>?
    private var elapsedTimeTask: Task<Void, Never>?
    
    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    /// Starts recording hand pose data.
    func startRecording() {
        stopPlayback()
        frames.removeAll()
        recordingStart = CACurrentMediaTime()
        recordingElapsedTime = 0
        isRecording = true
        hasUnsavedRecording = false
        
        // Start elapsed time update task
        elapsedTimeTask?.cancel()
        elapsedTimeTask = Task {
            while !Task.isCancelled && isRecording {
                await MainActor.run {
                    self.recordingElapsedTime = CACurrentMediaTime() - self.recordingStart
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // Update every 100ms
            }
        }
    }
    
    /// Captures a single frame of hand pose data.
    func captureFrame(leftJoints: [HandJointPose], rightJoints: [HandJointPose]) {
        guard isRecording else { return }
        guard !leftJoints.isEmpty || !rightJoints.isEmpty else { return }
        
        let timestamp = CACurrentMediaTime()
        let relativeTime = timestamp - recordingStart
        let frame = HandPoseFrame(timestamp: relativeTime, leftJoints: leftJoints, rightJoints: rightJoints)
        frames.append(frame)
    }
    
    /// Stops recording without saving. The data remains in memory for potential saving later.
    func stopRecording() {
        guard isRecording else { return }
        elapsedTimeTask?.cancel()
        elapsedTimeTask = nil
        isRecording = false
        hasUnsavedRecording = !frames.isEmpty
    }
    
    /// Saves the current recording data to a file.
    func saveRecording() async {
        guard hasUnsavedRecording, !frames.isEmpty else { return }
        
        let recording = HandPoseRecording(frames: frames)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(recording)
            
            guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Failed to get documents directory")
                return
            }
            let filename = "HandPose_\(Self.filenameFormatter.string(from: Date())).json"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            lastSavedURL = url
            print("Recording saved: \(url.path)")
            
            // Clear data after successful save
            frames.removeAll()
            hasUnsavedRecording = false
            recordingElapsedTime = 0
        } catch {
            print("Failed to save hand pose recording: \(error)")
        }
    }
    
    /// Discards the current unsaved recording data.
    func discardRecording() {
        frames.removeAll()
        hasUnsavedRecording = false
        recordingElapsedTime = 0
    }
    
    /// Stops recording and saves the data to a file (legacy method for compatibility).
    func stopRecordingAndSave() async {
        stopRecording()
        await saveRecording()
    }
    
    /// Lists all saved hand pose recordings.
    func listSavedRecordings() -> [URL] {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return files.filter { $0.lastPathComponent.hasPrefix("HandPose_") && $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            print("Failed to list recordings: \(error)")
            return []
        }
    }
    
    /// Loads a recording from a URL.
    func loadRecording(from url: URL) throws -> HandPoseRecording {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(HandPoseRecording.self, from: data)
    }
    
    /// Begins playback of a hand pose recording.
    func beginPlayback(with recording: HandPoseRecording) {
        stopPlayback()
        guard !recording.frames.isEmpty else { return }
        
        isPlayingBack = true
        let frames = recording.frames
        
        playbackTask = Task {
            guard let baseTime = frames.first?.timestamp else {
                await MainActor.run { self.stopPlayback() }
                return
            }
            let startWallClock = CACurrentMediaTime()
            
            for frame in frames {
                guard !Task.isCancelled else { break }
                
                let elapsed = CACurrentMediaTime() - startWallClock
                let target = frame.timestamp - baseTime
                
                if target > elapsed {
                    let delay = target - elapsed
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        break
                    }
                }
                
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.currentPlaybackFrame = frame
                }
            }
            
            await MainActor.run {
                self.isPlayingBack = false
                self.currentPlaybackFrame = nil
            }
        }
    }
    
    /// Stops the current playback.
    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlayingBack = false
        currentPlaybackFrame = nil
    }
}
