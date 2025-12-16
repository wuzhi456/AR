//
//  AppModel.swift
//  ARCoach_demo
//
//  Created by Dvalab on 2025/10/28.
//

import SwiftUI
import Combine

/// Maintains app-wide state
@MainActor
class AppModel: ObservableObject {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    @Published var immersiveSpaceState = ImmersiveSpaceState.closed
}
