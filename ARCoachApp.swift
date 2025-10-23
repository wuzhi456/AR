import SwiftUI

@main
struct ARCoachApp: App {
    var body: some Scene {
        WindowGroup("AR Coach", id: "arCoachWindow") {
            HandCoachView()
        }
    }
}
