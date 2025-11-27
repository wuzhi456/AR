/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The input selection and waiting screen before the game starts.
*/

import SwiftUI

struct Lobby: View {
    @Environment(GameModel.self) var gameModel
    @State private var showRecordingModeSelection = false
    @State private var selectedInputKind: InputKind = .hands
    @State private var showRecordingFileSelector = false
    @State private var availableRecordings: [URL] = []
    
    var progressValue: Float {
        min(1, max(0, Float(gameModel.countDown) / 3.0 + 0.01))
    }
    
    var body: some View {
        if !gameModel.isInputSelected {
            if showRecordingModeSelection {
                recordingModeSelection
                    .frame(width: 634, height: 499)
            } else {
                inputSelection
                    .frame(width: 634, height: 499)
            }
        } else {
            if gameModel.isSharePlaying {
                multiWaiting
                    .frame(width: 634, height: 499)
            } else { // Solo
                Gauge(value: progressValue) {
                    EmptyView()
                }
                .labelsHidden()
                .animation(.default, value: progressValue)
                .gaugeStyle(.accessoryCircularCapacity)
                .scaleEffect(x: 3, y: 3, z: 1)
                .frame(width: 150, height: 150)
                .padding(75)
                .overlay {
                    Text(verbatim: "\(gameModel.countDown)")
                        .animation(.none, value: progressValue)
                        .font(.system(size: 64))
                        .bold()
                }
                .frame(width: 634, height: 499)
                .accessibilityHidden(true)
            }
        }
    }
    
    var inputSelection: some View {
        VStack {
            Text("Choose how you’ll cheer up grumpy clouds.", comment: "Asks the user about how they will want to control the game.")
                .font(.title)
                .padding(.top, 40)
                .padding(.bottom, 30)
            HStack(alignment: .top, spacing: 30) {
                VStack {
                    Button {
                        selectedInputKind = .hands
                        showRecordingModeSelection = true
                    } label: {
                        Label {
                            Text("Make a heart with two hands.", comment: "A way to control the game.")
                        } icon: {
                            Image("gesture_hand")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 216, height: 216)
                                .scaleEffect(x: 1.18, anchor: .center)
                                .offset(y: 30)
                        }
                        .labelStyle(.iconOnly)
                    }
                    .buttonBorderShape(.roundedRectangle(radius: 28))
                    .padding(.bottom, 10)
                    
                    Text("Make a heart with two hands.", comment: "A way to control the game.")
                        .font(.headline)
                        .frame(width: 260)
                        .accessibilityHidden(true)
                }

                VStack {
                    Button {
                        selectedInputKind = .alternative
                        showRecordingModeSelection = true
                    } label: {
                        Label {
                            Text("Use a pinch gesture or a compatible device.", comment: "A way to control the game.")
                        } icon: {
                            Image("keyboardGameController")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 216, height: 216)
                        }
                        .labelStyle(.iconOnly)
                    }
                    .buttonBorderShape(.roundedRectangle(radius: 28))
                    .padding(.bottom, 10)
                    
                    Text("Use a pinch gesture or a compatible device.", comment: "A way to control the game.")
                        .font(.headline)
                        .frame(width: 260)
                        .accessibilityHidden(true)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
        }
    }
    
    var recordingModeSelection: some View {
        VStack(spacing: 20) {
            Text("Choose recording mode", comment: "Asks the user about recording mode.")
                .font(.title)
                .padding(.top, 40)
                .padding(.bottom, 20)
            
            HStack(alignment: .top, spacing: 20) {
                VStack {
                    Button {
                        gameModel.recordingMode = .none
                        chooseInputAndReady(selectedInputKind)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            Text("Normal Play", comment: "Play without recording")
                                .font(.headline)
                        }
                        .frame(width: 160, height: 160)
                    }
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    
                    Text("Play normally", comment: "Description for normal play")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                }
                
                VStack {
                    Button {
                        gameModel.recordingMode = .record
                        chooseInputAndReady(selectedInputKind)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 60))
                                .foregroundStyle(.red)
                            Text("Record", comment: "Record hand motions")
                                .font(.headline)
                        }
                        .frame(width: 160, height: 160)
                    }
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    
                    Text("Record your hand motions", comment: "Description for recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                }
                
                VStack {
                    Button {
                        showRecordingFileSelector = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                            Text("Playback", comment: "Show recorded motions")
                                .font(.headline)
                        }
                        .frame(width: 160, height: 160)
                    }
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    
                    Text("Follow recorded guidance", comment: "Description for playback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                }
            }
            
            Button {
                showRecordingModeSelection = false
            } label: {
                Label("Back", systemImage: "chevron.backward")
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .sheet(isPresented: $showRecordingFileSelector) {
            recordingFileSelector
        }
        .onAppear {
            let manager = HandRecordingManager()
            availableRecordings = manager.getAvailableRecordings()
        }
    }
    
    var recordingFileSelector: some View {
        VStack(spacing: 20) {
            Text("Select a recording", comment: "Title for file selector")
                .font(.title)
                .padding(.top, 30)
            
            if availableRecordings.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("No recordings found", comment: "Message when no recordings exist")
                        .font(.headline)
                    Text("Record a gameplay session first", comment: "Instruction to record first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(40)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableRecordings, id: \.self) { url in
                            Button {
                                gameModel.selectedRecordingURL = url
                                gameModel.recordingMode = .playback
                                showRecordingFileSelector = false
                                chooseInputAndReady(selectedInputKind)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.fill")
                                    Text(url.lastPathComponent)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            Button {
                showRecordingFileSelector = false
            } label: {
                Text("Cancel", comment: "Cancel button")
            }
            .padding(.bottom, 30)
        }
        .frame(width: 500, height: 400)
        .onAppear {
            // Refresh recordings list when sheet appears
            let manager = HandRecordingManager()
            availableRecordings = manager.getAvailableRecordings()
            print("recordingFileSelector: Refreshed recordings, found \(availableRecordings.count)")
        }
    }
    
    func chooseInputAndReady(_ kind: InputKind) {
        gameModel.isInputSelected = true
        gameModel.inputKind = kind
        
        if gameModel.isSharePlaying {
            multiReady()
        } else {
            // Delay three seconds, then...
            gameModel.isCountDownReady = true
        }
    }
    
    func multiReady() {
        print("Sending local ready message for: ", sessionInfo?.session?.localParticipant.id.asPlayerName as Any)
        
        guard let localPlayer = gameModel.players.first(where: { $0.name == Player.localName }) else {
            print("Local Player isn't set")
            return
        }
        
        localPlayer.isReady = true
        gameModel.players = gameModel.players.filter { _ in true }
        sessionInfo?.reliableMessenger?.send(ReadyStateMessage(ready: true)) { error in
            if error != nil {
                print("Send score error:", error!)
            }
        }
    }
    
    var multiWaiting: some View {
        VStack(spacing: 20) {
            Image("shareplayGraphic")
            Text("Waiting for all players to choose.", comment: "Informative message about why the multi-player game has not yet started.")
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            HStack(spacing: 10) {
                ForEach(gameModel.players, id: \.name) { player in
                    if player.isReady {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                    } else {
                        ProgressView()
                    }
                }
            }
        }
    }
}

#Preview {
    Lobby()
        .environment(GameModel())
        .glassBackgroundEffect(
            in: RoundedRectangle(
                cornerRadius: 32,
                style: .continuous
            )
        )
}
