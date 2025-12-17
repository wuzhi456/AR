# 空间计算范式下的身心教学法：基于 Apple Vision Pro 构建增强现实书法动作教练的项目报告

## 1. 执行摘要：项目实现概述

本报告记录了基于 Apple Vision Pro (AVP) 的增强现实手部动作教练系统（ARCoach）的实际开发与实现成果。项目利用 AVP 的高保真光学手部追踪技术，实现了中国书法动作学习的"记录-回放-比较"功能闭环。

本项目采用**原生 visionOS 开发栈（RealityKit + SwiftUI + ARKit）**构建，已成功实现以下三大核心功能模块：

1. **记录模块 (Recording)**：通过 `HandTrackingProvider` 获取 26 关节骨骼数据，并以 JSON 格式持久化存储手部姿态序列。
2. **回放模块 (Playback)**：加载已保存的手部姿态数据，在 AR 沉浸式空间中重建并可视化手部运动轨迹。
3. **比较模块 (Comparison)**：支持加载"教练"和"学员"两份录制数据，通过相似度算法计算动作匹配程度并给出百分比评分。

项目还包含一个完整的 **HappyBeam** 应用框架，提供了沉浸式空间的完整生命周期管理，以及基于手势识别的游戏交互系统（如"爱心手势"检测）。

系统当前版本聚焦于验证 AVP 手部追踪在书法动作教学场景下的可行性，为未来扩展更高级的实时练习模式和动态反馈机制奠定了基础。

------

## 2. 硬件基础：Apple Vision Pro 手部追踪能力

### 2.1 手部追踪架构

Apple Vision Pro 利用自我中心摄像头和激光雷达 (LiDAR) 的传感器融合技术，重建手部的 26 个关节骨骼模型。本项目通过 ARKit 的 `HandTrackingProvider` API 获取实时手部追踪数据。

**项目中使用的核心追踪数据结构：**

```swift
struct HandJointPose: Codable, Sendable {
    let name: String
    let position: [Float]      // 世界坐标系下的 (x, y, z)
    let orientation: [Float]   // 四元数表示的旋转 (x, y, z, w)
}

struct HandPoseFrame: Codable, Sendable {
    let timestamp: TimeInterval
    let leftJoints: [HandJointPose]
    let rightJoints: [HandJointPose]
}
```

### 2.2 追踪数据获取

项目通过 `HeartGestureModel` 和 `HandTrackingModel` 类管理 ARKit 会话和手部追踪更新：

```swift
@MainActor
class HeartGestureModel: ObservableObject {
    let session = ARKitSession()
    var handTracking = HandTrackingProvider()
    
    func start() async {
        if HandTrackingProvider.isSupported {
            try await session.run([handTracking])
        }
    }
    
    func publishHandTrackingUpdates() async {
        for await update in handTracking.anchorUpdates {
            // 处理手部追踪更新
        }
    }
}
```

### 2.3 关节数据提取

项目实现了从 `HandAnchor` 中提取所有关节姿态的辅助函数：

```swift
func extractJointPoses(from anchor: HandAnchor?) -> [HandJointPose] {
    guard let anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else { return [] }
    
    return HandSkeleton.JointName.allCases.compactMap { jointName in
        let joint = skeleton.joint(jointName)
        let worldTransform = matrix_multiply(
            anchor.originFromAnchorTransform, 
            joint.anchorFromJointTransform
        )
        return HandJointPose(name: String(describing: jointName), transform: worldTransform)
    }
}
```

------

## 3. 功能模块实现

### 3.1 记录模块 (Recording)

**功能描述：** 实时采集用户手部姿态数据，支持开始/停止录制，并将数据持久化保存。

**核心实现类：** `HandCaptureManager`

```swift
@MainActor
final class HandCaptureManager: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordingElapsedTime: TimeInterval = 0
    
    private var frames: [HandPoseFrame] = []
    private var recordingStart: TimeInterval = 0
    
    func startRecording() {
        frames.removeAll()
        recordingStart = CACurrentMediaTime()
        isRecording = true
    }
    
    func captureFrame(leftJoints: [HandJointPose], rightJoints: [HandJointPose]) {
        guard isRecording else { return }
        let timestamp = CACurrentMediaTime() - recordingStart
        let frame = HandPoseFrame(timestamp: timestamp, leftJoints: leftJoints, rightJoints: rightJoints)
        frames.append(frame)
    }
    
    func saveRecording() async {
        let recording = HandPoseRecording(frames: frames)
        let data = try encoder.encode(recording)
        let filename = "HandPose_\(dateString).json"
        try data.write(to: documentsDirectory.appendingPathComponent(filename))
    }
}
```

