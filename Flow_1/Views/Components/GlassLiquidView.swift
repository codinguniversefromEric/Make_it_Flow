import SwiftUI

/// 流暢水波紋進度條視圖 (0% CPU, 100% GPU 平移加速版)
struct GlassLiquidView: View {
    var progress: Double // 0.0 ~ 1.0
    var islandY: CGFloat
    
    @State private var animatedProgress: Double = 0
    @State private var waveOffset: CGFloat = 0.0
    
    var body: some View {
        GeometryReader { geo in
            let targetMaxY = geo.size.height + 40
            let currentY = islandY + (targetMaxY - islandY) * CGFloat(animatedProgress)
            
            // 定義一個波長剛好等於螢幕寬度 (Frequency = 1)
            let waveLength = geo.size.width
            // 畫出足夠長的靜態波浪 (3個波長)，確保往左平移加上相位差後，右邊不會穿幫
            let drawWidth = waveLength * 3
            
            // 使用 ZStack 搭配 offset 來做 100% GPU 硬體平移
            ZStack(alignment: .leading) {
                // 後方波浪：給予 1/4 波長的相位差產生交錯感
                WaveShape(yOffset: currentY, amplitude: 12, waveLength: waveLength)
                    .fill(Color.accentColor.opacity(0.15))
                    .offset(x: waveOffset - (waveLength / 4))
                
                // 前方波浪
                WaveShape(yOffset: currentY, amplitude: 18, waveLength: waveLength)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        WaveShape(yOffset: currentY, amplitude: 18, waveLength: waveLength)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .offset(x: waveOffset)
            }
            .frame(width: drawWidth, alignment: .leading)
            // 將 ZStack 的左上角精確對齊 GeometryReader 的左上角 (0,0)
            .position(x: drawWidth / 2, y: geo.size.height / 2)
        }
        .onAppear {
            animatedProgress = progress
            
            // 🚀 啟動 0 CPU 消耗的無限平移動畫
            // 以線性速度，在 2 秒內將波浪向左平移整整一個週期 (waveLength)
            // 當平移滿一個週期時瞬間歸零，因為波形連貫，視覺上等於無限流動
            let screenWidth = UIScreen.main.bounds.width
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                waveOffset = -screenWidth
            }
        }
        .onChange(of: progress) { newVal in
            // 水位升降依然保有優雅的物理彈簧感
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animatedProgress = newVal
            }
        }
    }
}

struct WaveShape: Shape {
    var yOffset: CGFloat
    var amplitude: CGFloat
    var waveLength: CGFloat
    
    // 只有 yOffset 需要進行 SwiftUI 內建的彈簧插值，確保水位升降平滑
    var animatableData: CGFloat {
        get { yOffset }
        set { yOffset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width // 這裡是 drawWidth (螢幕的三倍寬)
        guard width > 0 else { return path }
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: yOffset))
        
        // 由於只在水位改變時重繪，步進值可以設定得很小(更滑順)而沒有效能負擔
        let step: CGFloat = 3.0
        var x: CGFloat = step
        while x <= width {
            // 計算相對於一個波長的角度 (frequency = 1)
            let relativeX = x / waveLength
            let wave = sin(relativeX * .pi * 2)
            let y = yOffset + amplitude * CGFloat(wave)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        
        // 補齊最後一個點
        path.addLine(to: CGPoint(x: width, y: yOffset + amplitude * CGFloat(sin((width / waveLength) * .pi * 2))))
        
        // 右上角 → 閉合
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}
