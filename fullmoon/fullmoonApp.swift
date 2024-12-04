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
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject var appManager = AppManager()
    @State var llm = LLMEvaluator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Thread.self, Message.self])
                .environmentObject(appManager)
                .environment(llm)
                .environment(DeviceStat())
                #if os(macOS)
                .frame(minWidth: 640, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
                #endif
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                
            }
        }
        #endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainWindow = NSApp.windows[0]
        mainWindow.delegate = self
        
        let closeMenuItem = NSApp.mainMenu?.item(withTitle: "File")?.submenu?.item(withTitle: "Close")
        closeMenuItem?.target = self
        closeMenuItem?.action = #selector(handleCMDW)
    }
    
    @objc func handleCMDW() {
        // Post a notification when CMD + W is pressed
        // Optionally hide the app
        NSApp.hide(nil)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }
}
#endif
