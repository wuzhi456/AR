//
//  HandTrackingModel.swift
//  ARCoach_demo
//
//  Created by Dvalab on 2025/10/28.
//

import ARKit
import Foundation
import SwiftUI
internal import Combine

/// Publishes live hand-tracking anchors from `HandTrackingProvider`.
@MainActor
final class HandTrackingModel: ObservableObject, @unchecked Sendable {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()

    @Published private(set) var latestHands = HandsUpdates()

    struct HandsUpdates {
        var left: HandAnchor?
        var right: HandAnchor?
    }

    /// Starts the ARKit session if hand tracking is supported on the current device.
    func start() async {
        guard HandTrackingProvider.isSupported else {
            print("Hand tracking is not supported on this device.")
            return
        }

        do {
            print("ARKitSession starting with hand tracking provider.")
            try await session.run([handTracking])
        } catch {
            print("ARKitSession failed to start: \(error.localizedDescription)")
        }
    }

    /// Continuously publishes hand anchor updates as they stream from ARKit.
    func publishHandTrackingUpdates() async {
        guard HandTrackingProvider.isSupported else { return }

        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .added, .updated:
                if !update.anchor.isTracked {
                    if update.anchor.chirality == .left {
                        latestHands.left = nil
                    } else if update.anchor.chirality == .right {
                        latestHands.right = nil
                    }
                    continue
                }

                if update.anchor.chirality == .left {
                    latestHands.left = update.anchor
                } else if update.anchor.chirality == .right {
                    latestHands.right = update.anchor
                }
            case .removed:
                if update.anchor.chirality == .left {
                    latestHands.left = nil
                } else if update.anchor.chirality == .right {
                    latestHands.right = nil
                }
            default:
                break
            }
        }
    }

    /// Monitors session events in case authorization changes while the app is running.
    func monitorSessionEvents() async {
        guard HandTrackingProvider.isSupported else { return }

        for await event in session.events {
            switch event {
            case .authorizationChanged(let capability, let status):
                if capability == .handTracking && status != .allowed {
                    print("Hand tracking authorization changed: \(status)")
                }
            default:
                break
            }
        }
    }
}
