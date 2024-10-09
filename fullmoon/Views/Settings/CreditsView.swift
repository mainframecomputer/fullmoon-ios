//
//  CreditsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/6/24.
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        List {
            Section {
                Link("MLX Swift", destination: URL(string: "https://github.com/ml-explore/mlx-swift")!)
                    .badge(Text(Image(systemName: "arrow.up.right")))
                Link("Mainframe", destination: URL(string: "https://mainfra.me")!)
                    .badge(Text(Image(systemName: "arrow.up.right")))
            }
        }
        .navigationTitle("credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CreditsView()
}
