//
//  SpeechSettingsView.swift
//  fullmoon
//
//  Created by Kuba Szulaczkowski on 11/1/24.
//

import AVFoundation
import SwiftUI

struct SpeechSettingsView: View {
    @EnvironmentObject var speechSynthesizer: SpeechSynthesizer    
    @State private var textToSpeak: String = "Hi, I'm a helpful assistant!"
    
    var body: some View {
        List {
            Section {
                Toggle("auto speak responses", isOn: $speechSynthesizer.auto)
            }
            
            Section {
                Picker(selection: $speechSynthesizer.voice) {
                    ForEach(AVSpeechSynthesisVoice.speechVoices().filter({ $0.language.hasPrefix("en") }), id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                    }
                } label: {
                    Label("voice", systemImage: "bubble")
                }
                .onChange(of: speechSynthesizer.voice, speak)
            }
            
            HStack(spacing: 16) {
                Text("volume: 1.00")
                    .hidden()
                    .overlay(alignment: .leading) {
                        Text("rate: \(speechSynthesizer.rate, specifier: "%.2f")")
                    }
                Slider(value: $speechSynthesizer.rate, in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate), onEditingChanged: handleEditingChanged)
            }
            
            HStack(spacing: 16) {
                Text("volume: 1.00")
                    .hidden()
                    .overlay(alignment: .leading) {
                        Text("pitch: \(speechSynthesizer.pitch, specifier: "%.2f")")
                    }
                Slider(value: $speechSynthesizer.pitch, in: 0.5...2.0, onEditingChanged: handleEditingChanged)
            }
            
            HStack(spacing: 16) {
                Text("volume: \(speechSynthesizer.volume, specifier: "%.2f")")
                Slider(value: $speechSynthesizer.volume, in: 0.0...1.0, onEditingChanged: handleEditingChanged)
            }
        }
        .monospacedDigit()
        .navigationTitle("speech")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func handleEditingChanged(_ isEditing: Bool) {
        guard !isEditing else { return }
        speak()
    }
    
    private func speak() {
        speechSynthesizer.speak(textToSpeak)
    }
}

#Preview {
    SpeechSettingsView()
        .environmentObject(SpeechSynthesizer.shared)
}
