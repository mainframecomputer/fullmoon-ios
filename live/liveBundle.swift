//
//  liveBundle.swift
//  live
//
//  Created by Sam Roman on 2/6/25.
//

import WidgetKit
import SwiftUI

@main
struct liveBundle: WidgetBundle {
    var body: some Widget {
        live()
        ModelDownloadLiveActivity()
    }
}
