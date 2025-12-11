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
    @State private var showingSoloOptions = false
    @State private var showingRecordingsList = false
    @State private var savedRecordings: [URL] = []
    
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image("splashScreen")
                .resizable()
                .frame(width: 337, height: 211)
                .accessibilityHidden(true)
            Text("Happy Beam", comment: "The name of the game.")
                .font(.system(size: 30, weight: .bold))
            Text("Cheer up grumpy clouds by shining a happy beam with your heart.", comment: "This text explains the purpose of the game.")
                .multilineTextAlignment(.center)
                .font(.headline)
                .frame(width: 340)
                .padding(.bottom, 10)
            if gameModel.readyToStart {
                if showingRecordingsList {
                    recordingsListView
                } else if showingSoloOptions {
                    soloModeSelection
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
                showingSoloOptions = true
            } label: {
                Text("Play Solo", comment: "A game mode where the player plays in single-player mode.")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!gameModel.readyToStart)
            
            Button {
                print("Starting as SharePlay", groupStateObserver.isEligibleForGroupSession)
                
                Task {
                    do {
                        try await startSession()
                    } catch {
                        print("SharePlay session failure", error)
                    }
                }
            } label: {
                Text("Play with Friends", comment: "A game mode where the player plays in multi-player mode.")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!groupStateObserver.isEligibleForGroupSession)
        }
        .font(.system(size: 16, weight: .bold))
        .frame(width: 200)
    }
    
    var soloModeSelection: some View {
        VStack(spacing: 12) {
            Text("Select Game Mode", comment: "Title for solo mode selection")
                .font(.headline)
                .padding(.bottom, 5)
            
            Button {
                gameModel.soloGameMode = .normal
                startSoloGame()
            } label: {
                Text("Normal Play", comment: "Normal gameplay mode")
                    .frame(maxWidth: .infinity)
            }
            
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
                showingSoloOptions = false
            } label: {
                Text("Back", comment: "Go back to main menu")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .font(.system(size: 16, weight: .bold))
        .frame(width: 200)
    }
    
    var recordingsListView: some View {
        VStack(spacing: 12) {
            Text("Select Recording", comment: "Title for recordings list")
                .font(.headline)
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
                // Show recording buttons directly without ScrollView to debug
                VStack(spacing: 8) {
                    ForEach(Array(savedRecordings.enumerated()), id: \.offset) { index, url in
                        Button {
                            print("Selected recording: \(url.lastPathComponent)")
                            loadAndStartPlayback(from: url)
                        } label: {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: 200)
            }
            
            Button {
                isShowingFileImporter = true
            } label: {
                Text("Import from Files", comment: "Import recording from file system")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button {
                showingRecordingsList = false
            } label: {
                Text("Back", comment: "Go back to mode selection")
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
        gameModel.timeLeft = GameModel.gameTime
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
