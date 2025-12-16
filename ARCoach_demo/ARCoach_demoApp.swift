import SwiftUI

@main
struct ARCoach_demoApp: App {
    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()
    @StateObject private var captureManager = HandCaptureManager() // Shared Manager

    var body: some Scene {
        WindowGroup(id: "main") {
            LauncherView()
                .environmentObject(appModel)
                .environmentObject(captureManager) // Inject into Window
        }

            ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(appModel)
                .environmentObject(captureManager) // Inject into ImmersiveSpace
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    avPlayerViewModel.reset()
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}