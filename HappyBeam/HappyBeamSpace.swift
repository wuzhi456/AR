/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The space where the game takes place.
*/

import Accelerate
import AVKit
import Combine
import GameController
import RealityKit
import SwiftUI
import HappyBeamAssets
import ARKit

/// The Full Space that displays when someone plays the game.
struct HappyBeamSpace: View {
    @ObservedObject var gestureModel: HeartGestureModel
    @Environment(GameModel.self) var gameModel
    
    @State private var emittingBeam = false
    @State private var blasterPosition = Float(0)
    @State private var lastGestureUpdateTime: TimeInterval = 0
    @State private var draggedEntity: Entity? = nil
    @State private var positions: [SIMD3<Float>] = []
    @State private var orientations: [simd_quatf] = []
    @State private var collisionSubscription: EventSubscription?
    @State private var activationSubscription: EventSubscription?
    
    // Hand visualization state
    @State private var leftHandVisualization: HandVisualization?
    @State private var rightHandVisualization: HandVisualization?
    @State private var playbackLeftHandVisualization: HandVisualization?
    @State private var playbackRightHandVisualization: HandVisualization?
    @State private var practiceGhostVisualization: HandVisualization?
    @State private var practiceGhostFrameIndex: Int = 0
    
    // Recording/playback management
    @StateObject private var captureManager = HandCaptureManager()
    
    var collisionEntity = Entity()
    
    var body: some View {
        realityViewContent
            .gesture(dragGesture)
            .modifier(TasksModifier(
                gestureModel: gestureModel,
                handleGameModeStart: handleGameModeStart
            ))
            .modifier(NotificationModifier(
                startRecording: startRecording,
                stopRecording: stopRecording,
                saveRecording: saveRecording,
                discardRecording: discardRecording,
                startPlayback: startPlayback,
                pausePlayback: pausePlayback,
                stopPlayback: stopPlayback
            ))
            .onChange(of: gameModel.controllerLastInput) {
                gameControllerLoop()
            }
            .onChange(of: gameModel.isFinished) { _, isFinished in
                if isFinished {
                    handleGameEnd()
                }
            }
    }
    
    // MARK: - View Components
    
