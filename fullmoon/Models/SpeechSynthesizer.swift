//
//  SpeechSynthesizer.swift
//  fullmoon
//
//  Created by Kuba Szulaczkowski on 11/10/24.
//

import AVFoundation
import SwiftUI

final class SpeechSynthesizer: ObservableObject {
    static let shared = SpeechSynthesizer()
    private init() {}
    
    @AppStorage("autoSpeak") var auto = true
    @AppStorage("speechRate") var rate = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("speechPitch") var pitch = 1.0
    @AppStorage("speechVolume") var volume = 1.0
    @AppStorage("voice") var voice = AVSpeechSynthesisVoice.speechVoices().filter({ $0.language.hasPrefix("en") }).first?.identifier ?? "com.apple.voice.compact.en-GB.Daniel"
    
    private let synthesizer = AVSpeechSynthesizer()
    
    func speak(_ textToSpeak: String) {
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.rate = Float(rate)
        utterance.pitchMultiplier = Float(pitch)
        utterance.volume = Float(volume)
        utterance.voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == voice }) ?? AVSpeechSynthesisVoice.speechVoices().filter({ $0.language.hasPrefix("en") }).first
        
        synthesizer.speak(utterance)
    }
}
