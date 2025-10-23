import ARKit
import RealityKit
import SwiftUI

/// Builds simple geometry that visualizes tracked hand joints and bones.
@MainActor
final class HandSkeletonRenderer: ObservableObject {
    private let anchor = AnchorEntity(.world)
    private var jointEntities: [JointKey: ModelEntity] = [:]
    private var boneEntities: [BoneKey: ModelEntity] = [:]
    private var isInstalled = false

    private let jointRadius: Float = 0.012
    private let boneRadius: Float = 0.003

    private let jointNames: [HandSkeleton.JointName] = [
        .wrist,
        .palm,
        .thumbKnuckle,
        .thumbIntermediateBase,
        .thumbIntermediateTip,
        .thumbTip,
        .indexFingerKnuckle,
        .indexFingerIntermediateBase,
        .indexFingerIntermediateTip,
        .indexFingerTip,
        .middleFingerKnuckle,
        .middleFingerIntermediateBase,
        .middleFingerIntermediateTip,
        .middleFingerTip,
        .ringFingerKnuckle,
        .ringFingerIntermediateBase,
        .ringFingerIntermediateTip,
        .ringFingerTip,
        .littleFingerKnuckle,
        .littleFingerIntermediateBase,
        .littleFingerIntermediateTip,
        .littleFingerTip
    ]

    private lazy var boneSegments: [(HandSkeleton.JointName, HandSkeleton.JointName)] = {
        var segments: [(HandSkeleton.JointName, HandSkeleton.JointName)] = []

        func appendFinger(_ joints: [HandSkeleton.JointName]) {
            guard joints.count > 1 else { return }
            segments.append((.wrist, joints.first!))
            for index in joints.indices.dropFirst() {
                segments.append((joints[index - 1], joints[index]))
            }
        }

        appendFinger([
            .thumbKnuckle,
            .thumbIntermediateBase,
            .thumbIntermediateTip,
            .thumbTip
        ])

        appendFinger([
            .indexFingerKnuckle,
            .indexFingerIntermediateBase,
            .indexFingerIntermediateTip,
            .indexFingerTip
        ])

        appendFinger([
            .middleFingerKnuckle,
            .middleFingerIntermediateBase,
            .middleFingerIntermediateTip,
            .middleFingerTip
        ])

        appendFinger([
            .ringFingerKnuckle,
            .ringFingerIntermediateBase,
            .ringFingerIntermediateTip,
            .ringFingerTip
        ])

        appendFinger([
            .littleFingerKnuckle,
            .littleFingerIntermediateBase,
            .littleFingerIntermediateTip,
            .littleFingerTip
        ])

        segments.append((.wrist, .palm))
        return segments
    }()

    func installIfNeeded(into content: RealityViewContent) {
        guard isInstalled == false else { return }

        content.add(anchor)
        makeJointEntities()
        makeBoneEntities()

        isInstalled = true
    }

    func update(left: HandAnchor?, right: HandAnchor?) {
        updateHand(anchor: left, chirality: .left)
        updateHand(anchor: right, chirality: .right)
    }

    private func makeJointEntities() {
        let mesh = MeshResource.generateSphere(radius: jointRadius)

        for chirality in [HandAnchor.Chirality.left, .right] {
            let color: MaterialColorParameter = .init(tint: chirality == .left ? .cyan : .magenta)
            let material = SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)

            for jointName in jointNames {
                let entity = ModelEntity(mesh: mesh, materials: [material])
                entity.name = "\(chirality.label)-\(jointName.label)-joint"
                entity.isEnabled = false

                anchor.addChild(entity)
                jointEntities[JointKey(chirality: chirality, jointName: jointName)] = entity
            }
        }
    }

    private func makeBoneEntities() {
        let mesh = MeshResource.generateCylinder(height: 1.0, radius: boneRadius)

        for chirality in [HandAnchor.Chirality.left, .right] {
            let color: MaterialColorParameter = .init(tint: chirality == .left ? .blue : .red)
            let material = SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)

            for segment in boneSegments {
                let entity = ModelEntity(mesh: mesh, materials: [material])
                entity.name = "\(chirality.label)-\(segment.0.label)-\(segment.1.label)-bone"
                entity.isEnabled = false

                anchor.addChild(entity)
                boneEntities[BoneKey(chirality: chirality, start: segment.0, end: segment.1)] = entity
            }
        }
    }

    private func updateHand(anchor handAnchor: HandAnchor?, chirality: HandAnchor.Chirality) {
        guard let handAnchor else {
            setHandVisible(false, chirality: chirality)
            return
        }

        var activePositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]

        for jointName in jointNames {
            guard let position = worldPosition(for: jointName, anchor: handAnchor) else {
                jointEntities[JointKey(chirality: chirality, jointName: jointName)]?.isEnabled = false
                continue
            }

            activePositions[jointName] = position
            if let jointEntity = jointEntities[JointKey(chirality: chirality, jointName: jointName)] {
                jointEntity.isEnabled = true
                jointEntity.setTranslation(position, relativeTo: nil)
            }
        }

        for segment in boneSegments {
            let key = BoneKey(chirality: chirality, start: segment.0, end: segment.1)
            guard
                let startPosition = activePositions[segment.0],
                let endPosition = activePositions[segment.1],
                let boneEntity = boneEntities[key]
            else {
                boneEntities[key]?.isEnabled = false
                continue
            }

            let delta = endPosition - startPosition
            let length = simd_length(delta)

            guard length > 0.001 else {
                boneEntity.isEnabled = false
                continue
            }

            let midpoint = (startPosition + endPosition) * 0.5
            let orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
            var transform = Transform()
            transform.translation = midpoint
            transform.rotation = orientation
            transform.scale = SIMD3<Float>(repeating: 1)
            transform.scale.y = length

            boneEntity.transform = transform
            boneEntity.isEnabled = true
        }
    }

    private func setHandVisible(_ visible: Bool, chirality: HandAnchor.Chirality) {
        for jointName in jointNames {
            jointEntities[JointKey(chirality: chirality, jointName: jointName)]?.isEnabled = visible
        }
        for segment in boneSegments {
            boneEntities[BoneKey(chirality: chirality, start: segment.0, end: segment.1)]?.isEnabled = visible
        }
    }

    private func worldPosition(for joint: HandSkeleton.JointName, anchor: HandAnchor) -> SIMD3<Float>? {
        guard let joint = anchor.handSkeleton?.joint(joint), joint.isTracked else {
            return nil
        }

        let jointTransform = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
        return jointTransform.columns.3.xyz
    }
}

private struct JointKey: Hashable {
    let chirality: HandAnchor.Chirality
    let jointName: HandSkeleton.JointName
}

private struct BoneKey: Hashable {
    let chirality: HandAnchor.Chirality
    let start: HandSkeleton.JointName
    let end: HandSkeleton.JointName
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}

private extension HandAnchor.Chirality {
    var label: String { self == .left ? "left" : "right" }
}

private extension HandSkeleton.JointName {
    var label: String { String(describing: self) }
}