    private var realityViewContent: some View {
        RealityView { content in
            // The root entity.
            content.add(spaceOrigin)
            content.add(cameraRelativeAnchor)
            spaceOrigin.addChild(beamIntermediate)
            
            // Setup hand visualizations
            setupHandVisualizations(content: content)
            
            // MARK: Events
            activationSubscription = content.subscribe(to: AccessibilityEvents.Activate.self, on: nil, componentType: nil) { activation in
                Task {
                    try handleCloudHit(for: activation.entity, gameModel: gameModel)
                }
            }
            
            collisionSubscription = content.subscribe(to: CollisionEvents.Began.self, on: nil, componentType: nil) { event in
                Task {
                    try await handleCollisionStart(for: event, gameModel: gameModel)
                }
            }
            
            Task.detached {
                for await _ in NotificationCenter.default.notifications(named: .GCControllerDidConnect) {
                    Task { @MainActor in
                        for controller in GCController.controllers() {
                            controller.extendedGamepad?.valueChangedHandler = { pad, _ in
                                Task { @MainActor in
                                    if gameModel.isUsingControllerInput == false {
                                        gameModel.isUsingControllerInput = true
                                    }
                                    gameModel.controllerInputX = pad.leftThumbstick.xAxis.value
                                    gameModel.controllerInputY = pad.leftThumbstick.yAxis.value
                                    if gameModel.controllerInputX != 0, gameModel.controllerInputY != 0 {
                                        gameModel.controllerLastInput = Date.timeIntervalSinceReferenceDate
                                    }
                                }
                            }
                            
                            if controller.extendedGamepad == nil {
                                controller.microGamepad?.valueChangedHandler = { pad, _ in
                                    Task { @MainActor in
                                        if gameModel.isUsingControllerInput == false {
                                            gameModel.isUsingControllerInput = true
                                        }
                                        gameModel.controllerInputX = pad.dpad.xAxis.value
                                        gameModel.controllerInputY = pad.dpad.yAxis.value
                                        if gameModel.controllerInputX != 0, gameModel.controllerInputY != 0 {
                                            gameModel.controllerLastInput = Date.timeIntervalSinceReferenceDate
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } update: { updateContent in
            // Update hand visualizations based on game mode
            updateHandVisualizations()
            
            let handsCenterTransform = gestureModel.computeTransformOfUserPerformedHeartGesture()
            if let handsCenter = handsCenterTransform {
                let position = Pose3D(handsCenter)!.position
                let rotation = Pose3D(handsCenter)!.rotation
                
                // Rolling average window of N, ~2-30 frames
                vx1[wIndex] = rotation.vector.x
                vy1[wIndex] = rotation.vector.y
                vz1[wIndex] = rotation.vector.z
                vw1[wIndex] = rotation.vector.w
                
                let averageX = vDSP.mean(vx1)
                let averageY = vDSP.mean(vy1)
                let averageZ = vDSP.mean(vz1)
                let averageW = vDSP.mean(vw1)
                
                wIndex += 1
                wIndex %= windowSize
                
                beamIntermediate.transform.translation = SIMD3<Float>(position.vector)
                beamIntermediate.transform.rotation = simd_quatf(vector: [Float(averageX), Float(averageY), Float(averageZ), Float(averageW)])
                lastHeartDetectionTime = Date.timeIntervalSinceReferenceDate
                
                if gameModel.isSharePlaying {
                    sendBeamPositionUpdate(Pose3D(handsCenter)!)
                }
            }
            
            let shouldShowBeam = handsCenterTransform != nil
            if !gameModel.isPaused && gameModel.isPlaying {
                if shouldShowBeam {
                    if isShowingBeam == false {
                        beamIntermediate.addChild(beam)
                        startBlasterBeam(for: beam, beamType: .gesture)
                    }
                    isShowingBeam = true
                    
                } else if !shouldShowBeam && isShowingBeam == true {
                    if Date.timeIntervalSinceReferenceDate > lastHeartDetectionTime + 0.1 {
                        isShowingBeam = false
                        beamIntermediate.removeChild(beam)
                        endBlasterBeam()
                    }
                }
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0)
            .targetedToAnyEntity()
            .onChanged { @MainActor drag in
                let entity = drag.entity
                guard entity[parentMatching: "Heart Projector"] != nil else { return }
                
                if draggedEntity == nil || emittingBeam == false {
                    draggedEntity = entity
                    emittingBeam = true
                    startBlasterBeam(for: entity, beamType: .turret)
                }
                
                emittingBeam = !gameModel.isPaused
                
                if !isFloorBeamShowing && !gameModel.isPaused && gameModel.isPlaying {
                    entity.addChild(floorBeam)
                    
                    floorBeam.orientation = simd_quatf(
                        Rotation3D(angle: .degrees(90), axis: .z)
                            .rotated(by: .init(angle: .degrees(180), axis: .y))
                    )
                    
                    isFloorBeamShowing = true
                }
                
                // Slow the rotation down.
                let dragPoint = Point3D(drag.gestureValue.translation3D.vector) / 300
                let zRotation = (-180 * (dragPoint.x)).clamped(to: -90...90)
                let yRotation = (-180 * (dragPoint.y)).clamped(to: -90...90)
            
                let newOrientation = Rotation3D(angle: .degrees(Double(zRotation)), axis: .z)
                    .rotated(
                        by: .init(angle: .degrees(Double(yRotation)), axis: .x)
                    )
                
                entity.orientation = simd_quatf(newOrientation)
                
                if gameModel.isSharePlaying {
                    sendBeamPositionUpdate(Pose3D(entity.transform.matrix)!)
                }
            }
            .onEnded { dragEnd in
                if !gameModel.isPaused {
                    floorBeam.removeFromParent()
                    isFloorBeamShowing = false
                    globalHeart?.children[0].transform.rotation = .init()
                }
                endBlasterBeam()
            }
    }
    
    // MARK: - Hand Visualization Setup
    
    private func setupHandVisualizations(content: RealityViewContent) {
        // Create hand visualizations for recording mode (user's hands)
        let leftVis = HandVisualization(name: "LeftHandVisualization", jointColor: .cyan, boneColor: .white)
        let rightVis = HandVisualization(name: "RightHandVisualization", jointColor: .magenta, boneColor: .white)
        
        // Create hand visualizations for playback mode (recorded hands - different color)
        let playbackLeftVis = HandVisualization(name: "PlaybackLeftHandVisualization", jointColor: .green, boneColor: .yellow)
        let playbackRightVis = HandVisualization(name: "PlaybackRightHandVisualization", jointColor: .orange, boneColor: .yellow)

        // Practice ghost visualization (default red/yellow, rendered on top for clarity)
        let practiceGhost = HandVisualization(name: "PracticeGhostVisualization", jointColor: .red.withAlphaComponent(0.7), boneColor: .red.withAlphaComponent(0.5), renderOnTop: true)
        
        content.add(leftVis.rootEntity)
        content.add(rightVis.rootEntity)
        content.add(playbackLeftVis.rootEntity)
        content.add(playbackRightVis.rootEntity)
        content.add(practiceGhost.rootEntity)
        
        // Initially hide all visualizations
        leftVis.rootEntity.isEnabled = false
        rightVis.rootEntity.isEnabled = false
        playbackLeftVis.rootEntity.isEnabled = false
        playbackRightVis.rootEntity.isEnabled = false
        practiceGhost.rootEntity.isEnabled = false
        
        leftHandVisualization = leftVis
        rightHandVisualization = rightVis
        playbackLeftHandVisualization = playbackLeftVis
        playbackRightHandVisualization = playbackRightVis
        practiceGhostVisualization = practiceGhost
    }
    
    // MARK: - Hand Visualization Update
    
    private func updateHandVisualizations() {
        // For recording, playback, and practice modes, always show hand visualization regardless of isPaused
        guard gameModel.isPlaying else {
            leftHandVisualization?.clear()
            rightHandVisualization?.clear()
            playbackLeftHandVisualization?.clear()
            playbackRightHandVisualization?.clear()
            return
        }
        
        let leftJoints = extractJointPoses(from: gestureModel.latestHandTracking.left)
        let rightJoints = extractJointPoses(from: gestureModel.latestHandTracking.right)
        
        switch gameModel.soloGameMode {
        case .normal:
            // Normal mode: no hand visualization
            leftHandVisualization?.clear()
            rightHandVisualization?.clear()
            playbackLeftHandVisualization?.clear()
            playbackRightHandVisualization?.clear()
            
        case .recording:
            // Recording mode: always show user's hands
            leftHandVisualization?.update(with: leftJoints)
            rightHandVisualization?.update(with: rightJoints)
            playbackLeftHandVisualization?.clear()
            playbackRightHandVisualization?.clear()
            
            // Only capture frame when actively recording (user has pressed start)
            if gameModel.isActivelyRecording {
                captureManager.captureFrame(leftJoints: leftJoints, rightJoints: rightJoints)
                // Update elapsed time in game model
                gameModel.recordingElapsedTime = captureManager.recordingElapsedTime
            }
            
        case .playback:
            // Playback mode: show playback hands only (not user's hands)
            leftHandVisualization?.clear()
            rightHandVisualization?.clear()
            practiceGhostVisualization?.clear()
            
            // Update playback visualization only when actively playing
            if gameModel.isActivelyPlayingBack, let frame = captureManager.currentPlaybackFrame {
                playbackLeftHandVisualization?.update(with: frame.leftJoints)
                playbackRightHandVisualization?.update(with: frame.rightJoints)
                // Update elapsed time in game model
                gameModel.playbackElapsedTime = captureManager.playbackElapsedTime
            } else if !gameModel.isActivelyPlayingBack {
                // When paused or stopped, keep showing the current frame if available
                if let frame = captureManager.currentPlaybackFrame {
                    playbackLeftHandVisualization?.update(with: frame.leftJoints)
                    playbackRightHandVisualization?.update(with: frame.rightJoints)
                } else {
                    playbackLeftHandVisualization?.clear()
                    playbackRightHandVisualization?.clear()
                }
            }

        case .practice:
            // Practice mode: render a ghost hand from the coach recording and gate playback by user proximity.
            leftHandVisualization?.clear()
            rightHandVisualization?.clear()
            playbackLeftHandVisualization?.clear()
            playbackRightHandVisualization?.clear()
            updatePracticeGhost()
        }
    }

    private func updatePracticeGhost() {
        guard let recording = gameModel.practiceRecording,
              !recording.frames.isEmpty,
              let ghost = practiceGhostVisualization else {
            practiceGhostVisualization?.clear()
            return
        }
        // Clamp frame index
        practiceGhostFrameIndex = min(max(practiceGhostFrameIndex, 0), recording.frames.count - 1)
        let frame = recording.frames[practiceGhostFrameIndex]
        let joints = gameModel.practiceHand == .left ? frame.leftJoints : frame.rightJoints
        ghost.update(with: joints, interpolateMissing: true)
        ghost.rootEntity.isEnabled = true
    // Track elapsed time using frame timestamp
    gameModel.playbackElapsedTime = frame.timestamp
        
        // Use wrist (or fallback) as anchor for proximity check
        guard let userAnchor = referencePoint(from: gameModel.practiceHand),
              let ghostAnchor = referencePoint(from: joints) else {
            // No reference joints; keep ghost red and paused
            ghost.setColors(jointColor: .red.withAlphaComponent(0.7), boneColor: .red.withAlphaComponent(0.5))
            return
        }
        let distance = simd_distance(userAnchor, ghostAnchor)
        let threshold: Float = 0.15 // 15 cm
        if distance < threshold {
            // Close enough: turn green and advance a frame (bounded)
            ghost.setColors(jointColor: .green.withAlphaComponent(0.8), boneColor: .green.withAlphaComponent(0.6))
            if practiceGhostFrameIndex < recording.frames.count - 1 {
                practiceGhostFrameIndex += 1
            }
        } else {
            // Too far: stay red and pause
            ghost.setColors(jointColor: .red.withAlphaComponent(0.7), boneColor: .red.withAlphaComponent(0.5))
        }
    }

    private func referencePoint(from joints: [HandJointPose]) -> SIMD3<Float>? {
        // Prefer wrist; fallback to index knuckle; then first joint
        if let wrist = joints.first(where: { $0.name == "wrist" }) {
            return SIMD3<Float>(wrist.position[0], wrist.position[1], wrist.position[2])
        }
        if let indexKnuckle = joints.first(where: { $0.name.contains("indexFingerKnuckle") || $0.name == "indexFingerMCP" }) {
            return SIMD3<Float>(indexKnuckle.position[0], indexKnuckle.position[1], indexKnuckle.position[2])
        }
        if let first = joints.first {
            return SIMD3<Float>(first.position[0], first.position[1], first.position[2])
        }
        return nil
    }
    
    private func referencePoint(from hand: PracticeHand) -> SIMD3<Float>? {
        let joints = hand == .left ? extractJointPoses(from: gestureModel.latestHandTracking.left) : extractJointPoses(from: gestureModel.latestHandTracking.right)
        return referencePoint(from: joints)
    }
    
    // MARK: - Game Mode Handling
    
    /// Handles the start of the game based on the selected game mode.
    /// Normal mode requires no additional setup; recording and playback modes wait for user input.
    private func handleGameModeStart() async {
        switch gameModel.soloGameMode {
        case .normal:
            // Normal mode: no special initialization needed
            break
            
        case .recording:
            // Recording mode: wait for user to press start button
            // Do not auto-start recording
            break
            
        case .playback:
            // Playback mode: set up duration but wait for user to start
            if let recording = gameModel.playbackRecording {
                // Calculate total duration from recording
                if let lastFrame = recording.frames.last {
                    gameModel.playbackTotalDuration = lastFrame.timestamp
                }
            } else {
                gameModel.playbackTotalDuration = 0
            }
            // Do not auto-start playback

        case .practice:
            // Practice mode: derive duration from coach recording
            if let recording = gameModel.practiceRecording {
                if let lastFrame = recording.frames.last {
                    gameModel.playbackTotalDuration = lastFrame.timestamp
                }
            } else {
                gameModel.playbackTotalDuration = 0
            }
            practiceGhostFrameIndex = 0
        }
    }
    
    // MARK: - Recording Control Methods
    
    private func startRecording() {
        captureManager.startRecording()
        gameModel.isActivelyRecording = true
        gameModel.hasUnsavedRecording = false
    }
    
    private func stopRecording() {
        captureManager.stopRecording()
        gameModel.isActivelyRecording = false
        gameModel.hasUnsavedRecording = captureManager.hasUnsavedRecording
    }
    
    private func saveRecording() {
        Task {
            await captureManager.saveRecording()
            gameModel.hasUnsavedRecording = false
            gameModel.recordingElapsedTime = 0
        }
    }
    
    private func discardRecording() {
        captureManager.discardRecording()
        gameModel.hasUnsavedRecording = false
        gameModel.recordingElapsedTime = 0
    }
    
    // MARK: - Playback Control Methods
    
    private func startPlayback() {
        if gameModel.soloGameMode == .practice {
            // Manual, proximity-gated playback handled in updatePracticeGhost
            gameModel.isActivelyPlayingBack = true
            practiceGhostFrameIndex = 0
        } else {
            let recording = gameModel.playbackRecording
            if let recording {
                captureManager.startOrResumePlayback(with: recording)
                gameModel.isActivelyPlayingBack = true
            }
        }
    }
    
    private func pausePlayback() {
        if gameModel.soloGameMode == .practice {
            gameModel.isActivelyPlayingBack = false
        } else {
            captureManager.pausePlayback()
            gameModel.isActivelyPlayingBack = false
        }
    }
    
    private func stopPlayback() {
        if gameModel.soloGameMode == .practice {
            gameModel.isActivelyPlayingBack = false
            gameModel.playbackElapsedTime = 0
            practiceGhostFrameIndex = 0
        } else {
            captureManager.stopPlayback()
            gameModel.isActivelyPlayingBack = false
            gameModel.playbackElapsedTime = 0
        }
    }
    
    private func handleGameEnd() {
        switch gameModel.soloGameMode {
        case .normal:
            // Normal mode: no cleanup needed
            break
            
        case .recording:
            // Stop recording if active, but don't auto-save - let user decide
            if gameModel.isActivelyRecording {
                stopRecording()
            }
            
        case .playback:
            captureManager.stopPlayback()
            gameModel.isActivelyPlayingBack = false

        case .practice:
            gameModel.isActivelyPlayingBack = false
            practiceGhostFrameIndex = 0
        }
        
        // Clear all visualizations
        leftHandVisualization?.clear()
        rightHandVisualization?.clear()
        playbackLeftHandVisualization?.clear()
        playbackRightHandVisualization?.clear()
    }
    
    // Send each player's beam data during FaceTime calls that are spatial.
    func sendBeamPositionUpdate(_ pose: Pose3D) {
        if let sessionInfo = sessionInfo, let session = sessionInfo.session, let messenger = sessionInfo.messenger {
            let everyoneElse = session.activeParticipants.subtracting([session.localParticipant])
            
            if isShowingBeam, gameModel.isSpatial {
                messenger.send(BeamMessage(pose: pose), to: .only(everyoneElse)) { error in
                    if let error = error { print("Message failure:", error) }
                }
            }
        }
    }
    
    /// Stops showing the animated beam.
    @MainActor
    func endBlasterBeam() {
        Task.detached { @MainActor in
            emittingBeam = false
            if let collision = draggedEntity?.findEntity(named: collisionEntityName) {
                collision.removeFromParent()
            }
            draggedEntity = nil
        }
    }
    
    /// Displays the beam and starts its animation and moving collision entity.
    @MainActor
    func startBlasterBeam(for entity: Entity, beamType: BeamType) {
        Task() { @MainActor in
            lastGestureUpdateTime = Date.timeIntervalSinceReferenceDate
            emittingBeam = true
            draggedEntity = entity
            while emittingBeam == true {
                let elapsedTime = Date.timeIntervalSinceReferenceDate - lastGestureUpdateTime
                
                collisionEntity.removeFromParent()
                collisionEntity.name = collisionEntityName
                var root = entity
                while root.parent != nil {
                    if let parent = root.parent {
                        root = parent
                    }
                }

                root.addChild(collisionEntity)
                if collisionEntity.components[CollisionComponent.self] == nil {
                    let radius = (beamType == .turret) ? Float(0.1) : Float(0.5)
                    let collisionShape = ShapeResource.generateSphere(radius: radius)
                    let collisionComp = CollisionComponent(shapes: [collisionShape])
                    collisionEntity.components.set(collisionComp)
                }
                
                blasterPosition += Float(elapsedTime) * 1.5
                blasterPosition -= floorf(blasterPosition)
                entity.setMaterialParameterValues(parameter: HappyBeamAssets.beamPositionParameterName, value: .float(blasterPosition))
                let offset: Float = (beamType == .turret) ? 23 : 1400
                let offsetVector: SIMD3<Float> = (beamType == .turret)
                    ? [0, 1, 0] * offset * blasterPosition
                    : [1, 0, 0] * offset * blasterPosition
                
                collisionEntity.setPosition(offsetVector, relativeTo: entity)

                lastGestureUpdateTime = Date.timeIntervalSinceReferenceDate
                try? await Task.sleep(for: .milliseconds(66.666_666))
            }
            collisionEntity.removeFromParent()
        }
    }
    
    /// Continously updates the beam position in response to input from a game controller.
    @MainActor
    func gameControllerLoop() {
        Task { @MainActor in
            #if targetEnvironment(simulator)
            let speed: Float = 0.4
            #else
            let speed: Float = 0.7
            #endif
            gameModel.controllerX += gameModel.controllerInputX * speed
            gameModel.controllerY -= gameModel.controllerInputY * speed
            
            let heart = globalHeart!
            if !isFloorBeamShowing && (gameModel.controllerInputX != 0.0 || gameModel.controllerInputX != 0.0) {
                heart.addChild(floorBeam)
                emittingBeam = true
                startBlasterBeam(for: heart, beamType: .turret)
                floorBeam.orientation = simd_quatf(
                    Rotation3D(angle: .degrees(90), axis: .z)
                        .rotated(by: .init(angle: .degrees(180), axis: .y))
                )
                isFloorBeamShowing = true
            }
            
            heart.orientation = simd_quatf(
                Rotation3D(angle: .degrees(Double(-gameModel.controllerX)), axis: .z)
                    .rotated(by: .init(angle: .degrees(Double(-gameModel.controllerY)), axis: .x))
            )
            
            if let timer = gameModel.controllerDismissTimer {
                timer.invalidate()
            }

            gameModel.controllerDismissTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                Task { @MainActor in
                    heart.removeChild(floorBeam)
                    isFloorBeamShowing = false
                    endBlasterBeam()
                }
            }
        }
    }
}

// Storage for the rolling average of the beam's rotation during hand gestures.
var windowSize = 24
var vx1: [Double] = .init(repeating: 0, count: windowSize)
var vy1: [Double] = .init(repeating: 0, count: windowSize)
var vz1: [Double] = .init(repeating: 0, count: windowSize)
var vw1: [Double] = .init(repeating: 0, count: windowSize)
var wIndex = 0

let collisionEntityName = "movingCollider"

enum BeamType {
    case turret
    case gesture
}

var isShowingBeam = false {
    didSet {
        if oldValue != isShowingBeam {
            AccessibilityNotification.Announcement(isShowingBeam ? String(localized: "Casting beam") : String(localized: "Hiding beam")).post()
        }
    }
}

var lastHeartDetectionTime = Date.timeIntervalSinceReferenceDate

/// Adds the purple base and golden heart models when someone picks an input mode that requires them.
@MainActor
func addFloorBeamMaterials() async throws {
    guard
        let turret = turret,
        let heart = heart
    else {
        fatalError("Required assets are nil.")
    }
    
    globalHeart = heart
    spaceOrigin.addChild(turret)
    spaceOrigin.addChild(heart)
}

/// Loads assets from the local HappyBeamAssets package.
@MainActor
func loadFromRealityComposerPro(named entityName: String, fromSceneNamed sceneName: String) async -> Entity? {
    var entity: Entity? = nil
    do {
        let scene = try await Entity(named: sceneName, in: happyBeamAssetsBundle)
        entity = scene.findEntity(named: entityName)
    } catch {
        print("Error loading \(entityName) from scene \(sceneName): \(error.localizedDescription)")
    }
    return entity
}

/// Checks whether a collision event contains one of a list of named entities.
func eventHasTargets(event: CollisionEvents.Began, matching names: [String]) -> Entity? {
    for targetName in names {
        if let target = eventHasTarget(event: event, matching: targetName) {
            return target
        }
    }
    return nil
}

/// Checks whether a collision event contains an entity that matches the name you supply.
func eventHasTarget(event: CollisionEvents.Began, matching targetName: String) -> Entity? {
    let aParentBeam = event.entityA[parentMatching: targetName]
    let aChildBeam = event.entityA[descendentMatching: targetName]
    let bParentBeam = event.entityB[parentMatching: targetName]
    let bChildBeam = event.entityB[descendentMatching: targetName]
    
    if aParentBeam == nil && aChildBeam == nil && bParentBeam == nil && bChildBeam == nil {
        return nil
    }
    
    var beam: Entity?
    if aParentBeam != nil || aChildBeam != nil {
        beam = (aParentBeam == nil) ? aChildBeam : aParentBeam
    } else if bParentBeam != nil || bChildBeam != nil {
        beam = (bParentBeam == nil) ? bChildBeam : bParentBeam
    }
    
    return beam
}

// MARK: - View Modifiers for Type-Checking

/// View modifier that groups async tasks to help Swift's type checker.
struct TasksModifier: ViewModifier {
    @ObservedObject var gestureModel: HeartGestureModel
    var handleGameModeStart: () async -> Void
    
    func body(content: Content) -> some View {
        content
            .task {
                await gestureModel.start()
            }
            .task {
                await gestureModel.publishHandTrackingUpdates()
            }
            .task {
                await gestureModel.monitorSessionEvents()
            }
            .task {
                await handleGameModeStart()
            }
    }
}

/// View modifier that groups notification observers to help Swift's type checker.
struct NotificationModifier: ViewModifier {
    var startRecording: () -> Void
    var stopRecording: () -> Void
    var saveRecording: () -> Void
    var discardRecording: () -> Void
    var startPlayback: () -> Void
    var pausePlayback: () -> Void
    var stopPlayback: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .startRecordingRequested)) { _ in
                startRecording()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopRecordingRequested)) { _ in
                stopRecording()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveRecordingRequested)) { _ in
                saveRecording()
            }
            .onReceive(NotificationCenter.default.publisher(for: .discardRecordingRequested)) { _ in
                discardRecording()
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPlaybackRequested)) { _ in
                startPlayback()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pausePlaybackRequested)) { _ in
                pausePlayback()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopPlaybackRequested)) { _ in
                stopPlayback()
            }
    }
}
