import Foundation
import ARKit

/// Lightweight representation of a tracked hand used by UI and comparison logic.
struct HVHandInfo: Sendable {
    let timestamp: TimeInterval
    let joints: [HandPoseSample.JointPose]
    var isTracked: Bool = true

    import Foundation
    import ARKit
    import QuartzCore
    import simd

    /// HVHandInfo represents a single tracked hand's joint poses at a point in time.
    /// Consolidated single definition to avoid duplicate-type ambiguities.
    struct HVHandInfo: Sendable {
        let timestamp: TimeInterval
        let jointPoses: [HandPoseSample.JointPose]
        var isTracked: Bool = true

        /// Initialize from a HandAnchor (ARKit or similar).
        init(handAnchor: HandAnchor) {
            var poses: [HandPoseSample.JointPose] = []
            if handAnchor.isTracked, let skeleton = handAnchor.handSkeleton {
                for jointName in HandSkeleton.JointName.allCases {
                    let joint = skeleton.joint(jointName)
                    guard joint.isTracked else { continue }
                    let worldTransform = matrix_multiply(handAnchor.originFromAnchorTransform, joint.anchorFromJointTransform)
                    poses.append(HandPoseSample.JointPose(name: String(describing: jointName), transform: worldTransform))
                }
            }
            self.timestamp = CACurrentMediaTime()
            self.jointPoses = poses
            self.isTracked = handAnchor.isTracked
        }

        /// Initialize from an existing HandPoseSample (useful when converting recorded frames)
        init(sample: HandPoseSample) {
            self.timestamp = sample.timestamp
            self.jointPoses = sample.left + sample.right
            self.isTracked = true
        }

        /// Lookup transform for a joint name (if present)
        func transformForJoint(named name: String) -> simd_float4x4? {
            return jointPoses.first(where: { $0.name == name })?.transformMatrix
        }
    }
                let joint = skeleton.joint(jointName)
