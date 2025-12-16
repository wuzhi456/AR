import SwiftUI
import RealityKit
import Combine

/// A simple replay container that hosts a RealityView for showing hand model replay.
/// Responsibilities:
/// - Render a hand model driven by `HandModelController`.
/// - Accept gestures (pan/pinch/rotate) and translate them to camera controls via the controller.
struct HandReplayView: View {
    @StateObject var controller = HandModelController()

    var body: some View {
        ZStack {
            // RealityView hosts the 3D content. The controller provides the root anchor.
            RealityView { content in
                content.add(controller.rootAnchor)
            } update: { _ in
                // Nothing per-frame from SwiftUI; controller updates models directly.
            }
            .gesture(panGesture)
            .gesture(pinchGesture)

            // Overlay UI (play/pause handled by external view model)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                }
            }
        }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                controller.handlePan(translation: value.translation)
            }
            .onEnded { _ in
                controller.endPan()
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                controller.handlePinch(scale: scale)
            }
            .onEnded { _ in
                controller.endPinch()
            }
    }
}

#Preview {
    HandReplayView()
}
