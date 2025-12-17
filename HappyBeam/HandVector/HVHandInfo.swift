//
//  HVHandInfo.swift
//  HappyBeam
//
//  Ported from HandVector
//

import ARKit

public struct HVHandInfo: Sendable, Equatable {
    public let chirality: HandAnchor.Chirality
    public let allJoints: [HandSkeleton.JointName: HVJointInfo]
    public let transform: simd_float4x4
    
    public init(chirality: HandAnchor.Chirality, allJoints: [HandSkeleton.JointName: HVJointInfo], transform: simd_float4x4) {
        self.chirality = chirality
        self.allJoints = allJoints
        self.transform = transform
    }
    
    public init(handAnchor: HandAnchor) {
        self.chirality = handAnchor.chirality
        self.transform = handAnchor.originFromAnchorTransform
        
        var joints: [HandSkeleton.JointName: HVJointInfo] = [:]
        if let skeleton = handAnchor.handSkeleton {
            for jointName in HandSkeleton.JointName.allCases {
                let joint = skeleton.joint(jointName)
                joints[jointName] = HVJointInfo(joint: joint)
            }
        }
        self.allJoints = joints
    }
    
    public func vectorEndTo(_ jointName: HandSkeleton.JointName) -> SIMD3<Float> {
        guard let joint = allJoints[jointName] else { return .zero }
        return joint.position
    }
}
