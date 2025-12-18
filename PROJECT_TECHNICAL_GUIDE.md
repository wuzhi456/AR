# ARCoach 项目技术详解

本文档详细解答项目的核心技术问题，包括关节识别、数据记录与存储、回放机制、手部模型显示以及 SwiftUI 关键语法的应用。

---

## 目录

1. [关节识别机制](#1-关节识别机制)
2. [关节信息的记录](#2-关节信息的记录)
3. [数据存储位置与格式](#3-数据存储位置与格式)
4. [Playback 时的数据调用](#4-playback-时的数据调用)
5. [手部模型的显示机制](#5-手部模型的显示机制)
6. [记录时的随时终止实现](#6-记录时的随时终止实现)
7. [Playback 时的暂停与重播实现](#7-playback-时的暂停与重播实现)
8. [SwiftUI 关键语法应用](#8-swiftui-关键语法应用)

---

## 1. 关节识别机制

### 1.1 如何识别关节

项目使用 Apple Vision Pro 的 ARKit 框架中的 `HandTrackingProvider` 来识别手部关节。

#### 核心组件：HeartGestureModel

```swift
// 位置: HappyBeam/Gameplay/HeartGestureModel.swift

@MainActor
class HeartGestureModel: ObservableObject, @unchecked Sendable {
    let session = ARKitSession()
    var handTracking = HandTrackingProvider()
    @Published var latestHandTracking: HandsUpdates = .init(left: nil, right: nil)
    
    // 启动 ARKit 会话
    func start() async {
        do {
            if HandTrackingProvider.isSupported {
                print("ARKitSession starting.")
                try await session.run([handTracking])
            }
        } catch {
            print("ARKitSession error:", error)
        }
    }
    
    // 持续监听手部追踪更新
    func publishHandTrackingUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .updated:
                let anchor = update.anchor
                guard anchor.isTracked else { continue }
                
                // 更新左手信息
                if anchor.chirality == .left {
                    latestHandTracking.left = anchor
                } else if anchor.chirality == .right {
                    latestHandTracking.right = anchor
                }
            default:
                break
            }
        }
    }
}
```

**关键点解析：**
- `ARKitSession` 是 ARKit 的核心会话对象，负责管理追踪任务
- `HandTrackingProvider` 专门用于手部追踪，提供实时的 `HandAnchor` 数据
- `anchorUpdates` 是一个异步序列 (AsyncSequence)，持续发送手部位置更新
- `chirality` 属性区分左手 (`.left`) 和右手 (`.right`)

### 1.2 识别哪些关节

项目追踪的是 Apple ARKit 定义的 **26 个手部关节**，这些关节定义在 `HandSkeleton.JointName` 枚举中：

```swift
// Apple 系统定义的 26 个关节名称
public enum JointName: Sendable, CaseIterable {
    // 手腕
    case wrist
    
    // 拇指 (4个关节)
    case thumbKnuckle
    case thumbIntermediateBase
    case thumbIntermediateTip
    case thumbTip
    
    // 食指 (5个关节)
    case indexFingerMetacarpal
    case indexFingerKnuckle
    case indexFingerIntermediateBase
    case indexFingerIntermediateTip
    case indexFingerTip
    
    // 中指 (5个关节)
    case middleFingerMetacarpal
    case middleFingerKnuckle
    case middleFingerIntermediateBase
    case middleFingerIntermediateTip
    case middleFingerTip
    
    // 无名指 (5个关节)
    case ringFingerMetacarpal
    case ringFingerKnuckle
    case ringFingerIntermediateBase
    case ringFingerIntermediateTip
    case ringFingerTip
    
    // 小指 (5个关节)
    case littleFingerMetacarpal
    case littleFingerKnuckle
    case littleFingerIntermediateBase
    case littleFingerIntermediateTip
    case littleFingerTip
    
    // 前臂参考点 (2个)
    case forearmWrist
    case forearmArm
}
```

### 1.3 关节提取函数

项目中的关节数据提取通过以下函数实现：

```swift
// 位置: HappyBeam/Gameplay/HandPoseData.swift

/// 从 HandAnchor 中提取所有关节姿态
@MainActor
func extractJointPoses(from anchor: HandAnchor?) -> [HandJointPose] {
    guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else { return [] }
    
    return HandSkeleton.JointName.allCases.compactMap { jointName in
        let joint = skeleton.joint(jointName)
        // 计算世界坐标系下的变换矩阵
        let worldTransform = matrix_multiply(
            anchor.originFromAnchorTransform,  // 锚点到世界坐标系的变换
            joint.anchorFromJointTransform      // 关节到锚点的变换
        )
        return HandJointPose(name: String(describing: jointName), transform: worldTransform)
    }
}
```

**坐标变换详解：**
- `anchor.originFromAnchorTransform`：将锚点坐标转换为世界坐标的 4x4 变换矩阵
- `joint.anchorFromJointTransform`：将关节局部坐标转换为锚点坐标的 4x4 变换矩阵
- `matrix_multiply`：矩阵乘法，组合两个变换得到最终的世界坐标变换

---

## 2. 关节信息的记录

### 2.1 数据模型定义

```swift
// 位置: HappyBeam/Gameplay/HandPoseData.swift

/// 单个关节的姿态数据
struct HandJointPose: Codable, Sendable {
    let name: String           // 关节名称
    let position: [Float]      // 位置 [x, y, z]
    let orientation: [Float]   // 四元数旋转 [x, y, z, w]
    
    init(name: String, transform: simd_float4x4) {
        self.name = name
        // 从变换矩阵中提取平移分量
        let translation = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        // 从变换矩阵中提取旋转四元数
        let rotation = simd_quaternion(transform)
        self.position = [translation.x, translation.y, translation.z]
        self.orientation = [rotation.imag.x, rotation.imag.y, rotation.imag.z, rotation.real]
    }
}

/// 单帧手部姿态数据（包含左右手）
struct HandPoseFrame: Codable, Sendable {
    let timestamp: TimeInterval    // 相对于录制开始的时间戳
    let leftJoints: [HandJointPose]   // 左手所有关节
    let rightJoints: [HandJointPose]  // 右手所有关节
}

/// 完整的录制数据
struct HandPoseRecording: Codable, Sendable {
    let version: Int         // 数据版本号
    let createdAt: Date      // 创建时间
    let frames: [HandPoseFrame]  // 帧序列
}
```

### 2.2 记录管理器：HandCaptureManager

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

@MainActor
final class HandCaptureManager: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordingElapsedTime: TimeInterval = 0
    
    private var frames: [HandPoseFrame] = []       // 存储捕获的帧
    private var recordingStart: TimeInterval = 0   // 录制开始时间
    
    /// 开始录制
    func startRecording() {
        frames.removeAll()
        recordingStart = CACurrentMediaTime()  // 获取高精度时间戳
        recordingElapsedTime = 0
        isRecording = true
        
        // 启动计时器更新已录制时间
        elapsedTimeTask = Task {
            while !Task.isCancelled && isRecording {
                await MainActor.run {
                    self.recordingElapsedTime = CACurrentMediaTime() - self.recordingStart
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 每100ms更新一次
            }
        }
    }
    
    /// 捕获单帧数据
    func captureFrame(leftJoints: [HandJointPose], rightJoints: [HandJointPose]) {
        guard isRecording else { return }
        guard !leftJoints.isEmpty || !rightJoints.isEmpty else { return }
        
        let timestamp = CACurrentMediaTime()
        let relativeTime = timestamp - recordingStart  // 计算相对时间戳
        let frame = HandPoseFrame(
            timestamp: relativeTime,
            leftJoints: leftJoints,
            rightJoints: rightJoints
        )
        frames.append(frame)
    }
}
```

### 2.3 帧捕获的调用位置

帧捕获在 `HappyBeamSpace.swift` 的 `updateHandVisualizations()` 方法中被调用：

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

private func updateHandVisualizations() {
    // ... 其他代码 ...
    
    switch gameModel.soloGameMode {
    case .recording:
        // 提取当前帧的关节数据
        let leftJoints = extractJointPoses(from: gestureModel.latestHandTracking.left)
        let rightJoints = extractJointPoses(from: gestureModel.latestHandTracking.right)
        
        // 更新手部可视化
        leftHandVisualization?.update(with: leftJoints)
        rightHandVisualization?.update(with: rightJoints)
        
        // 只有在用户主动录制时才捕获帧
        if gameModel.isActivelyRecording {
            captureManager.captureFrame(leftJoints: leftJoints, rightJoints: rightJoints)
            gameModel.recordingElapsedTime = captureManager.recordingElapsedTime
        }
    // ... 其他模式 ...
    }
}
```

---

## 3. 数据存储位置与格式

### 3.1 存储位置

数据存储在应用的 **Documents 目录** 中：

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

func saveRecording() async {
    let recording = HandPoseRecording(frames: frames)
    
    // 获取 Documents 目录
    guard let directory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first else {
        print("Failed to get documents directory")
        return
    }
    
    // 生成文件名（包含时间戳）
    let filename = "HandPose_\(Self.filenameFormatter.string(from: Date())).json"
    let url = directory.appendingPathComponent(filename)
    
    // 编码并写入文件
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(recording)
    try data.write(to: url, options: .atomic)
}
```

**存储路径示例：**
```
/var/mobile/Containers/Data/Application/<UUID>/Documents/HandPose_<yyyyMMdd_HHmmss>.json
```

文件名格式由 `DateFormatter` 定义：`"yyyyMMdd_HHmmss"`，例如：`HandPose_20250101_120000.json`

### 3.2 JSON 数据格式

```json
{
    "version": 1,
    "createdAt": "2025-01-01T12:00:00Z",
    "frames": [
        {
            "timestamp": 0.0,
            "leftJoints": [
                {
                    "name": "wrist",
                    "position": [0.123, 0.456, -0.789],
                    "orientation": [0.0, 0.0, 0.0, 1.0]
                },
                {
                    "name": "thumbKnuckle",
                    "position": [0.130, 0.460, -0.780],
                    "orientation": [0.1, 0.0, 0.0, 0.995]
                }
                // ... 其他 24 个关节
            ],
            "rightJoints": [
                // ... 26 个关节数据
            ]
        },
        {
            "timestamp": 0.033,
            // ... 下一帧数据
        }
    ]
}
```

### 3.3 列出已保存的录制

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

func listSavedRecordings() -> [URL] {
    guard let directory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first else {
        return []
    }
    
    let files = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )
    
    // 筛选 HandPose_ 开头的 JSON 文件，按时间倒序排列
    return files
        .filter { $0.lastPathComponent.hasPrefix("HandPose_") && $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }
}
```

---

## 4. Playback 时的数据调用

### 4.1 加载录制数据

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

func loadRecording(from url: URL) throws -> HandPoseRecording {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(HandPoseRecording.self, from: data)
}
```

### 4.2 开始回放

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

func beginPlayback(with recording: HandPoseRecording) {
    stopPlayback()  // 先停止任何正在进行的回放
    guard !recording.frames.isEmpty else { return }
    
    playbackRecording = recording
    playbackStartIndex = 0
    playbackStartOffset = 0
    playbackElapsedTime = 0
    isPlayingBack = true
    
    let frames = recording.frames
    
    playbackTask = Task {
        guard let baseTime = frames.first?.timestamp else {
            await MainActor.run { self.stopPlayback() }
            return
        }
        let startWallClock = CACurrentMediaTime()
        
        // 遍历所有帧
        for (index, frame) in frames.enumerated() {
            guard !Task.isCancelled else { break }
            
            // 计算当前已经过的时间
            let elapsed = (CACurrentMediaTime() - startWallClock) * self.playbackSpeed
            // 计算目标帧应该在的时间点
            let target = frame.timestamp - baseTime
            
            // 如果目标时间还没到，等待
            if target > elapsed {
                let delay = (target - elapsed) / self.playbackSpeed
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            guard !Task.isCancelled else { break }
            
            // 更新当前播放帧
            await MainActor.run {
                self.currentPlaybackFrame = frame
                self.playbackElapsedTime = frame.timestamp
                self.playbackStartIndex = index
                self.playbackStartOffset = frame.timestamp
            }
        }
        
        // 自然播放结束
        if !Task.isCancelled {
            await MainActor.run {
                self.isPlayingBack = false
            }
        }
    }
}
```

### 4.3 在视图中使用回放数据

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

private func updateHandVisualizations() {
    // ...
    
    case .playback:
        // 1. 显示用户当前的手（用于实时对比）
        leftHandVisualization?.update(with: leftJoints)
        rightHandVisualization?.update(with: rightJoints)
        
        // 2. 显示回放的手
        if let frame = captureManager.currentPlaybackFrame {
            playbackLeftHandVisualization?.update(with: frame.leftJoints)
            playbackRightHandVisualization?.update(with: frame.rightJoints)
            
            // 确保可见
            playbackLeftHandVisualization?.rootEntity.isEnabled = true
            playbackRightHandVisualization?.rootEntity.isEnabled = true
            
            // 同步时间显示
            if gameModel.isActivelyPlayingBack {
                gameModel.playbackElapsedTime = captureManager.playbackElapsedTime
            }
        }
}
```

---

## 5. 手部模型的显示机制

### 5.1 HandVisualization 类概述

```swift
// 位置: HappyBeam/Gameplay/HandVisualization.swift

@MainActor
class HandVisualization {
    private var jointEntities: [String: ModelEntity] = [:]  // 关节球体实体
    private var boneEntities: [String: ModelEntity] = [:]   // 骨骼圆柱体实体
    
    private let jointRadius: Float = 0.005    // 关节球体半径（5mm）
    private let boneRadius: Float = 0.003     // 骨骼圆柱半径（3mm）
    
    let rootEntity: Entity  // 根实体，所有子实体都添加到这里
    
    init(name: String, jointColor: UIColor = .cyan, boneColor: UIColor = .white) {
        self.rootEntity = Entity()
        self.rootEntity.name = name
        self.jointColor = jointColor
        self.boneColor = boneColor
    }
}
```

### 5.2 更新可视化

```swift
func update(with joints: [HandJointPose], interpolateMissing: Bool = false) {
    // 如果没有关节数据，隐藏整个可视化
    guard !joints.isEmpty else {
        rootEntity.isEnabled = false
        return
    }
    
    rootEntity.isEnabled = true
    
    // 先隐藏所有已存在的实体
    for entity in jointEntities.values {
        entity.isEnabled = false
    }
    for entity in boneEntities.values {
        entity.isEnabled = false
    }
    
    // 建立关节名称到数据的映射
    var jointDict: [String: HandJointPose] = [:]
    for joint in joints {
        jointDict[joint.name] = joint
    }
    
    // 更新关节球体位置
    for (name, joint) in jointDict {
        let jointEntity = getOrCreateJointEntity(named: name)
        jointEntity.isEnabled = true
        jointEntity.setTransformMatrix(joint.transformMatrix, relativeTo: nil)
    }
    
    // 更新骨骼连接
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
}
```

### 5.3 创建关节球体

```swift
private func getOrCreateJointEntity(named name: String) -> ModelEntity {
    if let existing = jointEntities[name] {
        return existing
    }
    
    // 创建球体网格
    let mesh = MeshResource.generateSphere(radius: jointRadius)
    let material = UnlitMaterial(color: jointColor)
    let entity = ModelEntity(mesh: mesh, materials: [material])
    entity.name = "joint-\(name)"
    
    rootEntity.addChild(entity)
    jointEntities[name] = entity
    return entity
}
```

### 5.4 创建并更新骨骼连接

```swift
private func getOrCreateBoneEntity(named name: String) -> ModelEntity {
    if let existing = boneEntities[name] {
        return existing
    }
    
    // 创建单位高度的圆柱体
    let mesh = MeshResource.generateCylinder(height: 1.0, radius: boneRadius)
    let material = UnlitMaterial(color: boneColor)
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
    
    // 位置：两端的中点
    let midpoint = (start + end) / 2
    entity.position = midpoint
    
    // 缩放：调整圆柱体高度以匹配骨骼长度
    entity.scale = SIMD3<Float>(1, length, 1)
    
    // 旋转：使圆柱体指向骨骼方向
    let up = SIMD3<Float>(0, 1, 0)
    let normalizedDirection = simd_normalize(direction)
    
    if abs(simd_dot(up, normalizedDirection)) < 0.999 {
        let rotationAxis = simd_normalize(simd_cross(up, normalizedDirection))
        let angle = acos(simd_dot(up, normalizedDirection))
        entity.orientation = simd_quatf(angle: angle, axis: rotationAxis)
    }
}
```

### 5.5 骨骼连接定义

```swift
// 位置: HappyBeam/Gameplay/HandPoseData.swift

struct HandBoneConnection {
    let startJoint: String
    let endJoint: String
    
    static let allConnections: [HandBoneConnection] = [
        // 拇指
        HandBoneConnection(startJoint: "wrist", endJoint: "thumbKnuckle"),
        HandBoneConnection(startJoint: "thumbKnuckle", endJoint: "thumbIntermediateBase"),
        HandBoneConnection(startJoint: "thumbIntermediateBase", endJoint: "thumbIntermediateTip"),
        HandBoneConnection(startJoint: "thumbIntermediateTip", endJoint: "thumbTip"),
        
        // 食指
        HandBoneConnection(startJoint: "wrist", endJoint: "indexFingerMetacarpal"),
        HandBoneConnection(startJoint: "indexFingerMetacarpal", endJoint: "indexFingerKnuckle"),
        // ... 其他连接
    ]
}
```

---

## 6. 记录时的随时终止实现

### 6.1 状态管理

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

@MainActor
final class HandCaptureManager: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var hasUnsavedRecording = false
    
    private var frames: [HandPoseFrame] = []
    private var elapsedTimeTask: Task<Void, Never>?
}
```

### 6.2 停止录制方法

```swift
/// 停止录制但不保存。数据保留在内存中供后续保存。
func stopRecording() {
    guard isRecording else { return }
    
    // 取消计时器任务
    elapsedTimeTask?.cancel()
    elapsedTimeTask = nil
    
    // 更新状态
    isRecording = false
    hasUnsavedRecording = !frames.isEmpty  // 如果有帧数据，标记为未保存
}
```

### 6.3 UI 控制实现

```swift
// 位置: HappyBeam/Views/SoloPlay.swift

private func handleRecordingToggle() {
    if gameModel.isActivelyRecording {
        // 停止录制
        NotificationCenter.default.post(name: .stopRecordingRequested, object: nil)
    } else {
        // 检查是否有未保存的数据
        if gameModel.hasUnsavedRecording {
            gameModel.showingSaveConfirmation = true
        } else {
            // 开始录制
            NotificationCenter.default.post(name: .startRecordingRequested, object: nil)
        }
    }
}
```

### 6.4 通知响应机制

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

struct NotificationModifier: ViewModifier {
    var startRecording: () -> Void
    var stopRecording: () -> Void
    var saveRecording: () -> Void
    var discardRecording: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .startRecordingRequested)) { _ in
                startRecording()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopRecordingRequested)) { _ in
                stopRecording()
            }
            // ...
    }
}
```

### 6.5 实际的停止录制执行

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

private func stopRecording() {
    captureManager.stopRecording()
    gameModel.isActivelyRecording = false
    gameModel.hasUnsavedRecording = captureManager.hasUnsavedRecording
}
```

---

## 7. Playback 时的暂停与重播实现

### 7.1 暂停实现

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

/// 暂停当前播放（可稍后恢复）
func pausePlayback() {
    playbackTask?.cancel()   // 取消播放任务
    playbackTask = nil
    isPlayingBack = false
    
    // 计算恢复位置，以便从暂停点继续
    if let recording = playbackRecording {
        if playbackElapsedTime > 0 {
            // 找到最接近当前时间的帧索引
            if let idx = recording.frames.firstIndex(where: { $0.timestamp >= self.playbackElapsedTime }) {
                playbackStartIndex = max(0, idx)
                playbackStartOffset = recording.frames[playbackStartIndex].timestamp
            }
        }
    }
}
```

### 7.2 恢复播放实现

```swift
/// 从暂停位置恢复播放
private func resumePlayback() {
    guard let recording = playbackRecording else { return }
    guard playbackStartIndex < recording.frames.count else {
        // 播放已结束，从头开始
        playbackStartIndex = 0
        playbackStartOffset = 0
        playbackElapsedTime = 0
        beginPlayback(with: recording)
        return
    }
    
    isPlayingBack = true
    let startIndexOffset = playbackStartIndex
    let frames = Array(recording.frames.dropFirst(startIndexOffset))  // 从暂停点之后的帧开始
    let baseOffset = playbackStartOffset
    
    playbackTask = Task {
        let startWallClock = CACurrentMediaTime()
        
        for (index, frame) in frames.enumerated() {
            guard !Task.isCancelled else { break }
            
            let elapsed = (CACurrentMediaTime() - startWallClock) * self.playbackSpeed
            let target = frame.timestamp - baseOffset  // 相对于暂停点的时间
            
            if target > elapsed {
                let delay = (target - elapsed) / self.playbackSpeed
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            guard !Task.isCancelled else { break }
            let absoluteIndex = startIndexOffset + index
            await MainActor.run {
                self.currentPlaybackFrame = frame
                self.playbackElapsedTime = frame.timestamp
                self.playbackStartIndex = absoluteIndex
                self.playbackStartOffset = frame.timestamp
            }
        }
    }
}
```

### 7.3 智能开始/恢复播放

```swift
/// 智能播放：如果是同一个录制且已暂停，则恢复；否则重新开始
func startOrResumePlayback(with recording: HandPoseRecording) {
    // 检查是否是同一个录制
    if let loaded = playbackRecording {
        let sameCount = loaded.frames.count == recording.frames.count
        let sameFirst = loaded.frames.first?.timestamp == recording.frames.first?.timestamp
        let sameLast = loaded.frames.last?.timestamp == recording.frames.last?.timestamp
        
        if sameCount && sameFirst && sameLast {
            resumePlayback()  // 恢复播放
            return
        }
    }
    
    beginPlayback(with: recording)  // 开始新播放
}
```

### 7.4 重播实现

```swift
// 位置: HappyBeam/Views/SoloPlay.swift

private func handlePlaybackToggle() {
    if isPlaybackFinished {
        // 重播逻辑：先停止再开始
        NotificationCenter.default.post(name: .stopPlaybackRequested, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .startPlaybackRequested, object: nil)
        }
    } else if gameModel.isActivelyPlayingBack {
        NotificationCenter.default.post(name: .pausePlaybackRequested, object: nil)
    } else {
        NotificationCenter.default.post(name: .startPlaybackRequested, object: nil)
    }
}

/// 判断播放是否结束
private var isPlaybackFinished: Bool {
    guard gameModel.playbackTotalDuration > 0 else { return false }
    return gameModel.playbackElapsedTime >= gameModel.playbackTotalDuration - 0.1
}
```

### 7.5 完全停止播放

```swift
/// 完全停止播放，重置所有状态
func stopPlayback() {
    playbackTask?.cancel()
    playbackTask = nil
    isPlayingBack = false
    currentPlaybackFrame = nil
    playbackElapsedTime = 0
    playbackStartIndex = 0
    playbackStartOffset = 0
    playbackRecording = nil
}
```

---

## 8. SwiftUI 关键语法应用

### 8.1 @Observable 宏（iOS 17+ / visionOS 1.0+）

> **注意**：`@Observable` 宏是在 iOS 17 / visionOS 1.0 中引入的新特性。如果需要支持更早的 iOS 版本，需要使用传统的 `@ObservableObject` 协议和 `@Published` 属性包装器。

```swift
// 位置: HappyBeam/GameModel.swift

/// 使用 @Observable 宏简化状态管理
@Observable
class GameModel {
    var isPlaying = false
    var soloGameMode: SoloGameMode = .normal
    var playbackRecording: HandPoseRecording?
    var isActivelyRecording = false
    // ...
}
```

**传统的 ObservableObject 对比：**
```swift
// 旧方式
class GameModel: ObservableObject {
    @Published var isPlaying = false
    @Published var soloGameMode: SoloGameMode = .normal
}

// 新方式（使用 @Observable）
@Observable
class GameModel {
    var isPlaying = false          // 无需 @Published
    var soloGameMode: SoloGameMode = .normal
}
```

### 8.2 @Environment 和 @State

```swift
// 位置: HappyBeam/Views/SoloPlay.swift

struct SoloPlay: View {
    @Environment(GameModel.self) var gameModel    // 从环境中获取 GameModel
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace  // 系统环境值
    
    @State private var playbackSpeed: Double = 1.0  // 视图私有状态
    
    var body: some View {
        // ...
    }
}
```

**@Environment 的使用：**
- `@Environment(GameModel.self)` - 获取父视图注入的可观察对象
- `@Environment(\.dismissImmersiveSpace)` - 获取系统提供的沉浸式空间控制

### 8.3 @StateObject 和 @ObservedObject

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

struct HappyBeamSpace: View {
    @ObservedObject var gestureModel: HeartGestureModel  // 从外部传入的可观察对象
    @StateObject private var captureManager = HandCaptureManager()  // 视图拥有的可观察对象
}
```

**区别说明：**
- `@StateObject` - 视图创建并拥有这个对象，对象的生命周期与视图绑定
- `@ObservedObject` - 视图观察外部传入的对象，不拥有它

### 8.4 RealityView（visionOS 专用）

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

RealityView { content in
    // 初始化阶段：添加 3D 内容
    content.add(spaceOrigin)
    content.add(cameraRelativeAnchor)
    
    // 设置手部可视化
    setupHandVisualizations(content: content)
    
    // 订阅碰撞事件
    collisionSubscription = content.subscribe(
        to: CollisionEvents.Began.self,
        on: nil,
        componentType: nil
    ) { event in
        // 处理碰撞
    }
} update: { updateContent in
    // 更新阶段：每帧调用
    updateHandVisualizations()
}
```

### 8.5 Task 和 async/await

```swift
// 位置: HappyBeam/Gameplay/HeartGestureModel.swift

func start() async {
    do {
        if HandTrackingProvider.isSupported {
            try await session.run([handTracking])  // 异步启动 ARKit 会话
        }
    } catch {
        print("ARKitSession error:", error)
    }
}

// 使用 for await 处理异步序列
func publishHandTrackingUpdates() async {
    for await update in handTracking.anchorUpdates {
        // 处理每次手部追踪更新
    }
}
```

### 8.6 .task 修饰符

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

struct TasksModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .task {
                await gestureModel.start()  // 视图出现时执行
            }
            .task {
                await gestureModel.publishHandTrackingUpdates()
            }
    }
}
```

### 8.7 @MainActor 和并发安全

```swift
// 位置: HappyBeam/Gameplay/HandCaptureManager.swift

@MainActor  // 确保所有方法在主线程执行
final class HandCaptureManager: ObservableObject {
    @Published private(set) var isRecording = false
    
    func startRecording() {
        // 自动在主线程执行
    }
}

// 在 Task 中切换到主线程
playbackTask = Task {
    // 后台计算
    await MainActor.run {
        // UI 更新必须在主线程
        self.currentPlaybackFrame = frame
    }
}
```

### 8.8 Notification 和 onReceive

```swift
// 通知名称定义
extension Notification.Name {
    static let startRecordingRequested = Notification.Name("startRecordingRequested")
    static let stopRecordingRequested = Notification.Name("stopRecordingRequested")
}

// 发送通知
NotificationCenter.default.post(name: .startRecordingRequested, object: nil)

// 在 SwiftUI 中接收通知
.onReceive(NotificationCenter.default.publisher(for: .startRecordingRequested)) { _ in
    startRecording()
}
```

### 8.9 ViewModifier 和条件视图

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

struct NotificationModifier: ViewModifier {
    var startRecording: () -> Void
    var stopRecording: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .startRecordingRequested)) { _ in
                startRecording()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopRecordingRequested)) { _ in
                stopRecording()
            }
    }
}

