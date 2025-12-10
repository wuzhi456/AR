/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Visual representation of hand joints and bones using spheres and cylinders.
*/

import RealityKit
import UIKit

/// Manages the visual representation of hands with spheres for joints and cylinders for bones.
@MainActor
class HandVisualization {
    private var jointEntities: [String: ModelEntity] = [:]
    private var boneEntities: [String: ModelEntity] = [:]
    
    private let jointRadius: Float = 0.005
    private let boneRadius: Float = 0.003
    private let jointColor: UIColor
    private let boneColor: UIColor
    
    let rootEntity: Entity
    
    init(name: String, jointColor: UIColor = .cyan, boneColor: UIColor = .white) {
        self.rootEntity = Entity()
        self.rootEntity.name = name
        self.jointColor = jointColor
        self.boneColor = boneColor
    }
    
    /// Updates the visualization with new joint poses.
    func update(with joints: [HandJointPose]) {
        guard !joints.isEmpty else {
            rootEntity.isEnabled = false
            return
        }
        
        rootEntity.isEnabled = true
        var activeJointNames = Set<String>()
        
        // Create a dictionary for quick joint lookup
        var jointDict: [String: HandJointPose] = [:]
        for joint in joints {
            jointDict[joint.name] = joint
        }
        
        // Update joint spheres
        for joint in joints {
            let jointEntity = getOrCreateJointEntity(named: joint.name)
            jointEntity.isEnabled = true
            jointEntity.setTransformMatrix(joint.transformMatrix, relativeTo: nil)
            activeJointNames.insert(joint.name)
        }
        
        // Update bone cylinders
        for connection in HandBoneConnection.allConnections {
            guard let startJoint = jointDict[connection.startJoint],
                  let endJoint = jointDict[connection.endJoint] else {
                continue
            }
            
            let boneName = "\(connection.startJoint)-\(connection.endJoint)"
            let boneEntity = getOrCreateBoneEntity(named: boneName)
            boneEntity.isEnabled = true
            
            updateBoneTransform(
                entity: boneEntity,
                from: startJoint.positionVector,
                to: endJoint.positionVector
            )
        }
        
        // Disable unused joint entities
        for (name, entity) in jointEntities where !activeJointNames.contains(name) {
            entity.isEnabled = false
        }
    }
    
    /// Clears all visualization entities.
    func clear() {
        rootEntity.isEnabled = false
        for entity in jointEntities.values {
            entity.isEnabled = false
        }
        for entity in boneEntities.values {
            entity.isEnabled = false
        }
    }
    
    private func getOrCreateJointEntity(named name: String) -> ModelEntity {
        if let existing = jointEntities[name] {
            return existing
        }
        
        let mesh = MeshResource.generateSphere(radius: jointRadius)
        let material = SimpleMaterial(color: SimpleMaterial.Color(Color(uiColor: jointColor)), roughness: 0.15, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "joint-\(name)"
        rootEntity.addChild(entity)
        jointEntities[name] = entity
        return entity
    }
    
    private func getOrCreateBoneEntity(named name: String) -> ModelEntity {
        if let existing = boneEntities[name] {
            return existing
        }
        
        // Create a unit cylinder that will be scaled and positioned for each bone
        let mesh = MeshResource.generateCylinder(height: 1.0, radius: boneRadius)
        let material = SimpleMaterial(color: SimpleMaterial.Color(Color(uiColor: boneColor)), roughness: 0.15, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "bone-\(name)"
        rootEntity.addChild(entity)
        boneEntities[name] = entity
        return entity
    }
    
    private func updateBoneTransform(entity: ModelEntity, from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let direction = end - start
        let length = simd_length(direction)
        
        guard length > 0.0001 else {
            entity.isEnabled = false
            return
        }
        
        // Position at midpoint
        let midpoint = (start + end) / 2
        entity.position = midpoint
        
        // Scale to match bone length
        entity.scale = SIMD3<Float>(1, length, 1)
        
        // Rotate to align with bone direction
        let up = SIMD3<Float>(0, 1, 0)
        let normalizedDirection = simd_normalize(direction)
        
        if abs(simd_dot(up, normalizedDirection)) < 0.999 {
            let rotationAxis = simd_normalize(simd_cross(up, normalizedDirection))
            let angle = acos(simd_dot(up, normalizedDirection))
            entity.orientation = simd_quatf(angle: angle, axis: rotationAxis)
        } else if simd_dot(up, normalizedDirection) < 0 {
            // Pointing down, rotate 180 degrees
            entity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        } else {
            // Pointing up, no rotation needed
            entity.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
    }
}
