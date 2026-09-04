import SwiftUI

// MARK: - 座標偵測工具
// 動態島座標紀錄鍵
struct IslandAnchorKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct AnchorDetector: View {
    let coordinateSpace: CoordinateSpace
    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: coordinateSpace)
            let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
            Color.clear
                .preference(key: IslandAnchorKey.self, value: centerPoint)
        }
    }
}
