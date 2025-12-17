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
    
    /// The elapsed time since playback started (in seconds).
    @Published private(set) var playbackElapsedTime: TimeInterval = 0
    
    private var frames: [HandPoseFrame] = []
    private var recordingStart: TimeInterval = 0
    private var playbackTask: Task<Void, Never>?
    private var elapsedTimeTask: Task<Void, Never>?
    
    // Playback state for pause/resume
    private var playbackRecording: HandPoseRecording?
    private var playbackStartIndex: Int = 0
    private var playbackStartOffset: TimeInterval = 0
    
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
        
        playbackRecording = recording
        playbackStartIndex = 0
        playbackStartOffset = 0
        playbackElapsedTime = 0
        isPlayingBack = true
        let frames = recording.frames
        
        playbackTask = Task {
            guard let baseTime = frames.first?.timestamp else {
                await MainActor.run { self.stopPlayback() }
                return
            }
            let startWallClock = CACurrentMediaTime()
            
            for (index, frame) in frames.enumerated() {
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
                    self.playbackElapsedTime = frame.timestamp
                    self.playbackStartIndex = index
                    self.playbackStartOffset = frame.timestamp
                }
            }
            
            // Only reset if NOT cancelled (natural finish)
            if !Task.isCancelled {
                await MainActor.run {
                    self.isPlayingBack = false
                    // Keep the last frame visible and time at end
                    // Do NOT reset to 0 here, so UI knows it finished
                    // self.playbackStartIndex = 0
                    // self.playbackStartOffset = 0
                    // self.playbackElapsedTime = 0
                }
            }
        }
    }

    /// Public-safe start: will resume if the same recording is already loaded and paused,
    /// otherwise begin fresh playback.
    func startOrResumePlayback(with recording: HandPoseRecording) {
        // If we already have a recording loaded and it appears to be the same
        // recording (same frame count and first/last timestamps), resume; otherwise
        // start fresh with the provided recording.
        if let loaded = playbackRecording {
            let sameCount = loaded.frames.count == recording.frames.count
            let sameFirst = loaded.frames.first?.timestamp == recording.frames.first?.timestamp
            let sameLast = loaded.frames.last?.timestamp == recording.frames.last?.timestamp
            if sameCount && sameFirst && sameLast {
                resumePlayback()
                return
            }
        }

        beginPlayback(with: recording)
    }
    
    /// Resumes playback from where it was paused.
    private func resumePlayback() {
        guard let recording = playbackRecording else { return }
        guard playbackStartIndex < recording.frames.count else {
            // Playback finished, restart from beginning
            playbackStartIndex = 0
            playbackStartOffset = 0
            playbackElapsedTime = 0
            beginPlayback(with: recording)
            return
        }
        
        isPlayingBack = true
        let startIndexOffset = playbackStartIndex
        let frames = Array(recording.frames.dropFirst(startIndexOffset))
        let baseOffset = playbackStartOffset
        
        playbackTask = Task {
            let startWallClock = CACurrentMediaTime()
            
            for (index, frame) in frames.enumerated() {
                guard !Task.isCancelled else { break }
                
                let elapsed = CACurrentMediaTime() - startWallClock
                let target = frame.timestamp - baseOffset
                
                if target > elapsed {
                    let delay = target - elapsed
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        break
                    }
                }
                
                guard !Task.isCancelled else { break }
                let absoluteIndex = startIndexOffset + index
                await MainActor.run {
                    self.currentPlaybackFrame = frame
                    self.playbackElapsedTime = frame.timestamp
                    self.playbackStartIndex = absoluteIndex
                    self.playbackStartOffset = frame.timestamp
                }
            }
            
            // Only reset if NOT cancelled (natural finish)
            if !Task.isCancelled {
                await MainActor.run {
                    self.isPlayingBack = false
                    // Keep the last frame visible and time at end
                    // Do NOT reset to 0 here, so UI knows it finished
                    // self.playbackStartIndex = 0
                    // self.playbackStartOffset = 0
                    // self.playbackElapsedTime = 0
                }
            }
        }
    }
    
    /// Pauses the current playback (can be resumed later).
    func pausePlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlayingBack = false

        // Compute a robust resume index so resume continues from the nearest
        // frame instead of restarting from zero. Prefer the explicit
        // `playbackElapsedTime` when available; otherwise use the
        // `currentPlaybackFrame` as a fallback (handles race conditions).
        if let recording = playbackRecording {
            if playbackElapsedTime > 0 {
                if let idx = recording.frames.firstIndex(where: { $0.timestamp >= self.playbackElapsedTime }) {
                    playbackStartIndex = max(0, idx)
                    playbackStartOffset = recording.frames[playbackStartIndex].timestamp
                } else {
                    // If elapsed time is beyond last frame, set to last index.
                    playbackStartIndex = max(0, recording.frames.count - 1)
                    playbackStartOffset = recording.frames[playbackStartIndex].timestamp
                }
            } else if let current = currentPlaybackFrame {
                // Try to find exact match first, otherwise pick nearest frame.
                if let idx = recording.frames.firstIndex(where: { $0.timestamp == current.timestamp }) {
                    playbackStartIndex = idx
                    playbackStartOffset = current.timestamp
                    playbackElapsedTime = current.timestamp
                } else if let nearest = recording.frames.enumerated().min(by: { abs($0.element.timestamp - current.timestamp) < abs($1.element.timestamp - current.timestamp) })?.offset {
                    playbackStartIndex = nearest
                    playbackStartOffset = recording.frames[playbackStartIndex].timestamp
                    playbackElapsedTime = recording.frames[playbackStartIndex].timestamp
                } else {
                    // fallback to start
                    playbackStartIndex = 0
                    playbackStartOffset = 0
                    playbackElapsedTime = 0
                }
            } else {
                // Final fallback: use elapsed time search (may be zero)
                if let idx = recording.frames.firstIndex(where: { $0.timestamp >= self.playbackElapsedTime }) {
                    playbackStartIndex = max(0, idx)
                    playbackStartOffset = recording.frames[playbackStartIndex].timestamp
                } else {
                    playbackStartIndex = max(0, recording.frames.count - 1)
                    playbackStartOffset = recording.frames[playbackStartIndex].timestamp
                }
            }
        }
    }
    
    /// Stops the current playback completely.
    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlayingBack = false
        currentPlaybackFrame = nil
        playbackElapsedTime = 0
        playbackStartIndex = 0
        playbackStartOffset = 0
        playbackRecording = nil
    }
}
