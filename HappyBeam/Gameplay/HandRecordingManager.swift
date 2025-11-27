/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Manager for recording and playing back hand motion data.
*/

import Foundation
import Combine
import QuartzCore
import ARKit

/// Manages hand motion recording and playback functionality
@MainActor
final class HandRecordingManager: ObservableObject {
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
        print("HandRecordingManager: Recording started")
    }
    
    func captureFrame(leftJoints: [HandPoseSample.JointPose],
                      rightJoints: [HandPoseSample.JointPose]) {
        guard isRecording else { return }
        guard !leftJoints.isEmpty || !rightJoints.isEmpty else { return }
        
        let timestamp = CACurrentMediaTime()
        let relativeTime = timestamp - recordingStart
        let sample = HandPoseSample(timestamp: relativeTime, left: leftJoints, right: rightJoints)
        samples.append(sample)
        
        // Log every 60 frames (roughly once per second at 60fps)
        if samples.count % 60 == 0 {
            print("HandRecordingManager: Captured \(samples.count) frames")
        }
    }
    
    func stopRecordingAndSave() async {
        guard isRecording else { 
            print("stopRecordingAndSave: Not recording, skipping save")
            return 
        }
        isRecording = false
        
        print("stopRecordingAndSave: Collected \(samples.count) samples")
        guard !samples.isEmpty else {
            print("stopRecordingAndSave: No samples to save")
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
            print("Documents directory: \(directory.path)")
            let filename = "HandPose_\(Self.filenameFormatter.string(from: Date())).json"
            let url = directory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            lastSavedURL = url
            print("Recording saved successfully: \(url.path) (\(data.count) bytes)")
        } catch {
            print("Failed to save recording: \(error)")
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
    
    /// Load a recording from a file URL
    func loadRecording(from url: URL) async throws -> HandPoseSequence {
        let data = try Data(contentsOf: url)
        let sequence = try JSONDecoder().decode(HandPoseSequence.self, from: data)
        return sequence
    }
    
    /// Get list of available recordings
    func getAvailableRecordings() -> [URL] {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("getAvailableRecordings: Could not get documents directory")
            return []
        }
        
        print("getAvailableRecordings: Searching in \(directory.path)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            print("getAvailableRecordings: Found \(files.count) total files")
            
            let recordings = files.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("HandPose_") }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            
            print("getAvailableRecordings: Found \(recordings.count) hand pose recordings")
            for recording in recordings {
                print("  - \(recording.lastPathComponent)")
            }
            
            return recordings
        } catch {
            print("Error getting recordings: \(error)")
            return []
        }
    }
}

/// Represents a single sample of hand pose data at a specific timestamp
struct HandPoseSample: Codable, Sendable {
    let timestamp: TimeInterval
    let left: [JointPose]
    let right: [JointPose]
    
    struct JointPose: Codable, Sendable {
        let name: String
        let position: [Float]
        let orientation: [Float]
        
        init(name: String, transform: simd_float4x4) {
            self.name = name
            let translation = SIMD3<Float>(transform.columns.3.x,
                                           transform.columns.3.y,
                                           transform.columns.3.z)
            let rotation = simd_quaternion(transform)
            self.position = [translation.x, translation.y, translation.z]
            self.orientation = [rotation.imag.x, rotation.imag.y, rotation.imag.z, rotation.real]
        }
        
        var transformMatrix: simd_float4x4 {
            guard position.count == 3, orientation.count == 4 else { return matrix_identity_float4x4 }
            let translation = SIMD3<Float>(position[0], position[1], position[2])
            let rotation = simd_quatf(ix: orientation[0], iy: orientation[1], iz: orientation[2], r: orientation[3])
            var matrix = simd_float4x4(rotation)
            matrix.columns.3 = SIMD4<Float>(translation, 1)
            return matrix
        }
    }
}

/// Represents a sequence of hand pose samples
struct HandPoseSequence: Codable, Sendable {
    let version: Int
    let createdAt: Date
    let samples: [HandPoseSample]
    
    init(samples: [HandPoseSample], version: Int = 1, createdAt: Date = .now) {
        self.version = version
        self.createdAt = createdAt
        self.samples = samples
    }
}
