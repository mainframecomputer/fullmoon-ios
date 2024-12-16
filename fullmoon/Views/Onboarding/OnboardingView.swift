//
//  OnboardingView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    Text("🌕")
                        .font(.system(size: 64))
                    
                    VStack(spacing: 4) {
                        Text("fullmoon")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("chat with private and local large language models")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 24) {
                    HStack{
                        Image(systemName: "message")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                        
                        VStack(alignment: .leading) {
                            Text("fast")
                                .font(.headline)
                            Text("optimized for apple silicon")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                        
                        VStack(alignment: .leading) {
                            Text("private")
                                .font(.headline)
                            Text("runs locally on your device")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                        
                        VStack(alignment: .leading) {
                            Text("open source")
                                .font(.headline)
                            Text("view and contribute to the source code")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                
                Spacer()
                
                NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding)) {
                    Text("get started")
                        #if os(iOS)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(.background)
                        #endif
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("welcome")
            .toolbar(.hidden)
        }
        #if os(macOS)
        .frame(width: 420, height: 520)
        #endif
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
