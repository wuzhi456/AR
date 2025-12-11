import SwiftUI
import RealityKit

// 模式一 UI：书法比对视图
struct CalligraphyComparisonView: View {
    @Environment(HandCaptureManager.self) var captureManager // Use Shared Manager
    @State private var isRecording = false
    @State private var recordedFrames: [HVHandInfo] = []
    @State private var comparisonResult: CalligraphyComparisonManager.DTWResult?
    @State private var comparisonScore: Float = 0.0
    
    // 假设有一个 Coach 的录制数据 (实际应从文件加载)
    @State private var coachSequence: CalligraphyComparisonManager.GestureSequence?
    
    private let comparisonManager = CalligraphyComparisonManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("书法过程比对")
                .font(.title)
            
            HStack {
                Button(action: {
                    // 模拟加载 Coach 数据
                    loadCoachData()
                }) {
                    Text("加载范例 (Coach)")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    toggleRecording()
                }) {
                    Text(isRecording ? "停止录制" : "开始录制 (User)")
                        .padding()
                        .background(isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            if let result = comparisonResult {
                VStack {
                    Text("比对结果")
                        .font(.headline)
                    Text("相似度得分: \(String(format: "%.2f", result.normalizedScore * 100))%")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(scoreColor(result.normalizedScore))
                    
                    Text("DTW 距离: \(String(format: "%.2f", result.distance))")
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)
            } else if isRecording {
                Text("正在录制... 帧数: \(recordedFrames.count)")
                    .foregroundColor(.red)
            } else {
                Text("请加载范例并录制您的动作进行比对")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: captureManager.latestRightHand) { _, newValue in
            guard isRecording, let handInfo = newValue else { return }
            // 默认录制右手，如果需要支持左手，可以增加 UI 选项切换
            recordedFrames.append(handInfo)
        }
    }
    
    private func loadCoachData() {
        // TODO: 从 JSON 文件加载
        // 这里仅作演示，创建一个空的或模拟的序列
        print("Loading coach data...")
        // coachSequence = ...
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            recordedFrames.removeAll()
            // 开始监听帧更新 (伪代码)
            // Timer.scheduledTimer(...) { append frame }
        } else {
            // 停止录制，进行比对
            performComparison()
        }
    }
    
    private func performComparison() {
        guard let coach = coachSequence else {
            print("No coach data loaded")
            return
        }
        
        let userSeq = CalligraphyComparisonManager.GestureSequence(
            frames: recordedFrames,
            timestamps: [], // 简化，暂不使用时间戳
            chirality: .right // 假设用户使用右手，实际应从数据获取
        )
        
        if let result = comparisonManager.compareSequences(coachSequence: coach, userSequence: userSeq) {
            self.comparisonResult = result
        }
    }
    
    private func scoreColor(_ score: Float) -> Color {
        if score > 0.8 { return .green }
        if score > 0.5 { return .yellow }
        return .red
    }
}