**数据存储格式：** JSON 文件，包含版本号、创建时间和帧序列：

```json
{
    "version": 1,
    "createdAt": "2025-01-01T00:00:00Z",
    "samples": [
        {
            "timestamp": 0.0,
            "leftJoints": [...],
            "rightJoints": [...]
        }
    ]
}
```

### 3.2 回放模块 (Playback)

**功能描述：** 加载已保存的手部姿态数据，按时间戳同步播放，支持暂停/继续/停止控制。

**核心实现：**

```swift
func beginPlayback(with recording: HandPoseRecording) {
    isPlayingBack = true
    let frames = recording.frames
    
    playbackTask = Task {
        guard let baseTime = frames.first?.timestamp else { return }
        let startWallClock = CACurrentMediaTime()
        
        for frame in frames {
            let elapsed = CACurrentMediaTime() - startWallClock
            let target = frame.timestamp - baseTime
            
            if target > elapsed {
                try await Task.sleep(nanoseconds: UInt64((target - elapsed) * 1_000_000_000))
            }
            
            self.currentPlaybackFrame = frame
            self.playbackElapsedTime = frame.timestamp
        }
    }
}
```

**手部可视化：** 使用 `HandVisualization` 类渲染手部关节和骨骼连接：

```swift
class HandVisualization {
    private var jointEntities: [String: ModelEntity] = [:]
    private var boneEntities: [String: ModelEntity] = [:]
    let rootEntity: Entity
    
    func update(with joints: [HandJointPose]) {
        // 更新关节球体位置
        for joint in joints {
            let entity = getOrCreateJointEntity(named: joint.name)
            entity.setTransformMatrix(joint.transformMatrix, relativeTo: nil)
        }
        
        // 更新骨骼连接（圆柱体）
        for connection in HandBoneConnection.allConnections {
            updateBoneTransform(from: startJoint.position, to: endJoint.position)
        }
    }
}
```

### 3.3 比较模块 (Comparison)

**功能描述：** 加载两份录制数据（教练 vs 学员），计算动作相似度分数。

**核心实现类：** `CalligraphyComparisonViewModel`

**相似度计算算法：**

项目采用基于关节位置欧几里得距离的简化相似度算法：

```swift
private func calculateSimilarity(coach: HandPoseRecording, user: HandPoseRecording, mode: HandComparisonMode) -> Float {
    let sampleCount = 100  // 归一化为 100 帧
    var totalDistance: Float = 0.0
    
    for i in 0..<sampleCount {
        let t = Double(i) / Double(sampleCount - 1)
        
        let coachFrame = sampleFrame(recording: coach, at: t, range: coachTrimRange)
        let userFrame = sampleFrame(recording: user, at: t, range: userTrimRange)
        
        let coachJoints = getRelevantJoints(frame: coachFrame, isCoach: true, mode: mode)
        let userJoints = getRelevantJoints(frame: userFrame, isCoach: false, mode: mode)
        
        totalDistance += calculateFrameDistance(coachJoints: coachJoints, userJoints: userJoints)
    }
    
    let averageDistance = totalDistance / Float(sampleCount)
    let similarity = max(0, 1.0 - (averageDistance * 5.0))
    return similarity
}
```

**帧间距离计算：**

```swift
private func calculateFrameDistance(coachJoints: [HandJointPose], userJoints: [HandJointPose]) -> Float {
    // 以手腕位置为基准归一化
    guard let coachWrist = coachJoints.first(where: { $0.name == "wrist" }),
          let userWrist = userJoints.first(where: { $0.name == "wrist" }) else { return 1.0 }
    
    var distance: Float = 0.0
    var count: Float = 0.0
    
    // 重点比较指尖关节
    for jointName in ["thumbTip", "indexFingerTip", "middleFingerTip", "ringFingerTip"] {
        if let cJoint = coachJoints.first(where: { $0.name == jointName }),
           let uJoint = userJoints.first(where: { $0.name == jointName }) {
            
            let cPos = cJoint.positionVector - coachWristPos
            let uPos = uJoint.positionVector - userWristPos
            let d = simd_distance(cPos, uPos)
            
            // 权重：拇指、食指、中指 > 无名指
            let weight: Float = jointName.contains("ring") ? 0.5 : 1.0
            distance += d * weight
            count += weight
        }
    }
    
    return count > 0 ? distance / count : 1.0
}
```

