//
//  MoonAnimationView.swift
//  fullmoon
//
//  Created by Xavier on 17/12/2024.
//

import AVKit
import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(iOS) || os(visionOS)
struct PlayerView: UIViewRepresentable {
    var videoName: String
    var resetAnimation: Bool

    init(videoName: String, resetAnimation: Bool) {
        self.videoName = videoName
        self.resetAnimation = resetAnimation
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
        if let playerView = uiView as? LoopingPlayerUIView {
            playerView.restartPlayback()
        }
    }

    func makeUIView(context _: Context) -> UIView {
        return LoopingPlayerUIView(videoName: videoName)
    }
}

class LoopingPlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()

    init(videoName: String) {
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: videoName, ofType: "mp4")!)
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        super.init(frame: .zero)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        
        // Prevent other audio from stopping
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        player.play()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func restartPlayback() {
        player.seek(to: .zero)
        player.play()
    }
}
#endif

#if os(macOS)
struct PlayerView: NSViewRepresentable {
    var videoName: String
    
    init(videoName: String) {
        self.videoName = videoName
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No dynamic updates needed for this player
    }
    
    func makeNSView(context: Context) -> NSView {
        return LoopingPlayerNSView(videoName: videoName)
    }
}

class LoopingPlayerNSView: NSView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var player = AVQueuePlayer()
    
    init(videoName: String) {
        // Ensure the video file exists
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            fatalError("Video file \(videoName).mp4 not found in bundle.")
        }
        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        super.init(frame: .zero)
        
        // Configure the player layer
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        self.wantsLayer = true
        self.layer?.addSublayer(playerLayer)
        
        // Setup looping
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        
        // Start playback
        player.play()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = self.bounds
    }
}
#endif

struct MoonAnimationView: View {
    var isDone: Bool
    var resetAnimation: Bool
    
    var body: some View {
        ZStack {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.green)
            } else {
                // placeholder
                Image(.moonAnimationPlaceholder)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                // video loop
                
                PlayerView(videoName: "moon-phases", resetAnimation: resetAnimation)
                    .aspectRatio(contentMode: .fit)
                    .mask {
                        Circle()
                            .scale(0.99)
                    }
            }
        }
        .frame(width: 64, height: 64)
    }
}

#Preview {
    @Previewable @State var done = false
    VStack(spacing: 50) {
        Toggle(isOn: $done, label: { Text("Done") })
        MoonAnimationView(isDone: done, resetAnimation: false)
    }
}
