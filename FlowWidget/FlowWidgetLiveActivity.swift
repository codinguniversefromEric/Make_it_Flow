import ActivityKit
import WidgetKit
import SwiftUI

public struct FlowWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var statusMessage: String
    }

    public var documentName: String
}

struct FlowWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowWidgetAttributes.self) { context in
            // Lock screen UI
            HStack(spacing: 16) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.documentName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: 44, height: 44)
            }
            .padding()
            .activityBackgroundTint(Color(UIColor.systemBackground).opacity(0.5))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(.purple)
                        .font(.title3)
                        .padding(.top, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .padding(.top, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.documentName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(Color.purple)
                                    .frame(width: geo.size.width * context.state.progress, height: 8)
                            }
                        }
                        .frame(height: 8)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                Image(systemName: "doc.viewfinder")
                    .foregroundColor(.purple)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.purple)
            } minimal: {
                Image(systemName: "doc.viewfinder")
                    .foregroundColor(.purple)
            }
            .keylineTint(Color.purple)
        }
    }
}