**比较模式支持：**

```swift
enum HandComparisonMode: String, CaseIterable {
    case rightToRight = "Right vs Right"
    case leftToLeft = "Left vs Left"
    case rightToLeft = "Right vs Left (Mirror)"
}
```

**裁剪功能：** 支持对教练和学员录制数据进行时间范围裁剪，以对齐关键动作段落。

------

## 4. 系统架构

### 4.1 技术栈

| 组件       | 技术选型                   | 说明                                 |
| ---------- | -------------------------- | ------------------------------------ |
| 平台       | visionOS 2.0+              | Apple Vision Pro 原生平台            |
| UI 框架    | SwiftUI                    | 声明式 UI 构建                       |
| 3D 渲染    | RealityKit                 | 空间渲染和实体管理                   |
| 手部追踪   | ARKit (HandTrackingProvider)| 26 关节骨骼追踪                      |
| 数据持久化 | JSON + FileManager         | 录制数据序列化存储                   |
| 开发语言   | Swift 5.9+                 | 类型安全的并发编程                   |

### 4.2 项目结构

```
AR/
├── HappyBeam/                      # 主应用
│   ├── HappyBeamApp.swift          # 应用入口
│   ├── GameModel.swift             # 全局状态管理
│   ├── HappyBeamSpace.swift        # 沉浸式空间主视图
│   ├── Gameplay/
│   │   ├── HandCaptureManager.swift    # 录制/回放管理
│   │   ├── HandPoseData.swift          # 数据模型定义
│   │   ├── HandVisualization.swift     # 手部可视化渲染
│   │   ├── HeartGestureModel.swift     # 手势追踪模型
│   │   └── CalligraphyComparisonViewModel.swift  # 比较逻辑
│   └── Views/
│       ├── Start.swift                 # 启动界面
│       ├── SoloPlay.swift              # 单人模式控制界面
│       └── CalligraphyComparisonView.swift  # 比较模式界面
│
├── ARCoach_demo/                   # 演示应用（简化版）
│   ├── ARCoach_demoApp.swift
│   ├── HandTrackingModel.swift
│   ├── ImmersiveView.swift
│   └── ...
│
└── Packages/
    ├── RealityKitContent/          # RealityKit 资源
    └── HappyBeamAssets/            # 游戏资源
```

### 4.3 数据流

```
┌─────────────────────────────────────────────────────────────────┐
│                     visionOS / ARKit                            │
│  HandTrackingProvider → HandAnchor → HandSkeleton (26 joints)   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   HeartGestureModel                             │
│  - 启动 ARKitSession                                            │
│  - 订阅 anchorUpdates                                           │
│  - 发布 latestHandTracking (左右手 HandAnchor)                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   HappyBeamSpace (主视图)                       │
│  - extractJointPoses() 提取关节数据                             │
│  - 根据 soloGameMode 分发到不同处理逻辑                         │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Recording 模式  │  │  Playback 模式  │  │  Normal 模式    │
│  captureFrame() │  │  beginPlayback()│  │  游戏逻辑       │
│  saveRecording()│  │  pausePlayback()│  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
          │                   │
          ▼                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                  HandVisualization                              │
│  - 创建关节球体 (ModelEntity)                                   │
│  - 创建骨骼连接 (圆柱体)                                        │
│  - 实时更新位置/旋转                                            │
└─────────────────────────────────────────────────────────────────┘
```

------

## 5. 用户界面

### 5.1 启动界面 (Start View)

提供三个主要入口：
- **Recording Mode**：进入手部姿态录制模式
- **Playback Mode**：选择已保存的录制文件进行回放
- **Calligraphy Comparison**：进入书法比较界面

### 5.2 录制模式控制界面

```
┌──────────────────────────────┐
│  ○ Recording                 │
│                              │
│       00:05.3                │
│      recording               │
│                              │
│  🔇  ⏺  💾  🗑              │
│      Start/Stop  Save  Discard│
└──────────────────────────────┘
```

### 5.3 回放模式控制界面

