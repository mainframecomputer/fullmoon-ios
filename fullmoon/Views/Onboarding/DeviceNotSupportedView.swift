//
//  DeviceNotSupportedView.swift
//  fullmoon
//
//  Created by Xavier on 10/12/2024.
//

import SwiftUI

struct DeviceNotSupportedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 64))
                .foregroundStyle(.primary, .tertiary)
            
            VStack(spacing: 4) {
                Text("device not supported")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("sorry, fullmoon can only run on devices that support Metal 3.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    DeviceNotSupportedView()
}
