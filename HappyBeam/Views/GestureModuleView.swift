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
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }
        }
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
                Text("• 将双手靠拢拇指与食指接触可触发 Heart 手势。\n• 单侧拇指与食指接近可触发 Pinch (捏合) 检测。")
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