```
┌──────────────────────────────┐
│  ▶ Playing                   │
│                              │
│       00:03.2                │
│       / 00:10                │
│      playing                 │
│                              │
│      ▶/⏸    ⏹               │
│     Play/Pause  Stop         │
└──────────────────────────────┘
```

### 5.4 书法比较界面

- 教练录制文件选择
- 学员录制文件选择
- 比较模式选择（右手 vs 右手、左手 vs 左手、镜像比较）
- 时间范围裁剪滑块
- 相似度分数显示
- 3D 可视化对比（支持拖拽旋转视角）
- 同步回放控制

------

## 6. 手势识别附加功能

### 6.1 爱心手势检测

项目还实现了双手组合"爱心"手势的检测，用于游戏交互：

```swift
func computeTransformOfUserPerformedHeartGesture() -> simd_float4x4? {
    // 获取双手关键关节
    guard let leftThumbTip = leftHand.thumbTip,
          let leftIndexTip = leftHand.indexFingerTip,
          let rightThumbTip = rightHand.thumbTip,
          let rightIndexTip = rightHand.indexFingerTip else {
        return nil
    }
    
    // 计算指尖距离
    let indexFingersDistance = distance(leftIndexTip, rightIndexTip)
    let thumbsDistance = distance(leftThumbTip, rightThumbTip)
    
    // 距离阈值判定（< 4cm 视为接触）
    let isHeartShapeGesture = indexFingersDistance < 0.04 && thumbsDistance < 0.04
    
    if isHeartShapeGesture {
        // 返回手势中心点的变换矩阵
        return heartMidpointWorldTransform
    }
    return nil
}
```

------

## 7. 当前实现与未来扩展

### 7.1 已实现功能

| 功能模块         | 状态   | 说明                                             |
| ---------------- | ------ | ------------------------------------------------ |
| 手部追踪数据获取 | ✅ 完成 | 26 关节骨骼数据实时采集                          |
| 手部姿态录制     | ✅ 完成 | JSON 格式持久化存储                              |
| 手部姿态回放     | ✅ 完成 | 时间同步回放，支持暂停/继续                      |
| 手部可视化       | ✅ 完成 | 关节球体 + 骨骼连接线渲染                        |
| 动作比较         | ✅ 完成 | 基于欧几里得距离的相似度计算                     |
| 比较可视化       | ✅ 完成 | 双手叠加显示，支持旋转视角                       |
| 录制裁剪         | ✅ 完成 | 时间范围选择器                                   |
| 多种比较模式     | ✅ 完成 | 右右、左左、镜像比较                             |

### 7.2 未来扩展方向

| 功能模块              | 状态     | 描述                                               |
| --------------------- | -------- | -------------------------------------------------- |
| 实时练习模式 (Practice) | 🔲 待开发 | 实时对比用户动作与教练模板，提供即时反馈           |
| 高级 DTW 算法         | 🔲 待开发 | 动态时间规整算法，处理不同速度的动作对齐           |
| 四元数旋转比较        | 🔲 待开发 | 在距离计算中加入关节旋转因素                       |
| 速度/加速度分析       | 🔲 待开发 | 分析动作的力度和节奏特征                           |
| 虚拟毛笔模拟          | 🔲 待开发 | 基于手部姿态模拟毛笔笔触                           |
| 墨迹渲染              | 🔲 待开发 | 根据压力和速度生成虚拟墨迹                         |
| 视觉/听觉反馈         | 🔲 待开发 | 通过颜色、声音等方式提供动作指导                   |
| 3D 轨迹"隧道"可视化  | 🔲 待开发 | 显示动作容差范围的立体轨迹                         |

------

## 8. 结论

本项目成功验证了 Apple Vision Pro 手部追踪技术在书法动作教学场景下的可行性。通过实现"记录-回放-比较"功能闭环，系统能够：

1. **捕获**高精度的手部运动数据（26 关节骨骼追踪）
2. **存储**完整的动作序列用于后续分析
3. **重现**已录制的动作供学习者观察
4. **评估**学员动作与教练动作的相似程度

当前实现采用原生 visionOS 技术栈（RealityKit + SwiftUI + ARKit），具有良好的性能和系统集成度。项目架构设计为未来扩展实时练习模式、高级算法分析和多感官反馈机制奠定了基础。

本系统为书法等精细运动技能的数字化教学提供了新的可能性，也为非物质文化遗产的保护与传承探索了创新路径——将传统技艺以数据驱动、可交互的方式进行记录和传播。