// 使用
someView.modifier(NotificationModifier(
    startRecording: startRecording,
    stopRecording: stopRecording
))
```

### 8.10 Binding 和双向绑定

```swift
// 位置: HappyBeam/Views/SoloPlay.swift

// 创建自定义 Binding
.confirmationDialog(
    "Unsaved Recording",
    isPresented: Binding(
        get: { gameModel.showingSaveConfirmation },
        set: { gameModel.showingSaveConfirmation = $0 }
    ),
    titleVisibility: .visible
) {
    // 对话框内容
}

// Picker 使用绑定
@State private var playbackSpeed: Double = 1.0

Picker("Speed", selection: $playbackSpeed) {
    Text("0.5x").tag(0.5)
    Text("1.0x").tag(1.0)
    Text("1.5x").tag(1.5)
}
.onChange(of: playbackSpeed) { _, newSpeed in
    // 速度变化时的处理
}
```

### 8.11 手势处理

```swift
// 位置: HappyBeam/HappyBeamSpace.swift

// 拖拽手势
private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0.0)
        .targetedToAnyEntity()
        .onChanged { @MainActor drag in
            // 处理拖拽
        }
        .onEnded { dragEnd in
            // 拖拽结束
        }
}

// 组合手势（缩放 + 拖拽）
private var playbackGestures: some Gesture {
    SimultaneousGesture(
        MagnificationGesture()
            .onChanged { value in
                // 处理缩放
            },
        DragGesture()
            .onChanged { value in
                // 处理拖拽
            }
    )
}
```

---

## 总结

本项目是一个基于 Apple Vision Pro 的手部动作教练系统，其核心技术架构如下：

1. **关节识别**：使用 ARKit 的 `HandTrackingProvider` 追踪 26 个手部关节
2. **数据记录**：通过 `HandCaptureManager` 将每帧的关节位置和旋转编码为 JSON
3. **数据存储**：保存在应用的 Documents 目录，使用时间戳命名
4. **回放机制**：使用 `Task` 和 `Task.sleep` 实现精确的时间同步播放
5. **可视化**：使用 RealityKit 的 `ModelEntity` 创建关节球体和骨骼圆柱体
6. **控制流**：通过 `NotificationCenter` 实现 UI 与业务逻辑的解耦

SwiftUI 的现代特性（如 `@Observable`、`async/await`、`RealityView`）为项目提供了声明式、响应式的开发体验。
