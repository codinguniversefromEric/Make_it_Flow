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
        FlowWidget() // 恢復預設的小工具，避免 WidgetKit 註冊失效
        // FlowWidgetControl() // 預設的控制中心小工具先關閉
        FlowWidgetLiveActivity()
    }
}
