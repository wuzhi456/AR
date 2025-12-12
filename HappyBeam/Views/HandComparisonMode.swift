/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
ViewModel for the Calligraphy Comparison feature.
*/

import Foundation
import SwiftUI
import simd

enum HandComparisonMode: String, CaseIterable, Identifiable {
    case rightToRight = "Right vs Right"
    case leftToLeft = "Left vs Left"
    case rightToLeft = "Right vs Left (Mirror)" // User's Right vs Coach's Left (or vice versa? User said "Right vs Left (Mirror)")
    // Usually "Right vs Left (Mirror)" means comparing Right hand to a mirrored version of Left hand, or comparing Right hand to Left hand as if it was mirrored.
    // Let's assume User Right vs Coach Left (Mirrored to look like Right)
    
    var id: String { self.rawValue }
}

@MainActor
class CalligraphyComparisonViewModel: ObservableObject {
    @Published var availableRecordings: [URL] = []
    @Published var coachRecording: HandPoseRecording?
    @Published var userRecording: HandPoseRecording?
    @Published var comparisonMode: HandComparisonMode = .rightToRight
    
    @Published var isComparing = false
    @Published var similarityScore: Float = 0.0
    @Published var progress: Double = 0.0
    @Published var isPlaying = false
    
    // Trimming ranges (0.0 to 1.0)
    @Published var coachTrimRange: ClosedRange<Double> = 0.0...1.0
    @Published var userTrimRange: ClosedRange<Double> = 0.0...1.0
    
    // For visualization
    @Published var currentCoachFrame: HandPoseFrame?
    @Published var currentUserFrame: HandPoseFrame?
    
    private var playbackTask: Task<Void, Never>?
    private let captureManager = HandCaptureManager() // Or use shared instance if available
    
    init() {
        refreshRecordings()
    }
    
    func refreshRecordings() {
        availableRecordings = captureManager.listSavedRecordings()
    }
    
    func loadCoachRecording(from url: URL) {
        do {
            coachRecording = try captureManager.loadRecording(from: url)
            coachTrimRange = 0.0...1.0
        } catch {
            print("Error loading coach recording: \(error)")
        }
    }
    
    func loadUserRecording(from url: URL) {
        do {
            userRecording = try captureManager.loadRecording(from: url)
            userTrimRange = 0.0...1.0
        } catch {
            print("Error loading user recording: \(error)")
        }
    }
    
    func startComparison() {
        guard let coach = coachRecording, let user = userRecording else { return }
        
        isComparing = true
        
        let score = calculateSimilarity(coach: coach, user: user, mode: comparisonMode)
        similarityScore = score
        
        isComparing = false
    }
    
    private func calculateSimilarity(coach: HandPoseRecording, user: HandPoseRecording, mode: HandComparisonMode) -> Float {
        guard !coach.frames.isEmpty, !user.frames.isEmpty else { return 0.0 }
        
        let sampleCount = 100 // Normalize to 100 frames
        var totalDistance: Float = 0.0
        
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleCount - 1)
            
            let coachFrame = sampleFrame(recording: coach, at: t, range: coachTrimRange)
            let userFrame = sampleFrame(recording: user, at: t, range: userTrimRange)
            
            let coachJoints = getRelevantJoints(frame: coachFrame, isCoach: true, mode: mode)
            let userJoints = getRelevantJoints(frame: userFrame, isCoach: false, mode: mode)
            
