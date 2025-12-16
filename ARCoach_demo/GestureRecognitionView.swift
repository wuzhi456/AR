import SwiftUI

// Gesture Recognition View
struct GestureRecognitionView: View {
    @EnvironmentObject private var captureManager: HandCaptureManager // Use Shared Manager
    @State private var recognizedGestureName: String = "等待识别..."
    @State private var recognizedScore: Float = 0.0
    @State private var recognizedIcon: String = "hand.raised"
    @State private var isRecognizing = false
    @State private var timeRemaining = 5
    
    // 投票箱：记录5秒内每个手势出现的次数
    @State private var recognitionCounts: [String: Int] = [:]
    
    private let recognitionManager = GestureRecognitionManager()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Gesture Recognition Challenge")
                .font(.largeTitle)
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .foregroundColor(Color.blue.opacity(0.3))
                    .frame(width: 200, height: 200)
                
                if isRecognizing {
                    Text("\(timeRemaining)")
                        .font(.system(size: 80, weight: .bold))
                } else {
                    Image(systemName: recognizedIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                }
            }
            
            Text(recognizedGestureName)
                .font(.title)
                .padding()
            
            if !isRecognizing {
                Button(action: {
                    startRecognitionSession()
                }) {
                    Text("Start 5s Recognition Challenge")
                        .font(.headline)
                        .padding()
                        .frame(width: 200)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else {
                Text("Please present the gesture to the camera...")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: captureManager.latestRightHand) { newValue in
            guard isRecognizing, let handInfo = newValue else { return }
            processFrame(handInfo)
        }
        .onChange(of: captureManager.latestLeftHand) { newValue in
            guard isRecognizing, let handInfo = newValue else { return }
            processFrame(handInfo)
        }
    }
    
    private func processFrame(_ handInfo: HVHandInfo) {
        if let result = recognitionManager.recognizeGesture(handInfo: handInfo) {
            // Voting logic: while recognizing, tally votes per recognized gesture
            if isRecognizing {
                // Assume result has a 'name' property
                let gestureName = result.name
                recognitionCounts[gestureName, default: 0] += 1
            }
        }
    }
    
    private func startRecognitionSession() {
        isRecognizing = true
        timeRemaining = 5
        recognizedGestureName = "识别中..."
        recognitionCounts = [:] // 清空之前的投票记录
        
        // Countdown timer logic
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                timer.invalidate()
                self.finishRecognition()
            }
        }
    }
    
    private func finishRecognition() {
        isRecognizing = false

        // Tally results: pick the gesture with the highest votes
        if let (bestGesture, count) = recognitionCounts.max(by: { $0.value < $1.value }) {
            self.recognizedGestureName = "Recognition Result: \(bestGesture)"
            self.recognizedIcon = "checkmark.circle.fill"
            print("5s challenge finished. Winner: \(bestGesture), votes: \(count)")
        } else {
            self.recognizedGestureName = "No clear gesture detected"
            self.recognizedIcon = "questionmark.circle"
        }
    }
}
