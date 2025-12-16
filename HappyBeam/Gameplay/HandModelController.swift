import Foundation
import RealityKit
import simd

/// Responsible for loading the hand model(s), managing a root anchor, and applying per-frame joint transforms.
@MainActor
final class HandModelController: ObservableObject {
    let rootAnchor = AnchorEntity(world: .zero)

    // Camera orbit parameters (spherical)
    @Published var distance: Float = 0.6
    @Published var yaw: Float = 0
    @Published var pitch: Float = 0

    // The model entity (if any)
    private var handEntity: Entity?

    init() {
        // Optional: load a default hand model here or leave for explicit load.
    }

    func loadHandModel(from entity: Entity) {
        handEntity?.removeFromParent()
        handEntity = entity
        rootAnchor.addChild(entity)
    }

    // Apply a frame worth of joint transforms (poses are in world or model space depending on your data).
    func applyFrame(_ frame: HandPoseFrame, for handIsLeft: Bool) {
        // TODO: Map frame joint names to model node names and set transforms.
        // This is model-specific and needs the model's skeleton/node naming.
    }

    // MARK: - Gesture control API

    func handlePan(translation: CGSize) {
        // Convert to yaw/pitch deltas; tuning factors are arbitrary and should be adjusted.
        let dx = Float(translation.width) * 0.01
        let dy = Float(translation.height) * 0.01
        yaw += dx
        pitch = min(max(pitch + dy, -Float.pi / 2 + 0.1), Float.pi / 2 - 0.1)
        updateCamera()
    }

    func endPan() {
        // No-op for now
    }

    func handlePinch(scale: CGFloat) {
        distance = max(0.1, min(2.0, distance / Float(scale)))
        updateCamera()
    }

    func endPinch() {
        // No-op
    }

    private func updateCamera() {
        // In a full implementation we'd move a camera entity or adjust the view transform.
        // For RealityView-based scenes you can position a camera relative to rootAnchor.
    }
}
