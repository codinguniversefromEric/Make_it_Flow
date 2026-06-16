//
//  FlowWidgetBundle.swift
//  FlowWidget
//
//  Created by 魏嘉賢 on 2026/6/15.
//

import WidgetKit
import SwiftUI

@main
struct FlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlowWidget()
        FlowWidgetControl()
        FlowWidgetLiveActivity()
    }
}
