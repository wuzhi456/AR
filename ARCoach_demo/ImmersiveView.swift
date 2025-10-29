import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import UIKit
import UniformTypeIdentifiers

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @StateObject private var handTrackingModel = HandTrackingModel()
    @StateObject private var captureManager = HandCaptureManager()
    @State private var isShowingFileImporter = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityView { content in
                let leftHandAnchor = AnchorEntity()
                leftHandAnchor.name = EntityName.leftHandRoot
                content.add(leftHandAnchor)

                let rightHandAnchor = AnchorEntity()
                rightHandAnchor.name = EntityName.rightHandRoot
                content.add(rightHandAnchor)
            } update: { content in
                if captureManager.isPlayingBack, let frame = captureManager.currentPlaybackFrame {
                    updateHandVisualization(content: content,
                                            joints: frame.left,
                                            rootName: EntityName.leftHandRoot,
                                            jointColor: .cyan)
                    updateHandVisualization(content: content,
                                            joints: frame.right,
                                            rootName: EntityName.rightHandRoot,
                                            jointColor: .magenta)
                } else {
                    let leftJoints = jointPoses(for: handTrackingModel.latestHands.left)
                    let rightJoints = jointPoses(for: handTrackingModel.latestHands.right)

                    updateHandVisualization(content: content,
                                            joints: leftJoints,
                                            rootName: EntityName.leftHandRoot,
                                            jointColor: .cyan)
                    updateHandVisualization(content: content,
                                            joints: rightJoints,
                                            rootName: EntityName.rightHandRoot,
                                            jointColor: .magenta)

                    captureManager.captureFrame(leftJoints: leftJoints, rightJoints: rightJoints)
                }
            }
            .task { await handTrackingModel.start() }
            .task { await handTrackingModel.publishHandTrackingUpdates() }
            .task { await handTrackingModel.monitorSessionEvents() }

            HandCaptureControlPanel(
                captureManager: captureManager,
                onToggleRecording: toggleRecording,
                onTogglePlayback: togglePlayback
            )
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.bottom, 40)
        }
        .fileImporter(isPresented: $isShowingFileImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    print("No file selected")
                    return
                }
                Task.detached(priority: .userInitiated) {
                    do {
                        let data = try Data(contentsOf: url)
                        let sequence = try JSONDecoder().decode(HandPoseSequence.self, from: data)
                        await captureManager.beginPlayback(with: sequence)
                    } catch {
                        // TODO: Surface error to user
                        print("加载回放文件失败: \(error)")
                    }
                }
            case .failure(let error):
                print("文件选择失败: \(error)")
            }
        }
    }

    private func toggleRecording() {
        if captureManager.isRecording {
            Task { await captureManager.stopRecordingAndSave() }
        } else {
            captureManager.startRecording()
        }
    }

    private func togglePlayback() {
        if captureManager.isPlayingBack {
            captureManager.stopPlayback()
        } else {
            isShowingFileImporter = true
        }
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

    func jointPoses(for anchor: HandAnchor?) -> [HandPoseSample.JointPose] {
        guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else { return [] }

        return HandSkeleton.JointName.allCases.compactMap { jointName in
            let joint = skeleton.joint(jointName)
            guard joint.isTracked else { return nil }
            let worldTransform = matrix_multiply(anchor.originFromAnchorTransform, joint.anchorFromJointTransform)
            return HandPoseSample.JointPose(name: String(describing: jointName), transform: worldTransform)
        }
    }

    func updateHandVisualization(content: RealityViewContent,
                                 joints: [HandPoseSample.JointPose],
                                 rootName: String,
                                 jointColor: UIColor) {
        guard let root = content.entities.first(where: { $0.name == rootName }) else { return }

        guard !joints.isEmpty else {
            root.isEnabled = false
            return
        }

        root.isEnabled = true
        var activeJointNames = Set<String>()

        for joint in joints {
            let jointEntity = jointEntity(named: joint.name, under: root, color: jointColor)
            jointEntity.isEnabled = true
            jointEntity.setTransformMatrix(joint.transformMatrix, relativeTo: nil)
            activeJointNames.insert(joint.name)
        }

        for child in root.children where !activeJointNames.contains(child.name) {
            child.isEnabled = false
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

struct HandCaptureControlPanel: View {
    @ObservedObject var captureManager: HandCaptureManager
    var onToggleRecording: () -> Void
    var onTogglePlayback: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(captureManager.isRecording ? "停止录制" : "开始录制") {
                onToggleRecording()
            }
            .buttonStyle(.borderedProminent)

            Button(captureManager.isPlayingBack ? "停止回溯" : "回溯") {
                onTogglePlayback()
            }
            .buttonStyle(.bordered)
        }
    }
}