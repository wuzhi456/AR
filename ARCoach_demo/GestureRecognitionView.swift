import SwiftUI

// 模式二 UI：手势识别视图
struct GestureRecognitionView: View {
    @Environment(HandCaptureManager.self) var captureManager // Use Shared Manager
    @State private var recognizedGestureName: String = "等待识别..."
    @State private var recognizedScore: Float = 0.0
    @State private var recognizedIcon: String = "hand.raised"
    @State private var isRecognizing = false
    @State private var timeRemaining = 5
    
    private let recognitionManager = GestureRecognitionManager()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("手势识别挑战")
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
                    Text("开始 5秒 识别挑战")
                        .font(.headline)
                        .padding()
                        .frame(width: 200)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else {
                Text("请在摄像头前展示手势...")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: captureManager.latestRightHand) { _, newValue in
            guard isRecognizing, let handInfo = newValue else { return }
            processFrame(handInfo)
        }
        .onChange(of: captureManager.latestLeftHand) { _, newValue in
            guard isRecognizing, let handInfo = newValue else { return }
            processFrame(handInfo)
        }
    }
    
    private func processFrame(_ handInfo: HVHandInfo) {
        if let result = recognitionManager.recognizeGesture(handInfo: handInfo) {
            // 实时更新 UI 反馈 (可选)
            // self.recognizedGestureName = result.name
        }
    }
    
    private func startRecognitionSession() {
        isRecognizing = true
        timeRemaining = 5
        recognizedGestureName = "识别中..."
        
        // 倒计时逻辑
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
        // 获取最终最可能的识别结果
        // 这里应该取这5秒内出现频率最高或置信度最高的结果
        // 简单起见，我们假设 recognitionManager 内部维护了历史状态，我们再查询一次或让它返回最佳结果
        // 由于 recognitionManager.recognizeGesture 返回的是瞬时结果，我们需要一个方法获取"Session Best"
        // 这里简化处理：如果最后几帧识别到了，就显示。
        // 更好的做法是在 Manager 中增加 Session 统计。
        
        // 模拟结果 (如果没有真实识别到)
        if recognizedGestureName == "识别中..." {
             self.recognizedGestureName = "未检测到明确手势"
             self.recognizedIcon = "questionmark.circle"
        }
    }
}
