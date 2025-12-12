import SwiftUI
import UniformTypeIdentifiers

struct HandCaptureControlPanelView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(HandCaptureManager.self) private var captureManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var isShowingFileImporter = false

    var body: some View {
        HStack(spacing: 16) {
            Button(captureManager.isRecording ? "Stop Recording" : "Start Recording") {
                toggleRecording()
            }
            .buttonStyle(.borderedProminent)

            Button(captureManager.isPlayingBack ? "Stop Playback" : "Playback") {
                togglePlayback()
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 40)
        .fileImporter(isPresented: $isShowingFileImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            switch result {
                case .success(let urls):
                guard let url = urls.first else {
                    print("No file selected")
                    return
                }
                Task.detached(priority: .userInitiated) {
                    do {
                        let data = try Data(contentsOf: url)
                        let sequence = try JSONDecoder().decode(HandPoseSequence.self, from: data)
                        await captureManager.beginPlayback(with: sequence)
                    } catch {
                        // TODO: Surface error to user
                        print("Failed to load playback file: \(error)")
                    }
                }
            case .failure(let error):
                print("File selection failed: \(error)")
            }
        }
    }

    private func toggleRecording() {
        if captureManager.isRecording {
            Task { await captureManager.stopRecordingAndSave() }
        } else {
            captureManager.startRecording()
        }
    }

    private func togglePlayback() {
        if captureManager.isPlayingBack {
            captureManager.stopPlayback()
        } else {
            isShowingFileImporter = true
        }
    }
}
