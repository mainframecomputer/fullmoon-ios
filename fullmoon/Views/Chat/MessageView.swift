//
//  MessageView.swift
//  fullmoon
//
//  Created by Sébastien DAGUIN on 03/11/2026.
//


import MarkdownUI
import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            if message.role == .assistant {
                Markdown(message.content)
                    .textSelection(.enabled)
                    .padding(.trailing, 48)
            } else {
                Markdown(message.content)
                    .textSelection(.enabled)
                #if os(iOS) || os(visionOS)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                #else
                    .padding(.horizontal, 16 * 2 / 3)
                    .padding(.vertical, 8)
                #endif
                    .background(platformBackgroundColor)
                #if os(iOS) || os(visionOS)
                    .mask(RoundedRectangle(cornerRadius: 24))
                #elseif os(macOS)
                    .mask(RoundedRectangle(cornerRadius: 16))
                #endif
                    .padding(.leading, 48)
            }

            if message.role == .assistant { Spacer() }
        }
    }

    let platformBackgroundColor: Color = {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(visionOS)
        return Color(UIColor.separator)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }()
}