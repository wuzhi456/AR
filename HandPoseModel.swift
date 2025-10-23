import ARKit
import SwiftUI

/// Keeps the latest hand anchor information from ARKit.
@MainActor
final class HandPoseModel: ObservableObject {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    @Published private(set) var latestLeft: HandAnchor?
    @Published private(set) var latestRight: HandAnchor?

    func startSession() async {
        guard HandTrackingProvider.isSupported else {
            print("Hand tracking is not supported on this device.")
            return
        }

        do {
            try await session.run([handTracking])
        } catch {
            print("Failed to run ARKit session:", error)
        }
    }

    func monitorHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let anchor = update.anchor

            switch update.event {
            case .added, .updated:
                if anchor.chirality == .left {
                    latestLeft = anchor
                } else if anchor.chirality == .right {
                    latestRight = anchor
                }
            case .removed:
                if anchor.chirality == .left {
                    latestLeft = nil
                } else if anchor.chirality == .right {
                    latestRight = nil
                }
            default:
                break
            }
        }
    }

    func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(let type, let status):
                if type == .handTracking, status != .allowed {
                    print("Hand tracking authorization not granted: \(status)")
                }
            default:
                print("Session event: \(event)")
            }
        }
    }
}
