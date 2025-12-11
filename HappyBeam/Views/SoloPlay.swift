/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The play screen for single player.
*/

import SwiftUI

struct SoloPlay: View {
    @Environment(GameModel.self) var gameModel
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(spacing: 0) {
                // Mode indicator
                if gameModel.soloGameMode != .normal {
                    recordingModeIndicator
                }
                
                if gameModel.soloGameMode == .recording {
                    // Recording mode UI
                    recordingModeUI
                } else {
                    // Normal/Playback mode UI
                    normalModeUI
                }
            }
            .padding(.vertical, 12)
        }
        .frame(width: 260)
        .confirmationDialog(
            "Unsaved Recording",
            isPresented: Binding(
                get: { gameModel.showingSaveConfirmation },
                set: { gameModel.showingSaveConfirmation = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("Save Recording") {
                NotificationCenter.default.post(name: .saveRecordingRequested, object: nil)
            }
            Button("Discard", role: .destructive) {
                NotificationCenter.default.post(name: .discardRecordingRequested, object: nil)
            }
            Button("Cancel", role: .cancel) {
                gameModel.showingSaveConfirmation = false
            }
        } message: {
            Text("You have unsaved recording data. What would you like to do?")
        }
        .task {
            do {
                #if targetEnvironment(simulator)
                let shouldAddProjector = true
                #else
                let shouldAddProjector = gameModel.inputKind == .alternative
                #endif

                if shouldAddProjector, heart != nil {
                    try await addFloorBeamMaterials()
                }
            } catch {
                print(error)
            }
        }
    }
    
    // MARK: - Mode Indicator
    
    private var recordingModeIndicator: some View {
        HStack {
            Image(systemName: recordingModeIcon)
                .foregroundColor(recordingModeColor)
            Text(recordingModeText)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            .ultraThinMaterial,
            in: Capsule()
        )
        .padding(.bottom, 4)
    }
    
    private var recordingModeIcon: String {
        if gameModel.soloGameMode == .recording {
            return gameModel.isActivelyRecording ? "record.circle.fill" : "record.circle"
        } else {
            return "play.circle"
        }
    }
    
    private var recordingModeColor: Color {
        if gameModel.soloGameMode == .recording {
            return gameModel.isActivelyRecording ? .red : .gray
        } else {
            return .green
        }
    }
    
    private var recordingModeText: String {
        if gameModel.soloGameMode == .recording {
            return gameModel.isActivelyRecording ? "Recording" : "Ready to Record"
        } else {
            return "Playback"
        }
    }
    
    // MARK: - Recording Mode UI
    
    private var recordingModeUI: some View {
        VStack(spacing: 0) {
            // Elapsed time display
            HStack(alignment: .top) {
                Button {
                    handleBackButton()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                }
                .offset(x: -23)
                
                Text(formattedElapsedTime)
                    .font(.system(size: 50))
                    .bold()
                    .monospacedDigit()
                    .foregroundColor(gameModel.isActivelyRecording ? .red : .primary)
                    .accessibilityLabel(Text("Elapsed Time"))
                    .accessibilityValue(Text(formattedElapsedTime))
                    .padding(.leading, 0)
                    .padding(.trailing, 40)
            }
            
            Text(gameModel.isActivelyRecording ? "recording" : "ready")
                .font(.system(size: 24))
                .bold()
                .accessibilityHidden(true)
                .offset(y: -5)
            
            // Recording control buttons
            HStack(spacing: 8) {
                Button {
                    gameModel.isMuted.toggle()
                } label: {
                    Label(
                        gameModel.isMuted
                        ? String(localized: "Play music", comment: "Button to play music")
                        : String(localized: "Stop music", comment: "Button to stop music"),
                        systemImage: gameModel.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill"
                    )
                        .labelStyle(.iconOnly)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                // Start/Stop Recording button
                Button {
                    handleRecordingToggle()
                } label: {
                    Label(
                        gameModel.isActivelyRecording ? "Stop Recording" : "Start Recording",
                        systemImage: gameModel.isActivelyRecording ? "stop.circle.fill" : "record.circle"
                    )
                    .labelStyle(.iconOnly)
                    .foregroundColor(gameModel.isActivelyRecording ? .red : .primary)
                }
                
                // Save button (only visible after stopping with unsaved data)
                if !gameModel.isActivelyRecording && gameModel.hasUnsavedRecording {
                    Button {
                        NotificationCenter.default.post(name: .saveRecordingRequested, object: nil)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .labelStyle(.iconOnly)
                    }
                }
                
                Spacer()
                
                // Discard button (only visible after stopping with unsaved data)
                if !gameModel.isActivelyRecording && gameModel.hasUnsavedRecording {
                    Button {
                        NotificationCenter.default.post(name: .discardRecordingRequested, object: nil)
                    } label: {
                        Label("Discard", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .padding(.trailing, 8)
                }
            }
            .background(
                .regularMaterial,
                in: .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .frame(width: 260, height: 70)
            .offset(y: 15)
        }
    }
    
    private var formattedElapsedTime: String {
        let totalSeconds = Int(gameModel.recordingElapsedTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let tenths = Int((gameModel.recordingElapsedTime - Double(totalSeconds)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
    
    // MARK: - Normal/Playback Mode UI
    
    private var normalModeUI: some View {
        VStack(spacing: 0) {
            let progress = Float(gameModel.timeLeft) / Float(GameModel.gameTime)
            HStack(alignment: .top) {
                Button {
                    Task {
                        await dismissImmersiveSpace()
                    }
                    gameModel.reset()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                }
                .offset(x: -23)
                Text(verbatim: "\(String(format: "%02d", gameModel.score))")
                    .font(.system(size: 60))
                    .bold()
                    .accessibilityLabel(Text("Score",
                                comment: "For accessibility: A string that indicates this number is the player's current score in the game."))
                    .accessibilityValue(Text(verbatim: "\(gameModel.score)"))
                .padding(.leading, 0)
                .padding(.trailing, 60)
            }
            Text("score", comment: "A string that indicates the number immediately above is the player's current score in the game.")
                .font(.system(size: 30))
                .bold()
                .accessibilityHidden(true)
                .offset(y: -5)
            HStack {
                Button {
                    gameModel.isMuted.toggle()
                } label: {
                    Label(
                        gameModel.isMuted
                        ? String(localized: "Play music", comment: "Button to play music")
                        : String(localized: "Stop music", comment: "Button to stop music"),
                        systemImage: gameModel.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill"
                    )
                        .labelStyle(.iconOnly)
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
                ProgressView(value: (progress > 1.0 || progress < 0.0) ? 1.0 : progress)
                    .contentShape(.accessibility, Capsule().offset(y: -3))
                    .accessibilityLabel(Text(verbatim: ""))
                    .accessibilityValue(Text("\(gameModel.timeLeft) seconds remaining"))
                    .tint(Color(uiColor: UIColor(red: 242 / 255, green: 68 / 255, blue: 206 / 255, alpha: 1.0)))
                    .padding(.vertical, 30)
                Button {
                    gameModel.isPaused.toggle()
                    gameModel.isMuted.toggle()
                } label: {
                    if gameModel.isPaused {
                        Label(String(localized: "Play", comment: "Button to play the game"), systemImage: "play.fill")
                            .labelStyle(.iconOnly)
                    } else {
                        Label(String(localized: "Pause", comment: "Button to pause the game"), systemImage: "pause.fill")
                            .labelStyle(.iconOnly)
                    }
                }
                .padding(.trailing, 12)
                .padding(.leading, 10)
            }
            .background(
                .regularMaterial,
                in: .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .frame(width: 260, height: 70)
            .offset(y: 15)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleBackButton() {
        if gameModel.hasUnsavedRecording {
            gameModel.showingSaveConfirmation = true
        } else {
            Task {
                await dismissImmersiveSpace()
            }
            gameModel.reset()
        }
    }
    
    private func handleRecordingToggle() {
        if gameModel.isActivelyRecording {
            // Stop recording
            NotificationCenter.default.post(name: .stopRecordingRequested, object: nil)
        } else {
            // Check for unsaved data before starting new recording
            if gameModel.hasUnsavedRecording {
                gameModel.showingSaveConfirmation = true
            } else {
                // Start recording
                NotificationCenter.default.post(name: .startRecordingRequested, object: nil)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingRequested = Notification.Name("startRecordingRequested")
    static let stopRecordingRequested = Notification.Name("stopRecordingRequested")
    static let saveRecordingRequested = Notification.Name("saveRecordingRequested")
    static let discardRecordingRequested = Notification.Name("discardRecordingRequested")
}

#Preview {
    VStack {
        Spacer()
        SoloPlay()
            .environment(GameModel())
            .glassBackgroundEffect(
                in: RoundedRectangle(
                    cornerRadius: 32,
                    style: .continuous
                )
            )
    }
}
