//
//  ContentView.swift
//  ARCoach_demo
//
//  Created by Dvalab on 2025/10/28.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 20) {
                Text("AR Coach Demo")
                    .font(.largeTitle)
                    .padding(.bottom, 40)
                
                ToggleImmersiveSpaceButton()
                
                Divider()
                    .padding(.vertical)
                
                // 模式一：基础录制与回放 (复用 ImmersiveView 的功能)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mode 1: Basic Recording & Playback")
                            .font(.headline)
                        Text("Tap 'Show Immersive Space' above to enter the immersive space for gesture recording and playback.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // 模式二：书法过程比对
                NavigationLink(destination: CalligraphyComparisonView()) {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                        Text("Mode 2: Calligraphy Comparison")
                    }
                    .padding()
                    .frame(maxWidth: 300)
                    .background(Color.orange.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // 模式三：手势识别挑战
                NavigationLink(destination: GestureRecognitionView()) {
                    HStack {
                        Image(systemName: "hand.wave")
                        Text("Mode 3: Gesture Recognition Challenge")
                    }
                    .padding()
                    .frame(maxWidth: 300)
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .navigationTitle("主菜单")
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
