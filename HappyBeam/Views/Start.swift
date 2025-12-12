/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The start screen for the game.
*/

import SwiftUI
import GroupActivities
import UniformTypeIdentifiers

struct Start: View {
    @Environment(GameModel.self) var gameModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    @StateObject private var groupStateObserver = GroupStateObserver()
    @State private var isShowingFileImporter = false
    @State private var showingRecordingsList = false
    @State private var savedRecordings: [URL] = []
    @State private var recordingPendingDeletion: URL?
    
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("ARCOACH DEMO")
                .font(.system(size: 30, weight: .bold))
            if gameModel.readyToStart {
                if showingRecordingsList {
                    recordingsListView
                } else {
                    mainMenu
                }
            } else {
                ProgressView("Loading assets…")
            }
            
            Spacer()
        }
        .padding(.horizontal, 150)
        .frame(width: 634, height: 499)
        .onAppear {
            gameModel.menuPlayer.volume = 0.6
            gameModel.menuPlayer.numberOfLoops = -1
            gameModel.menuPlayer.currentTime = 0
            gameModel.menuPlayer.play()
        }
        .fileImporter(isPresented: $isShowingFileImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadAndStartPlayback(from: url)
            case .failure(let error):
                print("File selection failed: \(error)")
            }
        }
    }
    
    var mainMenu: some View {
        Group {
            Button {
                gameModel.soloGameMode = .recording
                startSoloGame()
            } label: {
                Text("Recording Mode", comment: "Mode to record hand movements")
                    .frame(maxWidth: .infinity)
            }

            Button {
                refreshRecordingsList()
                showingRecordingsList = true
            } label: {
                Text("Playback Mode", comment: "Mode to play with recorded hand data")
                    .frame(maxWidth: .infinity)
            }
            
            Button {
                gameModel.isCalligraphyComparisonMode = true
            } label: {
                Text("Calligraphy Comparison")
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 16, weight: .bold))
        .frame(width: 200)
    }
    
    var recordingsListView: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showingRecordingsList = false
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Replay")
                    .font(.headline)

                Spacer()

                // Keep the title visually centered.
                Color.clear
                    .frame(width: 70, height: 1)
            }
            .padding(.bottom, 5)
            
            // Debug: show count
            Text("Found \(savedRecordings.count) recordings")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if savedRecordings.isEmpty {
                Text("No recordings found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Use ScrollView with proper spacing for the recording list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(savedRecordings.enumerated()), id: \.offset) { index, url in
                            HStack(spacing: 8) {
                                Button(action: {
                                    print("Button tapped for: \(url.lastPathComponent)")
                                    loadAndStartPlayback(from: url)
                                }) {
                                    Text(url.deletingPathExtension().lastPathComponent)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)

                                Button(role: .destructive) {
                                    recordingPendingDeletion = url
                                } label: {
                                    Text("Delete")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: min(CGFloat(savedRecordings.count) * 50, 180))
            }
            
            Button(action: {
                isShowingFileImporter = true
            }) {
                Text("Import from Files", comment: "Import recording from file system")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
        }
        .font(.system(size: 16, weight: .bold))
        .frame(width: 280)
        .onAppear {
            // Refresh list when view appears to ensure state is current
            print("recordingsListView onAppear - current count: \(savedRecordings.count)")
            refreshRecordingsList()
            print("recordingsListView onAppear - after refresh count: \(savedRecordings.count)")
        }
        .confirmationDialog(
            "Delete this recording?",
            isPresented: Binding(
                get: { recordingPendingDeletion != nil },
                set: { if !$0 { recordingPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let url = recordingPendingDeletion {
                    deleteRecordingFile(at: url)
                }
                recordingPendingDeletion = nil
            }

            Button("Cancel", role: .cancel) {
                recordingPendingDeletion = nil
            }
        } message: {
            if let url = recordingPendingDeletion {
                Text(url.lastPathComponent)
            }
        }
    }
    
    private func refreshRecordingsList() {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            savedRecordings = []
            return
        }
        
        print("Looking for recordings in: \(directory.path)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            print("Found \(files.count) files in Documents directory")
            for file in files {
                print("  - \(file.lastPathComponent)")
            }
            savedRecordings = files.filter { $0.lastPathComponent.hasPrefix("HandPose_") && $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            print("Filtered to \(savedRecordings.count) HandPose recordings")
        } catch {
            print("Failed to list recordings: \(error)")
            savedRecordings = []
        }
    }
    
    private func startSoloGame() {
        gameModel.isPlaying = true
        
        // For recording and playback modes, skip countdown and go directly to the space
        if gameModel.soloGameMode == .recording || gameModel.soloGameMode == .playback {
            // Skip the normal game flow - directly open immersive space
            gameModel.isInputSelected = true
            gameModel.inputKind = .hands
            gameModel.isSoloReady = true
            // Stop menu music
            gameModel.menuPlayer.pause()
            Task {
                await openImmersiveSpace(id: "happyBeam")
            }
        } else {
            gameModel.timeLeft = GameModel.gameTime
        }
    }
    
    private func loadAndStartPlayback(from url: URL) {
        do {
            // Try security-scoped access first (for files from file importer)
            let needsSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if needsSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = try Data(contentsOf: url)
            let recording = try JSONDecoder().decode(HandPoseRecording.self, from: data)
            gameModel.playbackRecording = recording
            gameModel.soloGameMode = .playback
            showingRecordingsList = false
            startSoloGame()
        } catch {
            print("Failed to load recording: \(error)")
        }
    }

    private func deleteRecordingFile(at url: URL) {
        do {
            // For files created in-app (Documents), this should succeed without security-scoped access.
            try FileManager.default.removeItem(at: url)
            refreshRecordingsList()
        } catch {
            print("Failed to delete recording file: \(error)")
        }
    }
}

#Preview {
    Start()
        .environment(GameModel())
        .glassBackgroundEffect(
            in: RoundedRectangle(
                cornerRadius: 32,
                style: .continuous
            )
        )
}