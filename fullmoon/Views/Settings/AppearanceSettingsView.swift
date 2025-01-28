//
//  AppearanceSettingsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        Form {
            #if os(iOS)
            Section {
                Picker(selection: $appManager.appTintColor) {
                    ForEach(AppTintColor.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("color", systemImage: "paintbrush.pointed")
                }
            }
            #endif

            Section(header: Text("font")) {
                Picker(selection: $appManager.appFontFamily) {
                    ForEach(AppFontFamily.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(option == .sansSerif ? "sans serif" : String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("family", systemImage: "textformat")
                }

                if appManager.appFontFamily == .sansSerif {
                    Picker(selection: $appManager.appFontWidth) {
                        ForEach(AppFontWidth.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                            Text(String(describing: option).lowercased())
                                .tag(option)
                        }
                    } label: {
                        Label("width", systemImage: "arrow.left.and.line.vertical.and.arrow.right")
                    }
                }

                #if !os(macOS)
                Picker(selection: $appManager.appFontSize) {
                    ForEach(AppFontSize.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("size", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                #endif
            }
        }
        .formStyle(.grouped)
        .navigationTitle("appearance")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    AppearanceSettingsView()
}
