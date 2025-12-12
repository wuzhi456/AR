/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Hand pose data models for recording and playback.
*/

import Foundation
import ARKit
import simd

/// Represents a single joint pose with position and orientation.
struct HandJointPose: Codable, Sendable {
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
    
    var positionVector: SIMD3<Float> {
        guard position.count == 3 else { return .zero }
        return SIMD3<Float>(position[0], position[1], position[2])
    }
}

/// Represents a single frame of hand pose data containing both hands.
struct HandPoseFrame: Codable, Sendable {
    let timestamp: TimeInterval
    let leftJoints: [HandJointPose]
    let rightJoints: [HandJointPose]
}

/// Represents a complete recording of hand pose data over time.
struct HandPoseRecording: Codable, Sendable {
    let version: Int
    let createdAt: Date
    let frames: [HandPoseFrame]
    
    init(frames: [HandPoseFrame], version: Int = 1, createdAt: Date = .now) {
        self.version = version
        self.createdAt = createdAt
        self.frames = frames
    }
}

/// Extracts joint poses from a HandAnchor.
@MainActor
func extractJointPoses(from anchor: HandAnchor?) -> [HandJointPose] {
    guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else { return [] }
    
    return HandSkeleton.JointName.allCases.compactMap { jointName in
        let joint = skeleton.joint(jointName)
//        guard joint.isTracked else { return nil }
        let worldTransform = matrix_multiply(anchor.originFromAnchorTransform, joint.anchorFromJointTransform)
        return HandJointPose(name: String(describing: jointName), transform: worldTransform)
    }
}

/// Defines bone connections between joints for visualization.
struct HandBoneConnection {
    let startJoint: String
    let endJoint: String
    
    static let allConnections: [HandBoneConnection] = [
        // Thumb
        HandBoneConnection(startJoint: "wrist", endJoint: "thumbKnuckle"),
        HandBoneConnection(startJoint: "thumbKnuckle", endJoint: "thumbIntermediateBase"),
        HandBoneConnection(startJoint: "thumbIntermediateBase", endJoint: "thumbIntermediateTip"),
        HandBoneConnection(startJoint: "thumbIntermediateTip", endJoint: "thumbTip"),
        
        // Index finger
        HandBoneConnection(startJoint: "wrist", endJoint: "indexFingerMetacarpal"),
        HandBoneConnection(startJoint: "indexFingerMetacarpal", endJoint: "indexFingerKnuckle"),
        HandBoneConnection(startJoint: "indexFingerKnuckle", endJoint: "indexFingerIntermediateBase"),
        HandBoneConnection(startJoint: "indexFingerIntermediateBase", endJoint: "indexFingerIntermediateTip"),
        HandBoneConnection(startJoint: "indexFingerIntermediateTip", endJoint: "indexFingerTip"),
        
        // Middle finger
        HandBoneConnection(startJoint: "wrist", endJoint: "middleFingerMetacarpal"),
        HandBoneConnection(startJoint: "middleFingerMetacarpal", endJoint: "middleFingerKnuckle"),
        HandBoneConnection(startJoint: "middleFingerKnuckle", endJoint: "middleFingerIntermediateBase"),
        HandBoneConnection(startJoint: "middleFingerIntermediateBase", endJoint: "middleFingerIntermediateTip"),
        HandBoneConnection(startJoint: "middleFingerIntermediateTip", endJoint: "middleFingerTip"),
        
        // Ring finger
        HandBoneConnection(startJoint: "wrist", endJoint: "ringFingerMetacarpal"),
        HandBoneConnection(startJoint: "ringFingerMetacarpal", endJoint: "ringFingerKnuckle"),
        HandBoneConnection(startJoint: "ringFingerKnuckle", endJoint: "ringFingerIntermediateBase"),
        HandBoneConnection(startJoint: "ringFingerIntermediateBase", endJoint: "ringFingerIntermediateTip"),
        HandBoneConnection(startJoint: "ringFingerIntermediateTip", endJoint: "ringFingerTip"),
        
        // Little finger
        HandBoneConnection(startJoint: "wrist", endJoint: "littleFingerMetacarpal"),
        HandBoneConnection(startJoint: "littleFingerMetacarpal", endJoint: "littleFingerKnuckle"),
        HandBoneConnection(startJoint: "littleFingerKnuckle", endJoint: "littleFingerIntermediateBase"),
        HandBoneConnection(startJoint: "littleFingerIntermediateBase", endJoint: "littleFingerIntermediateTip"),
        HandBoneConnection(startJoint: "littleFingerIntermediateTip", endJoint: "littleFingerTip")
    ]
}
