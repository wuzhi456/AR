//
//  ImmersiveView.swift
//  ARCoach_demo
//
//  Created by Dvalab on 2025/10/28.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import UIKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @StateObject private var handTrackingModel = HandTrackingModel()

    var body: some View {
        RealityView { content in
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }

            // Prepare anchors that host joint visualizations for both hands.
            let leftHandAnchor = AnchorEntity()
            leftHandAnchor.name = EntityName.leftHandRoot
            content.add(leftHandAnchor)

            let rightHandAnchor = AnchorEntity()
            rightHandAnchor.name = EntityName.rightHandRoot
            content.add(rightHandAnchor)
        } update: { content in
            updateHandVisualization(content: content,
                                    anchor: handTrackingModel.latestHands.left,
                                    rootName: EntityName.leftHandRoot,
                                    jointColor: .cyan)

            updateHandVisualization(content: content,
                                    anchor: handTrackingModel.latestHands.right,
                                    rootName: EntityName.rightHandRoot,
                                    jointColor: .magenta)
        }
        .task { await handTrackingModel.start() }
        .task { await handTrackingModel.publishHandTrackingUpdates() }
        .task { await handTrackingModel.monitorSessionEvents() }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}

private extension ImmersiveView {
    enum EntityName {
        static let leftHandRoot = "LeftHandVisualization"
        static let rightHandRoot = "RightHandVisualization"
    }

    func updateHandVisualization(content: RealityViewContent,
                                 anchor: HandAnchor?,
                                 rootName: String,
                                 jointColor: UIColor) {
        guard let root = content.entities.first(where: { $0.name == rootName }) else { return }

        guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else {
            root.isEnabled = false
            return
        }

        root.isEnabled = true

        for jointName in HandSkeleton.JointName.allCases {
            let joint = skeleton.joint(jointName)
            let jointEntity = jointEntity(named: String(describing: jointName), under: root, color: jointColor)

            guard joint.isTracked else {
                jointEntity.isEnabled = false
                continue
            }

            jointEntity.isEnabled = true
            let worldTransform = matrix_multiply(anchor.originFromAnchorTransform, joint.anchorFromJointTransform)
            jointEntity.setTransformMatrix(worldTransform, relativeTo: nil)
        }
    }

    func jointEntity(named name: String, under root: Entity, color: UIColor) -> ModelEntity {
        if let existing = root.findEntity(named: name) as? ModelEntity {
            return existing
        }

        let mesh = MeshResource.generateSphere(radius: 0.005)
        let materialColor = SimpleMaterial.Color(Color(uiColor: color))
        let material = SimpleMaterial(color: materialColor, roughness: 0.15, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = name
        root.addChild(entity)
        return entity
    }
}
