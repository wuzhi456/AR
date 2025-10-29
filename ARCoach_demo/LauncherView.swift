import SwiftUI

struct LauncherView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Color.clear
            .task {
                // 打开沉浸空间（渲染手部）
                _ = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                // 关闭窗口，避免挡住视野
                dismissWindow(id: "main")
            }
    }
}