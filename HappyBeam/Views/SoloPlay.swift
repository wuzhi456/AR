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
                
                switch gameModel.soloGameMode {
                case .recording:
                    // Recording mode UI
                    recordingModeUI
                case .playback:
                    // Playback mode UI
                    playbackModeUI
                case .practice:
                    practiceModeUI
                case .normal:
                    // Normal mode UI
                    normalModeUI
                }
            }
            .padding(.vertical, 12)
        }
        .frame(width: 360)
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
        switch gameModel.soloGameMode {
        case .recording:
            return gameModel.isActivelyRecording ? "record.circle.fill" : "record.circle"
        case .playback:
            return gameModel.isActivelyPlayingBack ? "play.circle.fill" : "play.circle"
        case .practice:
            return gameModel.isActivelyPlayingBack ? "hand.point.up.left.fill" : "hand.point.up.left"
        case .normal:
            return "play.circle"
        }
    }
    
    private var recordingModeColor: Color {
        switch gameModel.soloGameMode {
        case .recording:
            return gameModel.isActivelyRecording ? .red : .gray
        case .playback:
            return gameModel.isActivelyPlayingBack ? .green : .gray
        case .practice:
            return gameModel.isActivelyPlayingBack ? .blue : .gray
        case .normal:
            return .gray
        }
    }
    
    private var recordingModeText: String {
        switch gameModel.soloGameMode {
        case .recording:
            return gameModel.isActivelyRecording ? "Recording" : "Ready to Record"
        case .playback:
            return gameModel.isActivelyPlayingBack ? "Playing" : "Ready to Play"
        case .practice:
            return gameModel.isActivelyPlayingBack ? "Practicing" : "Ready to Practice"
        case .normal:
            return ""
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
            .frame(width: 360, height: 70)
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
    
    private var formattedPlaybackTime: String {
        let totalSeconds = Int(gameModel.playbackElapsedTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let tenths = Int((gameModel.playbackElapsedTime - Double(totalSeconds)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
    
    private var formattedPlaybackDuration: String {
        let totalSeconds = Int(gameModel.playbackTotalDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var practiceHandLabel: String {
        "Hand: \(gameModel.practiceHand.displayName)"
    }

    private var practiceFrameInfo: String? {
        guard let recording = gameModel.practiceRecording else { return nil }
        let total = recording.frames.count
        let idx = nearestPracticeFrameIndex(in: recording)
        let ts = recording.frames[idx].timestamp
        return String(format: "帧 %d/%d · t=%.2fs", idx + 1, total, ts)
    }

    private func nearestPracticeFrameIndex(in recording: HandPoseRecording) -> Int {
        if let idx = recording.frames.enumerated().min(by: { abs($0.element.timestamp - gameModel.playbackElapsedTime) < abs($1.element.timestamp - gameModel.playbackElapsedTime) })?.offset {
            return idx
        }
        return 0
    }

    private var isPlaybackFinished: Bool {
        guard gameModel.playbackTotalDuration > 0 else { return false }
        // Allow a small epsilon for floating point comparison
        return gameModel.playbackElapsedTime >= gameModel.playbackTotalDuration - 0.1
    }
    
    private var playbackButtonIcon: String {
        if gameModel.isActivelyPlayingBack {
            return "pause.circle.fill"
        } else if isPlaybackFinished {
            return "arrow.counterclockwise.circle.fill"
        } else {
            return "play.circle"
        }
    }
    
    private var playbackButtonLabel: String {
        if gameModel.isActivelyPlayingBack {
            return "Pause Playback"
        } else if isPlaybackFinished {
            return "Replay"
        } else {
            return "Start Playback"
        }
    }
    
    private var playbackStatusText: String {
        if gameModel.isActivelyPlayingBack {
            return "playing"
        } else if isPlaybackFinished {
            return "ready"
        } else {
            return "ready"
        }
    }
    
    @State private var playbackSpeed: Double = 1.0
    
    // MARK: - Playback Mode UI
    
    private var playbackModeUI: some View {
        VStack(spacing: 0) {
            // Time display
            HStack(alignment: .top) {
                Button {
                    handlePlaybackBackButton()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                }
                .offset(x: -23)
                
                VStack(spacing: 0) {
                    Text(formattedPlaybackTime)
                        .font(.system(size: 50))
                        .bold()
                        .monospacedDigit()
                        .foregroundColor(gameModel.isActivelyPlayingBack ? .green : .primary)
                        .accessibilityLabel(Text("Playback Time"))
                        .accessibilityValue(Text(formattedPlaybackTime))
                    
                    if gameModel.playbackTotalDuration > 0 {
                        Text("/ \(formattedPlaybackDuration)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.leading, 0)
                .padding(.trailing, 40)
            }
            
            Text(playbackStatusText)
                .font(.system(size: 24))
                .bold()
                .accessibilityHidden(true)
                .offset(y: -5)
            
            // Speed Control
            Picker("Speed", selection: $playbackSpeed) {
                Text("0.5x").tag(0.5)
                Text("0.75x").tag(0.75)
                Text("1.0x").tag(1.0)
                Text("1.5x").tag(1.5)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .padding(.bottom, 8)
            .onChange(of: playbackSpeed) { _, newSpeed in
                NotificationCenter.default.post(name: .setPlaybackSpeedRequested, object: newSpeed)
            }
            
            // Playback control buttons
            HStack(spacing: 8) {
                Spacer()
                
                // Play/Pause/Replay button
                Button {
                    handlePlaybackToggle()
                } label: {
                    Label(
                        playbackButtonLabel,
                        systemImage: playbackButtonIcon
                    )
                    .labelStyle(.iconOnly)
                    .foregroundColor(gameModel.isActivelyPlayingBack ? .green : .primary)
                }
                
                // Stop button (reset playback to beginning)
                // Only show stop button if playing or paused (not finished)
                if (gameModel.isActivelyPlayingBack || gameModel.playbackElapsedTime > 0) && !isPlaybackFinished {
                    Button {
                        NotificationCenter.default.post(name: .stopPlaybackRequested, object: nil)
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                            .labelStyle(.iconOnly)
                    }
                }
                
                Spacer()
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
            .frame(width: 360, height: 70)
            .offset(y: 15)
        }
    }

    // MARK: - Practice Mode UI
    private var practiceModeUI: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Button {
                    handlePracticeBackButton()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                }
                .offset(x: -23)
                
                VStack(spacing: 2) {
                    Text(formattedPlaybackTime)
                        .font(.system(size: 44))
                        .bold()
                        .monospacedDigit()
                        .foregroundColor(gameModel.isActivelyPlayingBack ? .blue : .primary)
                        .accessibilityLabel(Text("Practice Time"))
                        .accessibilityValue(Text(formattedPlaybackTime))
                    Text(practiceHandLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let practiceInfo = practiceFrameInfo {
                        Text(practiceInfo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if let name = gameModel.practiceRecordingName {
                        Text(name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.trailing, 30)
            }
            
            Text(gameModel.isActivelyPlayingBack ? "practicing" : "ready")
                .font(.system(size: 22))
                .bold()
                .accessibilityHidden(true)
                .offset(y: -4)
            
            // Speed Control
            Picker("Speed", selection: $playbackSpeed) {
                Text("0.5x").tag(0.5)
                Text("0.75x").tag(0.75)
                Text("1.0x").tag(1.0)
                Text("1.5x").tag(1.5)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .padding(.bottom, 8)
            .onChange(of: playbackSpeed) { _, newSpeed in
                NotificationCenter.default.post(name: .setPlaybackSpeedRequested, object: newSpeed)
            }
            
            HStack(spacing: 8) {
                Spacer()
                
                Button {
                    handlePracticeToggle()
                } label: {
                    Label(
                        gameModel.isActivelyPlayingBack ? "Pause Practice" : "Start Practice",
                        systemImage: gameModel.isActivelyPlayingBack ? "pause.circle.fill" : "play.circle"
                    )
                    .labelStyle(.iconOnly)
                    .foregroundColor(gameModel.isActivelyPlayingBack ? .blue : .primary)
                }
                
                if gameModel.isActivelyPlayingBack || gameModel.playbackElapsedTime > 0 {
                    Button {
                        NotificationCenter.default.post(name: .stopPlaybackRequested, object: nil)
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                            .labelStyle(.iconOnly)
                    }
                }
                
                Spacer()
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
            .frame(width: 360, height: 70)
            .offset(y: 15)
        }
    }
    
    // MARK: - Normal Mode UI
    
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
            .frame(width: 360, height: 70)
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
    
    private func handlePlaybackBackButton() {
        // Pause playback if running (don't fully stop -- we want to preserve
        // the playback position so the user can resume later).
        if gameModel.isActivelyPlayingBack {
            NotificationCenter.default.post(name: .pausePlaybackRequested, object: nil)
        }
        
        // Clear playback state when exiting
        NotificationCenter.default.post(name: .stopPlaybackRequested, object: nil)

        // Request that Start show the recordings list once immersive space is dismissed.
        NotificationCenter.default.post(name: .showRecordingsListRequested, object: nil)

        Task {
            await dismissImmersiveSpace()
        }

        // Preserve playbackRecording in GameModel; just clear UI flags.
        gameModel.isPlaying = false
        gameModel.isSoloReady = false
        gameModel.isActivelyPlayingBack = false
    }
    
    private func handlePracticeToggle() {
        if gameModel.isActivelyPlayingBack {
            NotificationCenter.default.post(name: .pausePlaybackRequested, object: nil)
        } else {
            NotificationCenter.default.post(name: .startPlaybackRequested, object: nil)
        }
    }

    private func handlePracticeBackButton() {
        if gameModel.isActivelyPlayingBack {
            NotificationCenter.default.post(name: .stopPlaybackRequested, object: nil)
        }
        Task {
            await dismissImmersiveSpace()
        }
        gameModel.reset()
    }
    
    private func handlePlaybackToggle() {
        if isPlaybackFinished {
            // Replay logic: Reset and start
            NotificationCenter.default.post(name: .stopPlaybackRequested, object: nil)
            // Small delay to allow stop to process
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .startPlaybackRequested, object: nil)
            }
        } else if gameModel.isActivelyPlayingBack {
            NotificationCenter.default.post(name: .pausePlaybackRequested, object: nil)
        } else {
            NotificationCenter.default.post(name: .startPlaybackRequested, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingRequested = Notification.Name("startRecordingRequested")
    static let stopRecordingRequested = Notification.Name("stopRecordingRequested")
    static let saveRecordingRequested = Notification.Name("saveRecordingRequested")
    static let discardRecordingRequested = Notification.Name("discardRecordingRequested")
    static let startPlaybackRequested = Notification.Name("startPlaybackRequested")
    static let pausePlaybackRequested = Notification.Name("pausePlaybackRequested")
    static let stopPlaybackRequested = Notification.Name("stopPlaybackRequested")
    static let showRecordingsListRequested = Notification.Name("showRecordingsListRequested")
    static let setPlaybackSpeedRequested = Notification.Name("setPlaybackSpeedRequested")
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
