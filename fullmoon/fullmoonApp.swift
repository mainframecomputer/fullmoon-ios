//
//  fullmoonApp.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI
import MLXLLM

@main
struct fullmoonApp: App {
    @StateObject var appManager = AppManager()
    @StateObject var speechSynthesizer = SpeechSynthesizer.shared
    @State var llm = LLMEvaluator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Thread.self, Message.self])
                .environmentObject(appManager)
                .environmentObject(speechSynthesizer)
                .environment(llm)
                .environment(DeviceStat())
        }
    }
}
