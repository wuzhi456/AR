import ARKit
import RealityKit
import SwiftUI

struct HandCoachView: View {
    @StateObject private var poseModel = HandPoseModel()
    @StateObject private var renderer = HandSkeletonRenderer()

    var body: some View {
        ZStack(alignment: .topLeading) {
            RealityView { content in
                renderer.installIfNeeded(into: content)
            } update: { _ in
                renderer.update(left: poseModel.latestLeft, right: poseModel.latestRight)
            }
            .task {
                await poseModel.startSession()
            }
            .task {
                await poseModel.monitorHandUpdates()
            }
            .task {
                await poseModel.monitorSessionEvents()
            }

            instructionOverlay
        }
    }

    private var instructionOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hand Skeleton Debug View")
                .font(.headline)
            Text("Raise your hands within the field of view to see tracked joints.")
                .font(.subheadline)
            if !HandTrackingProvider.isSupported {
                Text("Hand tracking is unavailable on this hardware.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }
}

#Preview {
    HandCoachView()
}
