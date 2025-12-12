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
                    Text("模式一：基础录制与回放")
                        .font(.headline)
                    Text("点击上方 'Show Immersive Space' 进入沉浸式空间，即可进行手势录制与回放。")
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
                        Text("模式二：书法过程比对")
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
                        Text("模式三：手势识别挑战")
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
