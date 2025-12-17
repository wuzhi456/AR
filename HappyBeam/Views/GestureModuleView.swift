import SwiftUI
import RealityKit
import ARKit

/// Lightweight gesture recognition module view.
struct GestureModuleView: View {
    @ObservedObject private var gestureModel = HeartGestureModelContainer.heartGestureModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismiss) private var dismiss

    @State private var heartActive: Bool = false
    @State private var leftPinch: Bool = false
    @State private var rightPinch: Bool = false
    @State private var leftTracked: Bool = false
    @State private var rightTracked: Bool = false
    
    @ObservedObject private var handVectorManager = HandVectorManager.shared
    @State private var builtinGestures: [String: HVHandJsonModel] = [:]
    @State private var similarityScore: Float = 0.0
    @State private var recognizedGesture: String = "None"
    @State private var isDetectionEnabled: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    // Prefer dismissing a regular SwiftUI presentation first.
                    dismiss()
                    // Also attempt to dismiss immersive space if this view is hosted there.
                    Task {
                        await dismissImmersiveSpace()
                    }
                }) {
                    Label("Back", systemImage: "chevron.left")
                }
                Spacer()
                Text("Gesture Recognition")
                    .font(.title2)
                    .bold()
                Spacer()
                Spacer().frame(width: 44)
            }
            .padding()

            TabView {
                gestureRecognitionView
                    .tabItem { Text("识别") }

                VStack {
                    Text("Hand Vector Debug")
                        .font(.headline)
                    
                    Toggle("Enable Detection", isOn: $isDetectionEnabled)
                        .padding(.horizontal)
                    
                    Toggle("Show Skeleton", isOn: $handVectorManager.isSkeletonVisible)
                        .padding(.horizontal)
                    
                    HStack {
                        VStack {
                            Text("Left Hand")
                                .font(.caption)
                            if let left = handVectorManager.leftHand {
                                Text("Tracked")
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Tracked")
                                    .foregroundColor(.red)
                            }
                        }
                        Spacer()
                        VStack {
                            Text("Right Hand")
                                .font(.caption)
                            if let right = handVectorManager.rightHand {
                                Text("Tracked")
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Tracked")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    Text("Most Likely Gesture: \(recognizedGesture)")
                        .font(.title2)
                        .padding(.top)
                    
                    Text("Similarity: \(String(format: "%.2f", similarityScore))")
                        .font(.title3)
                        .foregroundColor(similarityScore > 0.8 ? .green : .primary)
                    
                    if similarityScore > 0.9 {
                        Text("MATCHED!")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                            .bold()
                    }
                }
                .tabItem { Text("Hand Vector") }
                
                VStack {
                    Text("小游戏占位")
                        .foregroundStyle(.secondary)
                    Text("(待实现)")
                        .foregroundStyle(.secondary)
                }
                .tabItem { Text("小游戏") }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            // Load builtin gestures
            if let loaded = HVHandJsonModel.loadHandJsonModelDict(fileName: "BuiltinHand") {
                builtinGestures = loaded
            } else {
                // Fallback if file not found in bundle (e.g. not added to target)
                // Try to load from local path if possible or just log error
                print("Failed to load BuiltinHand.json")
            }
            
            // Start heart gesture model tasks in background
            Task.detached { @MainActor in
                await gestureModel.start()
            }
            Task.detached { @MainActor in
                await gestureModel.publishHandTrackingUpdates()
            }
            // Start a small timer to poll detection state and update UI
            Task {
                while !Task.isCancelled {
                    await updateDetections()
                    
                    // Ensure HandVectorManager is updated with latest data
                    let left = gestureModel.latestHandTracking.left
                    let right = gestureModel.latestHandTracking.right
                    await MainActor.run {
                        HandVectorManager.shared.update(left: left, right: right)
                    }
                    
                    updateHandVectorSimilarity()
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }
        }
    }
    
    private func updateHandVectorSimilarity() {
        guard isDetectionEnabled else { return }
        
        var bestMatchName = "None"
        var bestMatchScore: Float = 0.0
        
        // Iterate through all loaded gestures
        for (name, jsonModel) in builtinGestures {
            guard let targetGesture = jsonModel.convertToHVHandInfo() else { continue }
            
            var currentMax: Float = 0.0
            
            if let leftHand = handVectorManager.leftHand {
                let score = leftHand.similarity(to: targetGesture)
                if score > currentMax { currentMax = score }
            }
            
            if let rightHand = handVectorManager.rightHand {
                let score = rightHand.similarity(to: targetGesture)
                if score > currentMax { currentMax = score }
            }
            
            if currentMax > bestMatchScore {
                bestMatchScore = currentMax
                bestMatchName = name
            }
        }
        
        self.similarityScore = bestMatchScore
        self.recognizedGesture = bestMatchName
    }

    private var gestureRecognitionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Heart Gesture")
                        .font(.headline)
                    Text(heartActive ? "Detected" : "Not detected")
                        .foregroundStyle(heartActive ? .green : .secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Left Pinch")
                        .font(.headline)
                    Text(leftPinch ? "Yes" : "—")
                        .foregroundStyle(leftPinch ? .green : .secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Right Pinch")
                        .font(.headline)
                    Text(rightPinch ? "Yes" : "—")
                        .foregroundStyle(rightPinch ? .green : .secondary)
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Vector Gesture Analysis")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Best Match: \(recognizedGesture)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(similarityScore > 0.8 ? .green : .primary)
                        Text("Score: \(String(format: "%.2f", similarityScore))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if similarityScore > 0.9 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.largeTitle)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Left Hand")
                        .font(.subheadline)
                    Text(leftTracked ? "Tracked" : "—")
                        .foregroundStyle(leftTracked ? .green : .secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Right Hand")
                        .font(.subheadline)
                    Text(rightTracked ? "Tracked" : "—")
                        .foregroundStyle(rightTracked ? .green : .secondary)
                }
            }
            .padding(.horizontal)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("说明")
                    .font(.headline)
                Text("• 将双手靠拢拇指与食指接触可触发 Heart 手势。\n• 单侧拇指与食指接近可触发 Pinch (捏合) 检测。\n• 尝试做出 '👆' 手势来测试向量识别。")
                    .foregroundStyle(.secondary)
            }
            .padding()

            Spacer()
        }
    }

    @MainActor
    private func updateDetections() async {
        let latest = gestureModel.latestHandTracking

        leftTracked = (latest.left?.isTracked ?? false)
        rightTracked = (latest.right?.isTracked ?? false)

        // Heart gesture via provided helper
        if let _ = gestureModel.computeTransformOfUserPerformedHeartGesture() {
            heartActive = true
        } else {
            heartActive = false
        }

        // Pinch detection: thumb tip & index tip distance < threshold
        func pinchDetected(anchor: HandAnchor?) -> Bool {
            guard let anchor = anchor, anchor.isTracked,
                  let thumb = anchor.handSkeleton?.joint(.thumbTip),
                  let index = anchor.handSkeleton?.joint(.indexFingerTip),
                  thumb.isTracked && index.isTracked else { return false }

            let t = matrix_multiply(anchor.originFromAnchorTransform, thumb.anchorFromJointTransform).columns.3.xyz
            let i = matrix_multiply(anchor.originFromAnchorTransform, index.anchorFromJointTransform).columns.3.xyz
            return distance(t, i) < 0.03
        }

        leftPinch = pinchDetected(anchor: latest.left)
        rightPinch = pinchDetected(anchor: latest.right)
    }
}

struct GestureModuleView_Previews: PreviewProvider {
    static var previews: some View {
        GestureModuleView()
    }
}
