import SwiftUI

/// 流暢水波紋進度條視圖
struct GlassLiquidView: View {
    var progress: Double // 0.0 ~ 1.0
    var islandY: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            let targetMaxY = geo.size.height + 40
            let currentY = islandY + (targetMaxY - islandY) * CGFloat(animatedProgress)
            
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let phase = now * .pi * 2 / 2.0
                
                ZStack {
                    // 恢復原本的大氣巨浪 (frequency: 1)，搭配振幅 (12, 18)
                    WaveShape(yOffset: currentY, phase: phase + .pi / 2, amplitude: 12, frequency: 1)
                        .fill(Color.accentColor.opacity(0.15))
                    
                    WaveShape(yOffset: currentY, phase: phase, amplitude: 18, frequency: 1)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            WaveShape(yOffset: currentY, phase: phase, amplitude: 18, frequency: 1)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                }
            }
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { newVal in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animatedProgress = newVal
            }
        }
    }
}

struct WaveShape: Shape {
    var yOffset: CGFloat
    var phase: Double
    var amplitude: CGFloat
    var frequency: Double
    
    // phase 由 TimelineView 直接刷新，不需要插值；yOffset 需要彈簧插值
    var animatableData: CGFloat {
        get { yOffset }
        set { yOffset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        guard width > 0 else { return path }
        
        // 起點：左上角
        path.move(to: CGPoint(x: 0, y: 0))
        
        // 第一個波浪點：x=0 的精確 Y 值，確保左邊緣無縫接合
        let startY = yOffset + amplitude * CGFloat(sin(phase))
        path.addLine(to: CGPoint(x: 0, y: startY))
        
        // 繪製波浪本體
        let step: CGFloat = 4.0
        var x: CGFloat = step
        while x < width {
            let relativeX = Double(x / width)
            let wave = sin(relativeX * .pi * 2 * frequency + phase)
            let y = yOffset + amplitude * CGFloat(wave)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        
        // 最後一個波浪點：x=width 的精確 Y 值，確保左右對稱 (因為 frequency 為整數)
        let endY = yOffset + amplitude * CGFloat(sin(.pi * 2 * frequency + phase))
        path.addLine(to: CGPoint(x: width, y: endY))
        
        // 右上角 → 閉合
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}