            totalDistance += calculateFrameDistance(coachJoints: coachJoints, userJoints: userJoints)
        }
        
        let averageDistance = totalDistance / Float(sampleCount)
        // Convert distance to similarity score (0 to 1). This is arbitrary and needs tuning.
        // Assuming max reasonable distance is around 0.5 meters?
        let similarity = max(0, 1.0 - (averageDistance * 5.0)) // Simple heuristic
        return similarity
    }
    
    private func sampleFrame(recording: HandPoseRecording, at t: Double, range: ClosedRange<Double>) -> HandPoseFrame {
        guard let first = recording.frames.first, let last = recording.frames.last else { return recording.frames[0] }
        
        let totalDuration = last.timestamp - first.timestamp
        let startOffset = totalDuration * range.lowerBound
        let endOffset = totalDuration * range.upperBound
        let duration = endOffset - startOffset
        
        let targetTime = first.timestamp + startOffset + (duration * t)
        
        // Find frame closest to targetTime
        // Optimization: Binary search could be used here
        let closest = recording.frames.min(by: { abs($0.timestamp - targetTime) < abs($1.timestamp - targetTime) })
        return closest ?? recording.frames[0]
    }
    
    private func getRelevantJoints(frame: HandPoseFrame, isCoach: Bool, mode: HandComparisonMode) -> [HandJointPose] {
        // Select Left or Right based on mode
        var joints: [HandJointPose] = []
        
        switch mode {
        case .rightToRight:
            joints = isCoach ? frame.rightJoints : frame.rightJoints
        case .leftToLeft:
            joints = isCoach ? frame.leftJoints : frame.leftJoints
        case .rightToLeft:
            // Coach uses Left (mirrored), User uses Right? Or Coach Right, User Left?
            // "Right vs Left (Mirror)" usually implies comparing opposite hands.
            // Let's assume we compare User's Right to Coach's Left (mirrored).
            if isCoach {
                joints = frame.leftJoints.map { mirrorJoint($0) }
            } else {
                joints = frame.rightJoints
            }
        }
        
        return joints
    }
    
    private func mirrorJoint(_ joint: HandJointPose) -> HandJointPose {
        // Mirror across X axis? Or Z?
        // For simple visualization, we might just flip X position.
        // Orientation mirroring is more complex.
        // For distance calculation, we mainly care about relative positions of fingers.
        // Let's just flip position.x for now.
        var pos = joint.position
        pos[0] = -pos[0] 
        // TODO: Fix orientation if needed for advanced comparison
        
        // We need to reconstruct the struct. 
        // Since HandJointPose properties are let, we need a new init or helper.
        // But HandJointPose init takes a transform.
        
        // Let's just return a dummy with modified position for distance calc.
        // Ideally we should add a helper to HandJointPose.
        
        // Hack: Create a transform with mirrored position
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(pos[0], pos[1], pos[2], 1)
        return HandJointPose(name: joint.name, transform: transform)
    }
    
    private func calculateFrameDistance(coachJoints: [HandJointPose], userJoints: [HandJointPose]) -> Float {
        // Focus on Thumb, Index, Middle (and Ring)
        let importantFingers = ["thumb", "indexFinger", "middleFinger", "ringFinger"]
        var distance: Float = 0.0
        var count: Float = 0.0
        
        // We need to align the hands first (remove global translation/rotation difference)
        // Or we assume the wrist is at (0,0,0) and compare relative positions.
        // Let's normalize by wrist position.
        
        guard let coachWrist = coachJoints.first(where: { $0.name == "wrist" }),
              let userWrist = userJoints.first(where: { $0.name == "wrist" }) else { return 1.0 }
        
        let coachWristPos = SIMD3<Float>(coachWrist.position[0], coachWrist.position[1], coachWrist.position[2])
        let userWristPos = SIMD3<Float>(userWrist.position[0], userWrist.position[1], userWrist.position[2])
        
        for jointName in ["thumbTip", "indexFingerTip", "middleFingerTip", "ringFingerTip"] {
            if let cJoint = coachJoints.first(where: { $0.name == jointName }),
               let uJoint = userJoints.first(where: { $0.name == jointName }) {
                
                let cPos = SIMD3<Float>(cJoint.position[0], cJoint.position[1], cJoint.position[2]) - coachWristPos
                let uPos = SIMD3<Float>(uJoint.position[0], uJoint.position[1], uJoint.position[2]) - userWristPos
                
                let d = simd_distance(cPos, uPos)
                
                // Weighting: Thumb, Index, Middle > Ring
                let weight: Float = (jointName.contains("ring")) ? 0.5 : 1.0
                
                distance += d * weight
                count += weight
            }
        }
        
        return count > 0 ? distance / count : 1.0
    }
    
    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    func startPlayback() {
        guard let coach = coachRecording, let user = userRecording else { return }
        isPlaying = true
        
        playbackTask = Task {
            let duration = 5.0 // Play over 5 seconds or use max duration
            let startTime = CACurrentMediaTime()
            
            while isPlaying {
                let elapsed = CACurrentMediaTime() - startTime
                let t = (elapsed / duration).truncatingRemainder(dividingBy: 1.0)
                
                await MainActor.run {
                    self.progress = t
                    self.currentCoachFrame = sampleFrame(recording: coach, at: t, range: coachTrimRange)
                    self.currentUserFrame = sampleFrame(recording: user, at: t, range: userTrimRange)
                }
                
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
            }
        }
    }
    
    func stopPlayback() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }
}